import { ethers } from "hardhat";

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const lockedAmount = ethers.parseEther("0.001");

  const lock = await ethers.deployContract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  await lock.waitForDeployment();

  console.log(
    `Lock with ${ethers.formatEther(
      lockedAmount
    )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        uint256 mintLockTime = block.timestamp + 10;
        uint256 mintStartTime = block.timestamp + 60;
        uint256 mintExpirationTime = block.timestamp + 730 days;

        address fiscDeployer = "0x47AdCa94F5E72F091DC78C2DC77b058811840Db0";

        Fisc fisc = new FiscOwnable(fiscDeployer);

        Surge surge = new Surge(
            mintLockTime,
            mintStartTime,
            mintExpirationTime,
            address(fiscDeployer)
        );

        vm.stopBroadcast();
    }
}