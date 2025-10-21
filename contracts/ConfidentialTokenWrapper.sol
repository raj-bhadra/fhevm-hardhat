// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";
import {ERC7984ERC20Wrapper} from 
    "@openzeppelin/confidential-contracts/token/ERC7984/extensions/ERC7984ERC20Wrapper.sol";
import { ERC7984 } from "@openzeppelin/confidential-contracts/token/ERC7984/ERC7984.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";


contract ConfidentialTokenWrapper is SepoliaConfig, ERC7984ERC20Wrapper {
    constructor(
        IERC20 underlying_
    ) ERC7984ERC20Wrapper(underlying_) ERC7984(generateName(underlying_), generateSymbol(underlying_), "") {
    }

    function generateName(IERC20 underlying_) public view returns (string memory) {
        return string(abi.encodePacked("z", _tryGetAssetName(underlying_)));
    }

    function generateSymbol(IERC20 underlying_) public view returns (string memory) {
        return string(abi.encodePacked("z", _tryGetAssetSymbol(underlying_)));
    }

    function _tryGetAssetName(IERC20 asset_) private view returns (string memory) {
        (bool success, bytes memory encodedName) = address(asset_).staticcall(
            abi.encodeCall(IERC20Metadata.name, ())
        );
        if (success && encodedName.length > 0) {
            return abi.decode(encodedName, (string));
        }
        return "";
    }

    function _tryGetAssetSymbol(IERC20 asset_) private view returns (string memory) {
        (bool success, bytes memory encodedSymbol) = address(asset_).staticcall(
            abi.encodeCall(IERC20Metadata.symbol, ())
        );
        if (success && encodedSymbol.length > 0) {
            return abi.decode(encodedSymbol, (string));
        }
        return "";
    }

}