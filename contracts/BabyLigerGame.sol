// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IBabyLigerToken {
    function stakeTokens(address player, string memory gameType) external;
    function unstakeTokens(address player, uint256 amount) external;
    function distributeReward(address winner, uint256 amount) external;
    function getGameFee(string memory gameType) external view returns (uint256);
}

contract BabyLigerGame is ReentrancyGuard, Ownable, Pausable {
    // State variables
    IBabyLigerToken public tokenContract;
    
    struct Game {
        string gameType;
        address player1;
        address player2;
        uint256 stake;
        uint256 startTime;
        bool isActive;
        address winner;
        uint8 status; // 0: Created, 1: InProgress, 2: Completed, 3: Cancelled
    }
    
    struct GameType {
        bool isActive;
        uint256 timeLimit; // Time limit in seconds
        uint256 minStake;
        uint256 maxStake;
    }
    
    // Mappings
    mapping(bytes32 => Game) public games;
    mapping(string => GameType) public gameTypes;
    mapping(address => bytes32[]) public playerGames;
    mapping(address => uint256) public playerActiveGames;
    
    // Constants
    uint256 public constant MAX_ACTIVE_GAMES = 3;
    uint256 public constant MAX_GAME_DURATION = 1 hours;
    
    // Events
    event GameCreated(bytes32 indexed gameId, address indexed player1, string gameType, uint256 stake);
    event GameJoined(bytes32 indexed gameId, address indexed player2);
    event GameStarted(bytes32 indexed gameId, uint256 startTime);
    event GameEnded(bytes32 indexed gameId, address indexed winner, uint256 reward);
    event GameCancelled(bytes32 indexed gameId, string reason);
    event GameTypeAdded(string gameType, uint256 timeLimit, uint256 minStake, uint256 maxStake);
    
    constructor(address _tokenContract) {
        require(_tokenContract != address(0), "Invalid token contract");
        tokenContract = IBabyLigerToken(_tokenContract);
    }
    
    // Admin functions
    function addGameType(
        string memory gameType,
        uint256 timeLimit,
        uint256 minStake,
        uint256 maxStake
    ) external onlyOwner {
        require(timeLimit > 0 && timeLimit <= MAX_GAME_DURATION, "Invalid time limit");
        require(maxStake >= minStake, "Invalid stake range");
        
        gameTypes[gameType] = GameType({
            isActive: true,
            timeLimit: timeLimit,
            minStake: minStake,
            maxStake: maxStake
        });
        
        emit GameTypeAdded(gameType, timeLimit, minStake, maxStake);
    }
    
    function toggleGameType(string memory gameType) external onlyOwner {
        require(gameTypes[gameType].timeLimit > 0, "Game type doesn't exist");
        gameTypes[gameType].isActive = !gameTypes[gameType].isActive;
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Game functions
    function createGame(string memory gameType, uint256 stake) external whenNotPaused nonReentrant {
        require(gameTypes[gameType].isActive, "Game type not active");
        require(stake >= gameTypes[gameType].minStake, "Stake too low");
        require(stake <= gameTypes[gameType].maxStake, "Stake too high");
        require(playerActiveGames[msg.sender] < MAX_ACTIVE_GAMES, "Too many active games");
        
        bytes32 gameId = keccak256(abi.encodePacked(msg.sender, block.timestamp, gameType));
        
        // Stake tokens
        tokenContract.stakeTokens(msg.sender, gameType);
        
        games[gameId] = Game({
            gameType: gameType,
            player1: msg.sender,
            player2: address(0),
            stake: stake,
            startTime: 0,
            isActive: true,
            winner: address(0),
            status: 0
        });
        
        playerGames[msg.sender].push(gameId);
        playerActiveGames[msg.sender]++;
        
        emit GameCreated(gameId, msg.sender, gameType, stake);
    }
    
    function joinGame(bytes32 gameId) external whenNotPaused nonReentrant {
        Game storage game = games[gameId];
        require(game.isActive, "Game not active");
        require(game.player2 == address(0), "Game full");
        require(msg.sender != game.player1, "Cannot join own game");
        require(playerActiveGames[msg.sender] < MAX_ACTIVE_GAMES, "Too many active games");
        
        // Stake tokens
        tokenContract.stakeTokens(msg.sender, game.gameType);
        
        game.player2 = msg.sender;
        game.startTime = block.timestamp;
        game.status = 1;
        
        playerGames[msg.sender].push(gameId);
        playerActiveGames[msg.sender]++;
        
        emit GameJoined(gameId, msg.sender);
        emit GameStarted(gameId, game.startTime);
    }
    
    function endGame(bytes32 gameId, address winner) external onlyOwner whenNotPaused nonReentrant {
        Game storage game = games[gameId];
        require(game.status == 1, "Game not in progress");
        require(winner == game.player1 || winner == game.player2, "Invalid winner");
        
        game.isActive = false;
        game.winner = winner;
        game.status = 2;
        
        uint256 reward = game.stake * 2;
        tokenContract.distributeReward(winner, reward);
        
        playerActiveGames[game.player1]--;
        playerActiveGames[game.player2]--;
        
        emit GameEnded(gameId, winner, reward);
    }
    
    function cancelGame(bytes32 gameId) external nonReentrant {
        Game storage game = games[gameId];
        require(game.isActive, "Game not active");
        require(msg.sender == game.player1 || msg.sender == game.player2 || msg.sender == owner(), "Unauthorized");
        
        if (game.status == 0) {
            // Only refund player1
            tokenContract.unstakeTokens(game.player1, game.stake);
            playerActiveGames[game.player1]--;
        } else if (game.status == 1) {
            // Refund both players
            tokenContract.unstakeTokens(game.player1, game.stake);
            tokenContract.unstakeTokens(game.player2, game.stake);
            playerActiveGames[game.player1]--;
            playerActiveGames[game.player2]--;
        }
        
        game.isActive = false;
        game.status = 3;
        
        emit GameCancelled(gameId, "Game cancelled by player or admin");
    }
    
    // View functions
    function getGame(bytes32 gameId) external view returns (Game memory) {
        return games[gameId];
    }
    
    function getPlayerGames(address player) external view returns (bytes32[] memory) {
        return playerGames[player];
    }
    
    function getGameType(string memory gameType) external view returns (GameType memory) {
        return gameTypes[gameType];
    }
}