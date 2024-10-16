// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IHooks } from "@balancer-labs/v3-interfaces/contracts/vault/IHooks.sol";
import { IRouterCommon } from "@balancer-labs/v3-interfaces/contracts/vault/IRouterCommon.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";
import {
    AfterSwapParams,
    LiquidityManagement,
    SwapKind,
    TokenConfig,
    HookFlags
} from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";

import { EnumerableMap } from "@balancer-labs/v3-solidity-utils/contracts/openzeppelin/EnumerableMap.sol";
import { FixedPoint } from "@balancer-labs/v3-solidity-utils/contracts/math/FixedPoint.sol";
import { VaultGuard } from "@balancer-labs/v3-vault/contracts/VaultGuard.sol";
import { BaseHooks } from "@balancer-labs/v3-vault/contracts/BaseHooks.sol";

contract GovernedLotteryHook is BaseHooks, VaultGuard, Ownable {
    using FixedPoint for uint256;
    using EnumerableMap for EnumerableMap.IERC20ToUint256Map;
    using SafeERC20 for IERC20;

    address private immutable _trustedRouter;

    uint8 public constant LUCKY_NUMBER = 10;
    uint8 public constant MAX_NUMBER = 20;

    uint64 public hookSwapFeePercentage;
    EnumerableMap.IERC20ToUint256Map private _tokensWithAccruedFees;

    uint256 private _counter = 0;

    event LotteryHookExampleRegistered(address indexed hooksContract, address indexed pool);
    event HookSwapFeePercentageChanged(address indexed hooksContract, uint256 hookFeePercentage);
    event LotteryFeeCollected(address indexed hooksContract, IERC20 indexed token, uint256 feeAmount);
    event LotteryWinningsPaid(
        address indexed hooksContract,
        address indexed winner,
        IERC20 indexed token,
        uint256 amountWon
    );

    constructor(IVault vault, address router) VaultGuard(vault) Ownable(msg.sender) {
        _trustedRouter = router;
    }

    /// @inheritdoc IHooks
    function onRegister(
        address,
        address pool,
        TokenConfig[] memory,
        LiquidityManagement calldata
    ) public override onlyVault returns (bool) {
        emit LotteryHookExampleRegistered(address(this), pool);
        return true;
    }

    /// @inheritdoc IHooks
    function getHookFlags() public pure override returns (HookFlags memory) {
        HookFlags memory hookFlags;
        hookFlags.enableHookAdjustedAmounts = true;
        hookFlags.shouldCallAfterSwap = true;
        return hookFlags;
    }

    /// @inheritdoc IHooks
    function onAfterSwap(
        AfterSwapParams calldata params
    ) public override onlyVault returns (bool success, uint256 hookAdjustedAmountCalculatedRaw) {
        uint8 drawnNumber;
        if (params.router == _trustedRouter) {
            drawnNumber = _getRandomNumber();
        }
        _counter++; // Increment the counter to help randomize the number drawn in the next swap

        hookAdjustedAmountCalculatedRaw = params.amountCalculatedRaw;

        if (hookSwapFeePercentage > 0) {
            uint256 hookFee = params.amountCalculatedRaw.mulDown(hookSwapFeePercentage);
            if (params.kind == SwapKind.EXACT_IN) {
                uint256 feeToPay = _chargeFeeOrPayWinner(params.router, drawnNumber, params.tokenOut, hookFee);
                if (feeToPay > 0) {
                    hookAdjustedAmountCalculatedRaw -= feeToPay;
                }
            } else {
                uint256 feeToPay = _chargeFeeOrPayWinner(params.router, drawnNumber, params.tokenIn, hookFee);
                if (feeToPay > 0) {
                    hookAdjustedAmountCalculatedRaw += feeToPay;
                }
            }
        }
        return (true, hookAdjustedAmountCalculatedRaw);
    }

    function setHookSwapFeePercentage(uint64 swapFeePercentage) external onlyOwner {
        hookSwapFeePercentage = swapFeePercentage;
        emit HookSwapFeePercentageChanged(address(this), swapFeePercentage);
    }

    function getRandomNumber() external view returns (uint8) {
        return _getRandomNumber();
    }

    function _chargeFeeOrPayWinner(
        address router,
        uint8 drawnNumber,
        IERC20 token,
        uint256 hookFee
    ) private returns (uint256) {
        if (drawnNumber == LUCKY_NUMBER) {
            address user = IRouterCommon(router).getSender();

            for (uint256 i = _tokensWithAccruedFees.length(); i > 0; i--) {
                (IERC20 feeToken, ) = _tokensWithAccruedFees.at(i - 1);
                _tokensWithAccruedFees.remove(feeToken);

                uint256 amountWon = feeToken.balanceOf(address(this));

                if (amountWon > 0) {
                    feeToken.safeTransfer(user, amountWon);
                    emit LotteryWinningsPaid(address(this), user, feeToken, amountWon);
                }
            }
            return 0;
        } else {
            _tokensWithAccruedFees.set(token, 1);
            if (hookFee > 0) {
                _vault.sendTo(token, address(this), hookFee);
                emit LotteryFeeCollected(address(this), token, hookFee);
            }
            return hookFee;
        }
    }

    function _getRandomNumber() private view returns (uint8) {
        return uint8((uint(keccak256(abi.encodePacked(block.prevrandao, _counter))) % MAX_NUMBER) + 1);
    }
}
