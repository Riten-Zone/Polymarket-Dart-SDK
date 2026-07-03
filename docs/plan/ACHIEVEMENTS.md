# Achievements — `polymarket_dart`

Last reviewed against the official Polymarket docs on 2026-06-24.

---

## Current verified state

The Dart SDK is no longer just a basic CLOB wrapper. It already covers a meaningful slice of Polymarket:

- Core CLOB trading and market data
- L1 and L2 auth flows
- API key lifecycle, including readonly keys
- Rewards endpoints
- Builder endpoints
- Bridge endpoints
- Relayer-backed Safe approval flow
- Legacy RFQ client
- Gamma and Data API starter coverage
- CLOB market and RTDS WebSocket coverage

That means the SDK is still ahead of "toy client" status and remains usable for live trading integrations.

One important correction to the previous review:

- the official platform now treats `pUSD` as the trading collateral token
- the official client story is now split between legacy `clob-client-v2` style clients and newer unified SDK beta flows

That changes the shape of the gap. The SDK is not just missing extra endpoints; it is also behind the current collateral and onboarding model.

---

## v0.4.1 — pUSD + CLOB V2 foundation (2026-06-24)

Added the first slice of the pUSD/CLOB V2 roadmap:

- current pUSD collateral contract constants
- `CollateralOnramp` and `CollateralOfframp` constants
- current CTF Exchange V2 and Neg-Risk CTF Exchange V2 constants
- legacy exchange aliases for migration tooling
- pUSD collateral approval flow for EOA approvals
- pUSD collateral approval flow for Safe multisend approvals
- `AbiEncoder.encodeWrap()` for USDC.e -> pUSD calldata
- `AbiEncoder.encodeUnwrap()` for pUSD -> USDC.e calldata
- exact-amount ERC-20 approval encoding via `AbiEncoder.encodeApprove(..., amount: ...)`
- `CollateralClient.wrapUsdcToPusd()` for signed wrap transactions
- `CollateralClient.unwrapPusdToUsdc()` for signed unwrap transactions
- `CollateralClient.balanceOf()`, `allowance()`, and `nativeBalance()` read helpers
- CLOB V2 EIP-712 order domain version `"2"`

New tests:

- `test/pusd_test.dart` validates pUSD/collateral/v2 exchange constants and wrap/unwrap calldata
- `test/pusd_live_test.dart` submits a live USDC.e -> pUSD -> USDC.e round trip
- `test/eip712_test.dart` now validates CLOB V2 exchange domain addresses and version
- `test/approvals_test.dart` now reads pUSD collateral allowance instead of USDC.e allowance

---

## v0.4.1 — `getClobMarketInfo` parity (2026-06-24)

Added the public CLOB V2 market-details endpoint:

- `ClobClient.getClobMarketInfo(conditionId)`
- `ClobMarketInfo`, `ClobMarketInfoToken`, and `ClobMarketFeeDetails` models
- live integration coverage in `test/clob_client_test.dart`

The model exposes stable documented fields and preserves the raw response map for compact or newly added CLOB keys.

---

## What still matches the official docs

These areas are implemented and still broadly aligned with the current official documentation:

### CLOB

- Server time
- Markets listing and single-market fetch
- Sampling and simplified market endpoints
- Order book, midpoint, market price, spread, last trade, fee rate, tick size
- Price history
- Order creation, posting, cancel flows, and open-order queries
- Trades, balance allowance, notifications, order scoring, heartbeat
- Rewards methods
- Builder trades and builder leaderboard

### Auth and trading setup

- L1 EIP-712 auth
- L2 HMAC auth
- EOA approval flow
- Gnosis Safe approval flow through the relayer

### Other clients

- `GammaClient`: markets, events, tags, series, comments, sports metadata,
  teams, tag relationships, market search, unified search, public profile lookup
- `DataClient`: positions, proxy wallet lookup, trades, activity, holders,
  leaderboard, closed positions, total value, total markets traded, positions for market,
  builder leaderboard, builder daily volume
- `BridgeClient`: supported assets, deposit address creation, quote, status
- `WebSocketClient`: market orderbook/trades plus RTDS price/comments

---

## Gap review vs current official docs

The official docs now expose a larger surface than this SDK currently implements.

### Major additions in the official docs since this plan was last current

- Official unified TypeScript and Python SDKs are now documented in beta, alongside the older CLOB SDKs.
- The older official CLOB SDKs are now explicitly documented as v2 clients:
  `@polymarket/clob-client-v2`, `py-clob-client-v2`, and `polymarket_client_sdk_v2`.
- Trading setup now centers on Deposit Wallet and Relayer flows in the new SDK docs, not just raw EOA or Safe approval plumbing.
- `pUSD` is now documented as the collateral token used for all trading on Polymarket, with explicit onchain wrap and unwrap flows:
  USDC.e -> pUSD through `CollateralOnramp`, and pUSD -> USDC.e through `CollateralOfframp`.
- Combos are now a first-class documented surface:
  `GET combo markets`, `GET user combo positions`, `GET user combo activity`,
  `POST submit quote`, `POST cancel quote`, `POST confirm/decline last look`,
  and `WSS quoter gateway`.
- Gamma/Data docs now cover more discovery and analytics endpoints:
  comments, series, sports, profile lookup, leaderboard, positions for market,
  total value, total markets traded, accounting snapshot, builder analytics.
- CLOB docs now explicitly include `get CLOB market info`, heartbeat, order scoring,
  builder trades, and more complete WebSocket docs including user and sports channels.
- Relayer docs now expose more than approvals:
  transaction submit/query, recent transactions, nonce queries, wallet deployment checks,
  relayer API keys.

---

## Confirmed missing or incomplete areas

### High-confidence gaps

- No support for the documented Combo API surface.
- No support for the Quoter Gateway WebSocket.
- No authenticated user-channel WebSocket support.
- No sports WebSocket support.
- pUSD support exists for constants, approvals, wrap/unwrap calldata, and live EOA wrap/unwrap transaction submission.
- No Gamma coverage for event/market slug helpers.
- No relayer client coverage beyond the custom approval flow.
- No current Deposit Wallet workflow abstraction matching the official unified SDK docs.

### Needs audit, not assumed broken

- `BridgeClient` naming and response modeling should be aligned to the current docs:
  "create bridge addresses", "create withdrawal addresses", "transaction status",
  and "deposit from other chains auto-wraps to pUSD".
- `RfqClient` likely reflects an older RFQ shape and should be audited against the new Combo/RFQ docs before adding features on top of it.
- WebSocket message formats should be rechecked against the current `Market Channel`, `User Channel`, `Sports Channel`, `RTDS`, and `Quoter Gateway` docs.

---

## Bottom line

As of 2026-06-24, `polymarket_dart` is strong on the older direct-CLOB integration model: market data, auth, rewards, builder basics, and initial Gamma/Data support.

The biggest gap is that Polymarket's official platform story has moved beyond "CLOB only":

- pUSD collateral
- CLOB v2 plus unified SDK beta workflows
- unified SDK workflows
- deposit wallet / relayer-first onboarding
- combos
- broader Gamma/Data discovery
- richer WebSocket coverage

Those areas now define the next phase of the SDK rather than incremental fixes to the March 2026 roadmap.
