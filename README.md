# VaultGuard 🔐

A secure time-locked savings vault smart contract built on Stacks blockchain using Clarity.

## Overview

VaultGuard allows users to create time-locked savings vaults where STX tokens are securely stored and can only be withdrawn after a specified lock period. This promotes disciplined saving and long-term wealth building.

## Features

- **Time-locked Deposits**: Lock STX for a specified number of blocks
- **Secure Withdrawals**: Only vault owners can withdraw after unlock period
- **Emergency Withdrawals**: Early withdrawal with 10% penalty
- **Multiple Vaults**: Users can create unlimited vaults
- **Transparent Tracking**: View vault details and contract statistics

## Smart Contract Functions

### Public Functions

- `create-vault(amount, lock-duration)` - Create a new time-locked vault
- `withdraw-from-vault(vault-id)` - Withdraw from unlocked vault
- `emergency-withdraw(vault-id)` - Early withdrawal with penalty

### Read-only Functions

- `get-vault(vault-id)` - Get vault details
- `get-total-vaults()` - Get total number of vaults created
- `get-user-vault-count(user)` - Get user's vault count
- `is-vault-unlocked(vault-id)` - Check if vault is unlocked

## Usage

1. **Creating a Vault**
   ```clarity
   (contract-call? .vaultguard create-vault u1000000 u144) ;; Lock 1 STX for 144 blocks (~1 day)
   ```

2. **Withdrawing from Vault**
   ```clarity
   (contract-call? .vaultguard withdraw-from-vault u1)
   ```

3. **Emergency Withdrawal**
   ```clarity
   (contract-call? .vaultguard emergency-withdraw u1) ;; 10% penalty applies
   ```

## Security Features

- Only vault owners can withdraw their funds
- Time-lock prevents premature withdrawals
- Emergency withdrawal option with penalty
- All funds are secured in the contract

## Testing

Run tests using Clarinet:

```bash
clarinet test
```

## Development

This contract is built with Clarinet and follows Stacks ecosystem best practices.

### Prerequisites

- Clarinet CLI
- Stacks blockchain knowledge
- Clarity smart contract understanding

