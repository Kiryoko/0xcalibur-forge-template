// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Vm.sol";
import "solady/utils/LibString.sol";

library ChainId {
    uint256 internal constant Base = 8453;
}

library Block {
    uint256 internal constant Latest = 0;
}

/// @notice Toolkit is a toolchain contract that stores all the addresses of the contracts, cauldrons configurations
/// and other information and functionnalities that is needed for the deployment scripts and testing.
/// It is not meant to be deployed but to be used for chainops.
contract Toolkit {
    using LibString for string;

    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    ///////////////////////////////////////////////////////////////
    /// @dev Json structs for reading from the config files
    /// The name must be in alphabetical order as documented here:
    /// https://book.getfoundry.sh/cheatcodes/parse-json
    struct JsonAddressEntry {
        string key;
        address value;
    }

    struct JsonPairCodeHash {
        string key;
        bytes32 value;
    }
    //
    ///////////////////////////////////////////////////////////////

    mapping(string => address) private addressMap;
    mapping(string => bytes32) private pairCodeHash;
    mapping(uint256 => string) private chainIdToName;

    string[] private addressKeys;

    uint[] public chains = [ChainId.Base];

    bool public testing;

    constructor() {
        chainIdToName[ChainId.Base] = "Base";

        for (uint i = 0; i < chains.length; i++) {
            uint256 chainId = chains[i];
            string memory path = string.concat(vm.projectRoot(), "/config/", chainIdToName[chainId].lower(), ".json");

            try vm.readFile(path) returns (string memory json) {
                {
                    bytes memory jsonContent = vm.parseJson(json, ".addresses");
                    JsonAddressEntry[] memory entries = abi.decode(jsonContent, (JsonAddressEntry[]));

                    for (uint j = 0; j < entries.length; j++) {
                        JsonAddressEntry memory entry = entries[j];
                        setAddress(chainId, entry.key, entry.value);
                    }
                }
            } catch {}
        }
    }

    function setAddress(uint256 chainid, string memory key, address value) public {
        key = string.concat(chainIdToName[chainid].lower(), ".", key);
        require(addressMap[key] == address(0), string.concat("address already exists: ", key));
        addressMap[key] = value;
        addressKeys.push(key);

        vm.label(value, key);
    }

    function getAddress(string memory key) public view returns (address) {
        require(addressMap[key] != address(0), string.concat("address not found: ", key));
        return addressMap[key];
    }

    function getAddress(string calldata name, uint256 chainid) public view returns (address) {
        string memory key = string.concat(chainIdToName[chainid].lower(), ".", name);
        return getAddress(key);
    }

    function getAddress(uint256 chainid, string calldata name) public view returns (address) {
        return getAddress(name, chainid);
    }

    function getPairCodeHash(string calldata key) public view returns (bytes32) {
        require(pairCodeHash[key] != "", string.concat("pairCodeHash not found: ", key));
        return pairCodeHash[key];
    }

    function getChainName(uint256 chainid) public view returns (string memory) {
        return chainIdToName[chainid];
    }

    function setTesting(bool _testing) public {
        testing = _testing;
    }

    function prefixWithChainName(uint256 chainid, string memory name) public view returns (string memory) {
        return string.concat(getChainName(chainid), "_", name);
    }
}

function getToolkit() returns (Toolkit toolkit) {
    address location = address(bytes20(uint160(uint256(keccak256("toolkit")))));
    toolkit = Toolkit(location);

    if (location.code.length == 0) {
        Vm vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));
        bytes memory creationCode = vm.getCode("Toolkit.sol");
        vm.etch(location, abi.encodePacked(creationCode, ""));
        vm.allowCheatcodes(location);
        (bool success, bytes memory runtimeBytecode) = location.call{value: 0}("");
        require(success, "Fail to initialize Toolkit");
        vm.etch(location, runtimeBytecode);
        vm.makePersistent(address(location));
        vm.label(location, "toolkit");
    }
}
