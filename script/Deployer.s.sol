// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "../lib/forge-std/src/Script.sol";
import "../src/Surge.sol";
import "../src/FiscOwnable.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        uint256 mintLock = block.timestamp + 60;
        uint256 mintStart = block.timestamp + 120;
        uint256 mintEnd = block.timestamp + 730 days;

        address fiscDeployer = 0x47AdCa94F5E72F091DC78C2DC77b058811840Db0;

        // FiscOwnable fisc = new FiscOwnable(fiscDeployer);

        Surge surge = new Surge(
            mintLock,
            mintStart,
            mintEnd,
            address(fiscDeployer)
        );

        surge.addMint(0xa0Cc535555a67FB6c3f4c2f2d39Ad039ba129Cf4, 10000);

        vm.stopBroadcast();
    }
}
