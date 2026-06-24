# Guides — `polymarket_dart`

Working guide for closing the gap between the current Dart SDK and the official Polymarket docs.

Last reviewed on 2026-06-24.

---

## Source of truth

Use the official docs first, then verify against the official SDK repos when the docs are ambiguous.

- Docs index: https://docs.polymarket.com/llms.txt
- API intro: https://docs.polymarket.com/api-reference/introduction
- Clients & SDKs: https://docs.polymarket.com/api-reference/clients-sdks
- TypeScript unified SDK beta: https://docs.polymarket.com/dev-tooling/typescript
- Python unified SDK beta: https://docs.polymarket.com/dev-tooling/python

Do not extend the Dart SDK from the older March 2026 roadmap alone. It is now missing official surface area.

---

## Current comparison rules

When deciding whether something is "done", use this standard:

1. The endpoint or WebSocket channel is explicitly documented in the official docs.
2. The Dart client has a public method or stream that maps cleanly to it.
3. The request model, auth level, and response model match the docs.
4. There is at least one live or fixture-backed test proving the shape.

If any of those are missing, treat the item as incomplete.

---

## Gap map by area

### CLOB

Already covered well:

- Market data
- Order entry and cancellation
- Balance allowance
- Notifications
- Order scoring
- Heartbeats
- Rewards
- Some builder endpoints

Still missing or incomplete:

- `getClobMarketInfo`
- explicit fee-rate path variant support
- explicit tick-size path variant support
- better alignment with current unified SDK trading abstractions

### Gamma API

Already covered:

- markets
- events
- tags
- simple market search

Still missing:

- event by slug
- market by slug
- market-by-token style helpers where applicable
- series
- comments
- sports metadata and teams
- richer tag relation endpoints
- unified search across markets, events, and profiles
- public profile endpoint support

### Data API

Already covered:

- positions
- proxy wallet lookup
- trades
- activity
- holders

Still missing:

- closed positions
- total value of user positions
- total markets traded by user
- positions for a market
- trader leaderboard rankings
- builder analytics endpoints
- accounting snapshot download
- combo positions
- combo activity

### Bridge and relayer

Already covered:

- supported assets
- quote
- deposit-address creation
- status
- custom relayer-backed Safe approvals

Still missing:

- withdrawal-address creation parity
- relayer transaction submit/query endpoints
- relayer recent-transactions endpoints
- relayer nonce and wallet-deployment helpers
- relayer API key helpers
- deposit-wallet workflow abstraction matching the current official SDK direction

### WebSockets

Already covered:

- market orderbook
- market trades
- RTDS prices
- RTDS comments

Still missing:

- authenticated user channel
- sports channel
- combo/RFQ quoter gateway
- current message-format audit against the live docs

### Combos / RFQ

Current risk:

- the local `RfqClient` looks legacy relative to the current docs

Required next audit:

- combo markets
- submit quote
- cancel quote
- confirm or decline last look
- combo user positions
- combo user activity
- quoter gateway WebSocket

Do not assume the existing RFQ client maps 1:1 to the current docs without revalidation.

---

## Recommended implementation order

### Phase 1: fill obvious public-data gaps

Implement public endpoints that do not require new auth flows:

- `getClobMarketInfo`
- trader leaderboard
- closed positions
- total value
- total markets traded
- series
- comments
- sports metadata
- teams
- tag relationship endpoints
- unified search

This gives the fastest increase in official coverage with the lowest risk.

### Phase 2: add combo parity

Implement the documented combo endpoints and then decide whether to:

- rename `RfqClient` to reflect the current docs, or
- keep `RfqClient` but add a new `ComboClient`

The second option is cleaner if backward compatibility matters.

### Phase 3: expand relayer and deposit-wallet support

Add a first-class relayer/deposit-wallet workflow instead of keeping relayer logic limited to Safe approvals.

This is where the official unified SDKs have moved, so Dart should not stay pinned to only raw-key trading patterns.

### Phase 4: close WebSocket parity

Add:

- user channel
- sports channel
- quoter gateway

Then verify subscription and ping behavior against live endpoints.

---

## Testing guidance

For each new area:

- prefer real API tests for public REST endpoints
- use live opt-in tests for auth-sensitive endpoints
- keep parsing tests for weird response shapes
- record exact auth assumptions in the test name or comment

Specific caution areas:

- query-param names often differ from obvious guesses
- some IDs are strings even when they look numeric
- cursor pagination is now documented more explicitly
- docs may describe both query-param and path-param variants for the same resource

---

## Documentation update rule

Whenever a new endpoint is implemented:

1. update `ROADMAP.md`
2. add a short note to `ACHIEVEMENTS.md`
3. add or revise a usage example only if the API is verified

That keeps plan docs synchronized with real implementation state instead of drifting behind the official docs again.
