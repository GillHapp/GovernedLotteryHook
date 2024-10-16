

# 🎲 GovernedLotteryHook Contract

The `GovernedLotteryHook` is a smart contract built on top of the Balancer V3 protocol to act as a customizable fee hook during token swaps. The unique feature of this contract is the lottery mechanism embedded into its logic. Whenever a swap happens, there's a chance for users to win accumulated fees if a lucky number is drawn.

## 🔑 Key Features

- **Swap Fee Hook**: A fee can be applied to every swap, with adjustable percentages controlled by the contract owner.
- **Lottery Mechanism**: For every swap, a random number is drawn. If the number matches the predefined lucky number, the user wins the accumulated fees.
- **Trusted Router**: Only swaps routed through a trusted router are eligible for the lottery.
- **Accrued Fees**: Accrued fees are stored in the contract until a lottery winner is drawn.

## 📝 Contract Summary

This contract implements several key features using Balancer’s `IHooks` and integrates with a trusted router for secure transactions. Below is a detailed breakdown of the main functionality.

### ⚙️ Constructor

```solidity
constructor(IVault vault, address router) VaultGuard(vault) Ownable(msg.sender)
```

- **VaultGuard**: The contract is built around the Balancer vault system.
- **Router**: The `router` address is set as the trusted router, which ensures that swaps from specific routes are the only ones eligible for the lottery mechanism.

### 🔄 Hook-Related Functions

#### `onRegister`

```solidity
function onRegister(
    address,
    address pool,
    TokenConfig[] memory,
    LiquidityManagement calldata
) public override onlyVault returns (bool)
```

This function is called when the hook is registered with a pool. It emits an event to confirm registration.

#### `onAfterSwap`

```solidity
function onAfterSwap(
    AfterSwapParams calldata params
) public override onlyVault returns (bool success, uint256 hookAdjustedAmountCalculatedRaw)
```

- **AfterSwap Logic**: This is the core of the contract. It applies fees on swaps and triggers the lottery mechanism.
- **Lottery**: Each time a swap is executed, a random number is generated. If the random number matches the lucky number, the user wins the accrued fees stored in the contract.
- **Fee Collection**: The contract collects a swap fee (if set) for every transaction and stores it in the `_tokensWithAccruedFees` map for potential winners.

### 💸 Fees & Lottery

#### `setHookSwapFeePercentage`

```solidity
function setHookSwapFeePercentage(uint64 swapFeePercentage) external onlyOwner
```

This function allows the contract owner to set the swap fee percentage (in basis points). The fees will be collected on every swap, and the amount collected can be adjusted.

#### `getRandomNumber`

```solidity
function getRandomNumber() external view returns (uint8)
```

This view function returns the generated random number used in the lottery system. This random number is based on the block's randomness and the internal counter.

#### `_chargeFeeOrPayWinner`

```solidity
function _chargeFeeOrPayWinner(
    address router,
    uint8 drawnNumber,
    IERC20 token,
    uint256 hookFee
) private returns (uint256)
```

- If the drawn number matches the lucky number, the user wins the accumulated fees.
- If the drawn number does not match, the accrued fees are stored in `_tokensWithAccruedFees`, and the hook fee is sent to the contract.

### 🎰 Lottery Parameters

- **LUCKY_NUMBER**: `10` – The predefined lucky number.
- **MAX_NUMBER**: `20` – The range of possible numbers (1 to 20).
- **hookSwapFeePercentage**: The fee applied to each swap, which can be adjusted by the owner.

### 🔐 Security & Access Control

The contract is owned by a single owner (set during deployment), who can adjust the fee percentage.

- **Ownable**: The contract uses the `Ownable` pattern from OpenZeppelin, giving control over the swap fee percentage to the owner.
- **VaultGuard**: This ensures that only the Balancer vault can interact with the hooks.

## 🔍 Functions Overview

| Function                   | Description                                                                             |
| -------------------------- | --------------------------------------------------------------------------------------- |
| `onRegister`               | Registers the hook with the Balancer vault.                                             |
| `getHookFlags`             | Returns the flags that enable the hook's adjusted amounts and the call after swap.      |
| `onAfterSwap`              | Executes after each swap, applying fees and triggering the lottery mechanism.           |
| `setHookSwapFeePercentage` | Allows the owner to set the swap fee percentage.                                        |
| `getRandomNumber`          | Returns the current random number generated for the lottery mechanism.                  |
| `_chargeFeeOrPayWinner`    | Internal function that charges the fee or pays the winner if they hit the lucky number. |

## 📦 Deployment

1. **Prerequisites**:
   - Ensure the Balancer Vault address is known.
   - Set the address of the trusted router for secure transaction routing.

2. **Deploying the Contract**:

```solidity
IVault vault = IVault(vaultAddress);
address router = trustedRouterAddress;

GovernedLotteryHook lotteryHook = new GovernedLotteryHook(vault, router);
```

Once deployed, the contract will start managing swaps and collecting fees, as well as enabling users to participate in the lottery mechanism.

## ⚠️ Important Notes

- **Owner Controls**: Only the contract owner can change the swap fee percentage.
- **Randomness**: The random number generation is based on the `block.prevrandao` and an internal counter. While this provides basic randomness, it may not be fully secure in highly adversarial environments.
- **Accrued Fees**: The contract accumulates fees until a user wins the lottery, so ensure the contract has sufficient funds to handle payouts.

## 📜 Events

- **LotteryHookExampleRegistered**: Emitted when the contract is registered as a hook for a pool.
- **HookSwapFeePercentageChanged**: Emitted when the owner changes the fee percentage.
- **LotteryFeeCollected**: Emitted when a swap fee is collected.
- **LotteryWinningsPaid**: Emitted when a user wins the lottery, along with the amount and token paid out.
