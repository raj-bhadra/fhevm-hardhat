// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {iZBondingCurve} from "./iZBondingCurve.sol";
import {ConfidentialToken} from "./ConfidentialToken.sol";
import {ConfidentialTokenWrapper} from "./ConfidentialTokenWrapper.sol";
import {FHE, ebool, euint64, externalEuint64, externalEbool} from "@fhevm/solidity/lib/FHE.sol";
import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {ConfidentialTokenFactory} from "./ConfidentialTokenFactory.sol";

contract ZBondingCurve is SepoliaConfig, iZBondingCurve {
    // At least 2 transactions must be made before public price update is allowed
    // This is to prevent the transactions from being revealed due to price changes
    uint256 public constant MIN_TRANSACTIONS_BEFORE_PRICE_UPDATE_ALLOWED = 2;

    uint64 public lastDecryptedPrice;

    ConfidentialTokenWrapper public quoteAssetToken;
    ConfidentialTokenFactory public confidentialTokenFactory;

    constructor(ConfidentialTokenWrapper _quoteAssetToken, ConfidentialTokenFactory _confidentialTokenFactory) {
        quoteAssetToken = _quoteAssetToken;
        confidentialTokenFactory = _confidentialTokenFactory;
    }

    // Trade with a minimum amount out
    function trade(
        ConfidentialToken baseAssetToken,
        externalEuint64 eQuoteAssetAmountInExternal,
        externalEuint64 eBaseAssetTokenAmountInExternal,
        bytes calldata inputProof
    ) external {
        require(
            confidentialTokenFactory.isConfidentialTokenRegistered(address(baseAssetToken)),
            "Base asset not registered"
        );
        // require this address to be an operator for both quote asset and base asset
        require(baseAssetToken.isOperator(msg.sender, address(this)), "Not an operator for base asset");
        require(quoteAssetToken.isOperator(msg.sender, address(this)), "Not an operator for quote asset");
        require(baseAssetToken.observer(msg.sender) == address(this), "Not an observer for base asset");
        require(quoteAssetToken.observer(msg.sender) == address(this), "Not an observer for quote asset");

        euint64 eQuoteAssetAmountIn = FHE.fromExternal(eQuoteAssetAmountInExternal, inputProof);
        euint64 eBaseAssetTokenAmountIn = FHE.fromExternal(eBaseAssetTokenAmountInExternal, inputProof);
        euint64 ePrice = FHE.asEuint64(1);
        // if is buy
        // transfer quote asset to this contract
        // calculate the generated base asset token amount
        // mint the generated base asset token to the user
        FHE.allowTransient(eQuoteAssetAmountIn, address(quoteAssetToken));
        euint64 quoteTokenAmountTransferred = quoteAssetToken.confidentialTransferFrom(
            msg.sender,
            address(this),
            eQuoteAssetAmountIn
        );
        euint64 eBaseAssetTokenAmountOut = FHE.mul(quoteTokenAmountTransferred, ePrice);
        FHE.allowTransient(eBaseAssetTokenAmountOut, address(baseAssetToken));
        baseAssetToken.mint(msg.sender, eBaseAssetTokenAmountOut);
        // if is sell
        // calculate the actual price in quote asset using step bonding curve formula
        // burn the base asset token from the user
        // transfer the generated base asset token to the user
        // todo: calculate the actual price in quote asset using step bonding curve formula
        euint64 baseAssetTokenBalance = baseAssetToken.confidentialBalanceOf(msg.sender);
        euint64 eBaseAssetTokenToBurn = FHE.min(baseAssetTokenBalance, eBaseAssetTokenAmountIn);
        FHE.allowTransient(eBaseAssetTokenToBurn, address(baseAssetToken));
        euint64 burnedBaseAssetToken = baseAssetToken.burn(msg.sender, eBaseAssetTokenToBurn);
        euint64 eQuoteAssetAmountOut = FHE.mul(burnedBaseAssetToken, ePrice);
        FHE.allowTransient(eQuoteAssetAmountOut, address(quoteAssetToken));
        // transfer the quote asset to the user
        quoteAssetToken.confidentialTransfer(msg.sender, eQuoteAssetAmountOut);
        // FHE.allowTransient(amountTransferred, address(quoteAssetToken));
    }

    function getLastDecryptedPrice() external view returns (uint64) {
        return lastDecryptedPrice;
    }

    function getQuoteAssetToken() external view returns (address) {
        return address(quoteAssetToken);
    }

    function getConfidentialTokenFactory() external view returns (address) {
        return address(confidentialTokenFactory);
    }

    function minTransactionsBeforePriceUpdateRequired() external pure returns (uint256) {
        return MIN_TRANSACTIONS_BEFORE_PRICE_UPDATE_ALLOWED;
    }

    function calculateQuoteAssetOutAtLastDecryptedPrice(
        ConfidentialToken,
        uint64 amountIn
    ) external pure returns (uint64 amountOut) {
        return amountIn;
    }

    function calculateTokenOutAtLastDecryptedPrice(
        ConfidentialToken,
        uint64 amountIn
    ) external pure returns (uint64 amountOut) {
        return amountIn;
    }
}
