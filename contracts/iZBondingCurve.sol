// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FHE, externalEuint64, externalEbool} from "@fhevm/solidity/lib/FHE.sol";
import {ConfidentialToken} from "./ConfidentialToken.sol";

interface iZBondingCurve {
    function trade(
        ConfidentialToken baseAssetToken,
        externalEuint64 eQuoteAssetAmountInExternal,
        externalEuint64 eBaseAssetTokenAmountInExternal,
        bytes calldata inputProof
    ) external;

    function getLastDecryptedPrice() external view returns (uint64);

    function minTransactionsBeforePriceUpdateRequired() external pure returns (uint256);

    function getQuoteAssetToken() external view returns (address);

    function calculateQuoteAssetOutAtLastDecryptedPrice(
        ConfidentialToken baseAssetToken,
        uint64 amountIn
    ) external pure returns (uint64 amountOut);

    function calculateTokenOutAtLastDecryptedPrice(
        ConfidentialToken baseAssetToken,
        uint64 amountIn
    ) external pure returns (uint64 amountOut);
}
