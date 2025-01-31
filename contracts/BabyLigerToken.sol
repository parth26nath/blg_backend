// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BabyLigerToken is ERC20, ERC20Burnable, ReentrancyGuard, Ownable {
    // Gaming specific storage
    mapping(address => uint256) public playerBalances;
    mapping(string => uint256) public gameFees;
    mapping(address => bool) public authorizedGames;
    
    // Events
    event GameAuthorized(address gameContract);
    event GameUnauthorized(address gameContract);
    event GameFeeSet(string gameType, uint256 fee);
    event TokensStaked(address player, uint256 amount);
    event TokensUnstaked(address player, uint256 amount);
    event RewardDistributed(address player, uint256 amount);
    
    constructor() ERC20("BabyLiger", "BLGR") {
        // Initial supply: 1 billion tokens
        _mint(msg.sender, 1_000_000_000 * 10**decimals());
    }
    
    // Admin functions
    function authorizeGame(address gameContract) external onlyOwner {
        require(gameContract != address(0), "Invalid game address");
        authorizedGames[gameContract] = true;
        emit GameAuthorized(gameContract);
    }
    
    function unauthorizeGame(address gameContract) external onlyOwner {
        require(authorizedGames[gameContract], "Game not authorized");
        authorizedGames[gameContract] = false;
        emit GameUnauthorized(gameContract);
    }
    
    function setGameFee(string memory gameType, uint256 fee) external onlyOwner {
        require(fee > 0, "Fee must be positive");
        gameFees[gameType] = fee;
        emit GameFeeSet(gameType, fee);
    }
    
    // Gaming functions
    function stakeTokens(address player, string memory gameType) external nonReentrant {
        require(authorizedGames[msg.sender], "Unauthorized game contract");
        require(gameFees[keccak256(bytes(gameType))] > 0, "Game type not configured");
        uint256 stakeAmount = gameFees[keccak256(bytes(gameType))];
        require(balanceOf(player) >= stakeAmount, "Insufficient balance");
        
        _transfer(player, address(this), stakeAmount);
        playerBalances[player] += stakeAmount;
        emit TokensStaked(player, stakeAmount);
    }
    
    function unstakeTokens(address player, uint256 amount) external nonReentrant {
        require(authorizedGames[msg.sender], "Unauthorized game contract");
        require(playerBalances[player] >= amount, "Insufficient staked balance");
        
        playerBalances[player] -= amount;
        _transfer(address(this), player, amount);
        emit TokensUnstaked(player, amount);
    }
    
    function distributeReward(address winner, uint256 amount) external nonReentrant {
        require(authorizedGames[msg.sender], "Unauthorized game contract");
        require(amount <= address(this).balance, "Insufficient contract balance");
        
        _transfer(address(this), winner, amount);
        emit RewardDistributed(winner, amount);
    }
    
    // View functions
    function getGameFee(string memory gameType) external view returns (uint256) {
        return gameFees[keccak256(bytes(gameType))];
    }
    
    function getStakedBalance(address player) external view returns (uint256) {
        return playerBalances[player];
    }
}