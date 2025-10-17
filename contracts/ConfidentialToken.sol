// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";
import { ERC7984 } from "@openzeppelin/confidential-contracts/token/ERC7984/ERC7984.sol";
import {FHE, externalEuint64, euint64} from "@fhevm/solidity/lib/FHE.sol";

contract ConfidentialToken is SepoliaConfig, ERC7984 {
    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI
    ) ERC7984(name, symbol, contractURI) {
    }

    function mint(address to, externalEuint64 amount, bytes calldata inputProof) external {
        euint64 encryptedAmount = FHE.fromExternal(amount, inputProof);
        _mint(to, encryptedAmount);
    }

    function burn(externalEuint64 amount, bytes calldata inputProof) external {
        euint64 encryptedAmount = FHE.fromExternal(amount, inputProof);
        _burn(msg.sender, encryptedAmount);
    }
}
