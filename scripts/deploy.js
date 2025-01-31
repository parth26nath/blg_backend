const hre = require("hardhat");

async function main() {
  // Deploy Token Contract
  const BabyLigerToken = await hre.ethers.getContractFactory("BabyLigerToken");
  const token = await BabyLigerToken.deploy();
  await token.deployed();
  console.log("BabyLigerToken deployed to:", token.address);

  // Deploy Game Contract
  const BabyLigerGame = await hre.ethers.getContractFactory("BabyLigerGame");
  const game = await BabyLigerGame.deploy(token.address);
  await game.deployed();
  console.log("BabyLigerGame deployed to:", game.address);

  // Set game fees
  await token.setGameFee("tictactoe", ethers.utils.parseEther("0.1"));
  await token.setGameFee("chess", ethers.utils.parseEther("0.2"));
  await token.setGameFee("snakeladders", ethers.utils.parseEther("0.15"));

  console.log("Game fees set");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});