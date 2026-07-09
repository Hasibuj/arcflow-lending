# ArcFlow Lending Protocol

A protocol-native lending and borrowing platform built specifically for **Arc Network**, focusing on core protocol logic and on-chain capital efficiency.

---

## 🚀 Features

*   **Supply & Earn:** Users can supply supported ERC20 tokens to the pool and earn protocol native interest or rewards (based on logic).
*   **Borrow & Repay:** Secure on-chain borrowing logic against supplied collateral.
*   **Capital Efficiency:** Optimized smart contracts tailored for Arc Network's infrastructure.
*   **Security:** Built using OpenZeppelin's industry-standard contracts (`Ownable`, `ReentrancyGuard`).

---

## 🛠️ Smart Contracts Structure

The core logic resides in `LendingPool.sol`, which handles:
*   Token whitelisting (`addToken`)
*   Liquidity provisioning (`supply`, `withdraw`)
*   Credit operations (`borrow`, `repay`)

### System Architecture Overview

```text
               +-------------------+
               |    LendingPool    |
               +---------+---------+
                         |
      +------------------+------------------+
      |                  |                  |
+-----v-----+      +-----v-----+      +-----v-----+
|  Supply   |      |  Borrow   |      |  Withdraw |
+-----------+      +-----------+      +-----------+
