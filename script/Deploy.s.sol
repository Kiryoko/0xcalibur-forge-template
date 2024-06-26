// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";

contract DeployScript is BaseScript {
    function deploy() public {
        vm.startBroadcast();
        deploy("Contract", "Contract.sol:Contract", abi.encode(tx.origin));
        vm.stopBroadcast();
    }
}
