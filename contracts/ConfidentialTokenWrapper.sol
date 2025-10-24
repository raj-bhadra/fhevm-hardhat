// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SepoliaConfig} from "@fhevm/solidity/config/ZamaConfig.sol";
import {
    ERC7984ERC20Wrapper
} from "@openzeppelin/confidential-contracts/token/ERC7984/extensions/ERC7984ERC20Wrapper.sol";
import {ERC7984} from "@openzeppelin/confidential-contracts/token/ERC7984/ERC7984.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {FHE, euint64} from "@fhevm/solidity/lib/FHE.sol";

contract ConfidentialTokenWrapper is SepoliaConfig, ERC7984ERC20Wrapper {
    // copied from observer extension
    mapping(address => address) private _observers;
    event ERC7984ObserverAccessObserverSet(address account, address oldObserver, address newObserver);
    error Unauthorized();

    constructor(
        IERC20 underlying_
    ) ERC7984ERC20Wrapper(underlying_) ERC7984(generateName(underlying_), generateSymbol(underlying_), "") {}

    // copied from observer extension
    function setObserver(address account, address newObserver) public virtual {
        address oldObserver = observer(account);
        require(msg.sender == account || (msg.sender == oldObserver && newObserver == address(0)), Unauthorized());
        if (oldObserver != newObserver) {
            if (newObserver != address(0)) {
                euint64 balanceHandle = confidentialBalanceOf(account);
                if (FHE.isInitialized(balanceHandle)) {
                    FHE.allow(balanceHandle, newObserver);
                }
            }

            emit ERC7984ObserverAccessObserverSet(account, oldObserver, _observers[account] = newObserver);
        }
    }

    // copied from observer extension
    function _update(address from, address to, euint64 amount) internal virtual override returns (euint64 transferred) {
        transferred = super._update(from, to, amount);

        address fromObserver = observer(from);
        address toObserver = observer(to);

        if (fromObserver != address(0)) {
            FHE.allow(confidentialBalanceOf(from), fromObserver);
            FHE.allow(transferred, fromObserver);
        }
        if (toObserver != address(0)) {
            FHE.allow(confidentialBalanceOf(to), toObserver);
            if (toObserver != fromObserver) {
                FHE.allow(transferred, toObserver);
            }
        }
    }

    function observer(address account) public view virtual returns (address) {
        return _observers[account];
    }

    function generateName(IERC20 underlying_) public view returns (string memory) {
        return string(abi.encodePacked("z", _tryGetAssetName(underlying_)));
    }

    function generateSymbol(IERC20 underlying_) public view returns (string memory) {
        return string(abi.encodePacked("z", _tryGetAssetSymbol(underlying_)));
    }

    function _tryGetAssetName(IERC20 asset_) private view returns (string memory) {
        (bool success, bytes memory encodedName) = address(asset_).staticcall(abi.encodeCall(IERC20Metadata.name, ()));
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
