# Roadmap — `polymarket_dart`

Current roadmap after reviewing the SDK against the official Polymarket docs on 2026-06-24.

---

## Status summary

The SDK already has strong coverage for:

- legacy direct-CLOB trading
- L1 and L2 auth
- EOA and Safe approval flows
- rewards
- builder basics
- bridge basics
- starter Gamma and Data clients
- market-data WebSockets

The next roadmap should not focus on small CLOB cleanup. The main gap is platform breadth and platform model drift.

Two shifts now need to be explicit in the roadmap:

- Polymarket documents `pUSD` as the collateral token used for all trading
- Polymarket now documents both legacy CLOB v2 SDKs and newer unified SDK beta flows

---

## Completed foundation

These are effectively done and should stay marked complete:

- Core CLOB client
- Live auth and order placement validation
- EOA approval flow
- Gnosis Safe approval flow through relayer
- Rewards endpoints
- Readonly API keys
- Builder leaderboard and builder trade endpoints
- Bridge client
- Gamma client initial release
- Data client initial release
- RTDS and market WebSocket support

---

## Priority roadmap

## P0 — pUSD and CLOB v2 alignment

Before treating the rest of the roadmap as endpoint parity work, the SDK docs and abstractions need to reflect the current trading model.

### Collateral model

- Add `pUSD` to the SDK vocabulary and docs as the trading collateral layer
- Add contract constants for `pUSD`, `CollateralOnramp`, and `CollateralOfframp`
- Add helpers for wrapping USDC.e -> pUSD
- Add helpers for unwrapping pUSD -> USDC.e
- Audit approval and balance language that still assumes raw USDC is the user-facing trading collateral
- Update examples and comments that still describe trading collateral as only USDC or USDC.e

### Official client direction

- Mark the current Dart SDK as closest to the legacy direct CLOB v2 client model
- Add a roadmap note for compatibility with the newer unified SDK beta flow
- Audit where a higher-level secure client abstraction should exist in Dart

### Result

This prevents the SDK from staying conceptually pinned to a pre-pUSD mental model.

---

## P0 — align with the current official docs

These are the highest-value gaps because they are clearly documented today and materially expand SDK parity.

### Public REST parity

- Add `getClobMarketInfo`
- Add Data API leaderboard support
- Add closed positions
- Add total portfolio value
- Add total markets traded
- Add positions-for-market
- Add builder analytics endpoints
- Add Gamma comments endpoints
- Add Gamma series endpoints
- Add Gamma sports endpoints
- Add Gamma tag relationship endpoints
- Add unified search for markets, events, and profiles
- Add public profile lookup

### Result

This closes the largest doc-visible holes without introducing new signing complexity.

---

## P1 — combo and RFQ parity

The official docs now expose combos as a first-class feature set. This SDK currently does not match that surface.

- Add combo markets
- Add combo user positions
- Add combo user activity
- Add quote submission
- Add quote cancellation
- Add confirm/decline last look
- Add Quoter Gateway WebSocket

### Design decision required

Pick one of:

- keep `RfqClient` and retrofit it to the current combo docs
- introduce a new `ComboClient` and leave `RfqClient` as legacy

Preferred direction: add `ComboClient` and deprecate the older RFQ naming later if needed.

---

## P1 — relayer and deposit-wallet workflows

The current official SDK direction is more deposit-wallet and relayer centric than this Dart SDK.

- Add withdrawal-address creation
- Add relayer transaction submission
- Add relayer transaction lookup
- Add relayer recent-transactions query
- Add relayer nonce helpers
- Add wallet deployment check
- Add relayer API key queries
- Add a higher-level trading setup abstraction for deposit-wallet onboarding

### Result

This moves the Dart SDK closer to the documented onboarding flow used by the new official SDKs.

---

## P2 — WebSocket parity

- Add authenticated user channel
- Add sports channel
- Audit market-channel payloads against the current docs
- Audit RTDS ping/subscription format against the current docs
- Add combo/quoter gateway streaming support

### Result

This completes real-time parity and reduces uncertainty around currently inferred message formats.

---

## P2 — developer-experience improvements

- Add examples that mirror the current official docs, not only the older CLOB flows
- Add integration tests for new public endpoints
- Add opt-in live tests for relayer and combo flows
- Add a single coverage matrix in the repo root or docs folder

---

## Explicit non-priority items

These should not be the next focus unless directly needed by the app:

- a Privy adapter before the official API surface gap is closed
- cosmetic refactors without parity gains
- more March 2026 cleanup on already-working CLOB methods

The SDK is already beyond the point where "more basic CLOB polish" is the bottleneck.

---

## Short-term milestone proposal

### v0.4.0

Focus on pUSD and public REST parity:

- pUSD contract constants
- wrap helper
- unwrap helper
- `getClobMarketInfo`
- leaderboard
- closed positions
- total value
- total markets traded
- positions-for-market
- series
- comments
- sports metadata
- teams
- tag relationships
- unified search
- public profile

### v0.5.0

Focus on combos and relayer breadth:

- combo endpoints
- quoter gateway
- relayer transaction endpoints
- deposit-wallet workflow helpers
- higher-level unified-client style trading setup

### v0.6.0

Focus on WebSocket and unified-SDK alignment:

- user channel
- sports channel
- message-format audit cleanup
- docs/examples aligned to the current official platform story

---

## Bottom line

As of 2026-06-24, the SDK is solid on the older direct CLOB integration style but behind the current official docs in six areas:

- pUSD collateral alignment
- unified / CLOB v2 client direction
- combo support
- relayer and deposit-wallet workflows
- broader Gamma/Data coverage
- full WebSocket parity

That is the real roadmap now.
