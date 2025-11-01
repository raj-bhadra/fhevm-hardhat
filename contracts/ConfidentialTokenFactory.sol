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
    address[] public _priviledgedTokenAddresses;
    event TokenCreated(address indexed tokenAddress);
    event PriviledgedTokenCreated(address indexed tokenAddress);
    mapping(address => bool) public isTokenRegistered;
    mapping(address => bool) public isPriviledgedTokenRegistered;
    ZBondingCurve public zBondingCurve;
    struct TokenInfo {
        address createdBy;
        string name;
        string symbol;
        string contractURI;
        address tokenAddress;
    }
    TokenInfo[] public tokenInfos;
    TokenInfo[] public priviledgedTokenInfos;
    mapping(address => TokenInfo[]) public tokenInfosByCreatorAddress;
    mapping(address => TokenInfo[]) public priviledgedTokenInfosByCreatorAddress;

    constructor() Ownable(msg.sender) {}

    function setZBondingCurve(ZBondingCurve _zBondingCurve) external onlyOwner {
        zBondingCurve = _zBondingCurve;
    }

    function createToken(string memory name, string memory symbol, string memory contractURI) external {
        require(address(zBondingCurve) != address(0), "ZBondingCurve not set");
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
        tokenInfosByCreatorAddress[msg.sender].push(
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

    function createPriviledgedToken(string memory name, string memory symbol, string memory contractURI) external {
        ConfidentialToken token = new ConfidentialToken(msg.sender, name, symbol, contractURI);
        _priviledgedTokenAddresses.push(address(token));
        isPriviledgedTokenRegistered[address(token)] = true;
        priviledgedTokenInfos.push(
            TokenInfo({
                createdBy: msg.sender,
                name: name,
                symbol: symbol,
                contractURI: contractURI,
                tokenAddress: address(token)
            })
        );
        priviledgedTokenInfosByCreatorAddress[msg.sender].push(
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

    function priviledgedTokenRegistered(address tokenAddress) external view returns (bool) {
        return isPriviledgedTokenRegistered[tokenAddress];
    }

    function getPriviledgedTokenAddresses() external view returns (address[] memory) {
        return _priviledgedTokenAddresses;
    }

    function getPriviledgedTokenCount() external view returns (uint256) {
        return priviledgedTokenInfos.length;
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

    function getPaginatedPriviledgedTokenInfos(uint256 page, uint256 pageSize) external view returns (TokenInfo[] memory) {
        uint256 startIndex = page * pageSize;
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > priviledgedTokenInfos.length) {
            endIndex = priviledgedTokenInfos.length;
        }
        TokenInfo[] memory paginatedTokenInfos = new TokenInfo[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            paginatedTokenInfos[i - startIndex] = priviledgedTokenInfos[i];
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

    function getPaginatedPriviledgedTokenInfosByCreator(
        address creatorAddress,
        uint256 page,
        uint256 pageSize
    ) external view returns (TokenInfo[] memory) {
        uint256 startIndex = page * pageSize;
        uint256 endIndex = startIndex + pageSize;
        if (endIndex > priviledgedTokenInfosByCreatorAddress[creatorAddress].length) {
            endIndex = priviledgedTokenInfosByCreatorAddress[creatorAddress].length;
        }
        TokenInfo[] memory paginatedTokenInfos = new TokenInfo[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            paginatedTokenInfos[i - startIndex] = priviledgedTokenInfosByCreatorAddress[creatorAddress][i];
        }
        return paginatedTokenInfos;
    }
}
