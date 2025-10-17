// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ConfidentialToken} from "./ConfidentialToken.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title ERC7984Factory
/// @notice Factory contract for creating ERC7984 instances
contract ConfidentialTokenFactory is SepoliaConfig {

    address[] public _tokenAddresses;
    event TokenCreated(address indexed tokenAddress);

    function createToken(
        string memory name,
        string memory symbol,
        string memory contractURI
    ) external {
        ConfidentialToken token = new ConfidentialToken(name, symbol, contractURI);
        _tokenAddresses.push(address(token));
        emit TokenCreated(address(token));
    }

    function getTokenAddresses() external view returns (address[] memory) {
        return _tokenAddresses;
    }

}