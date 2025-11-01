// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {ERC7984} from "@openzeppelin/confidential-contracts/token/ERC7984/ERC7984.sol";
import {
    ERC7984ObserverAccess
} from "@openzeppelin/confidential-contracts/token/ERC7984/extensions/ERC7984ObserverAccess.sol";
import {FHE, externalEuint64, euint64} from "@fhevm/solidity/lib/FHE.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ConfidentialToken is SepoliaConfig, ERC7984ObserverAccess, Ownable {
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory contractURI
    ) ERC7984(name, symbol, contractURI) Ownable(owner) {
    }

    function mint(address to, externalEuint64 amount, bytes calldata inputProof) onlyOwner external returns (euint64) {
        euint64 encryptedAmount = FHE.fromExternal(amount, inputProof);
        return _mint(to, encryptedAmount);
    }

    function mint(address to, euint64 amount) onlyOwner external returns (euint64) {
        return _mint(to, amount);
    }

    function burn(address from, externalEuint64 amount, bytes calldata inputProof) onlyOwner external returns (euint64) {
        euint64 encryptedAmount = FHE.fromExternal(amount, inputProof);
        return _burn(from, encryptedAmount);
    }

    function burn(address from, euint64 amount) onlyOwner external returns (euint64) {
        return _burn(from, amount);
    }
}
