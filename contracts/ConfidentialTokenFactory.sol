// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ConfidentialToken} from "./ConfidentialToken.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ZBondingCurve} from "./ZBondingCurve.sol";

/// @title ERC7984Factory
/// @notice Factory contract for creating ERC7984 instances
contract ConfidentialTokenFactory is SepoliaConfig, Ownable {
    address[] public _tokenAddresses;
    event TokenCreated(address indexed tokenAddress);
    mapping(address => bool) public isTokenRegistered;
    ZBondingCurve public zBondingCurve;
    struct TokenInfo {
        address createdBy;
        string name;
        string symbol;
        string contractURI;
        address tokenAddress;
    }
    TokenInfo[] public tokenInfos;
    mapping(address => TokenInfo[]) public tokenInfosByCreatorAddress;

    constructor() Ownable(msg.sender) {}

    function setZBondingCurve(ZBondingCurve _zBondingCurve) external onlyOwner {
        zBondingCurve = _zBondingCurve;
    }

    function createToken(string memory name, string memory symbol, string memory contractURI) external {
        ConfidentialToken token = new ConfidentialToken(address(zBondingCurve), name, symbol, contractURI);
        _tokenAddresses.push(address(token));
        isTokenRegistered[address(token)] = true;
        tokenInfos.push(
            TokenInfo({
                createdBy: msg.sender,
                name: name,
                symbol: symbol,
                contractURI: contractURI,
                tokenAddress: address(token)
            })
        );
        emit TokenCreated(address(token));
    }

    function getTokenAddresses() external view returns (address[] memory) {
        return _tokenAddresses;
    }

    function isConfidentialTokenRegistered(address tokenAddress) external view returns (bool) {
        return isTokenRegistered[tokenAddress];
    }

    function getTokenCount() external view returns (uint256) {
        return tokenInfos.length;
    }

    function getTokenInfosCountByCreator(address creatorAddress) external view returns (uint256) {
        return tokenInfosByCreatorAddress[creatorAddress].length;
    }
    function getPaginatedTokenInfos(uint256 page, uint256 pageSize) external view returns (TokenInfo[] memory) {
        uint256 startIndex = page * pageSize;
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > tokenInfos.length) {
            endIndex = tokenInfos.length;
        }
        TokenInfo[] memory paginatedTokenInfos = new TokenInfo[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            paginatedTokenInfos[i - startIndex] = tokenInfos[i];
        }
        return paginatedTokenInfos;
    }

    function getPaginatedTokenInfosByCreator(
        address creatorAddress,
        uint256 page,
        uint256 pageSize
    ) external view returns (TokenInfo[] memory) {
        uint256 startIndex = page * pageSize;
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > tokenInfosByCreatorAddress[creatorAddress].length) {
            endIndex = tokenInfosByCreatorAddress[creatorAddress].length;
        }
        TokenInfo[] memory paginatedTokenInfos = new TokenInfo[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            paginatedTokenInfos[i - startIndex] = tokenInfosByCreatorAddress[creatorAddress][i];
        }
        return paginatedTokenInfos;
    }
}
