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

- `GammaClient`: markets, events, tags, market search
- `DataClient`: positions, proxy wallet lookup, trades, activity, holders
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
- No first-class `pUSD` collateral model in the SDK surface.
- No helpers for `pUSD` wrap or unwrap via `CollateralOnramp` / `CollateralOfframp`.
- The SDK still documents and names collateral primarily as USDC or USDC.e rather than pUSD-backed trading collateral.
- No `getClobMarketInfo` endpoint.
- No documented Data API leaderboard implementation.
- No closed positions, total portfolio value, total markets traded, or positions-for-market endpoints.
- No builder analytics client for aggregated leaderboard and daily builder volume.
- No Gamma coverage for comments, series, sports, richer tag relationships, or event/market slug helpers.
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
