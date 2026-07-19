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

- Done: add `pUSD` to the SDK vocabulary and docs as the trading collateral layer
- Done: add contract constants for `pUSD`, `CollateralOnramp`, and `CollateralOfframp`
- Done: add ABI helpers for wrapping USDC.e -> pUSD
- Done: add ABI helpers for unwrapping pUSD -> USDC.e
- Done: update EOA and Safe approval helpers to use pUSD collateral approvals
- Done: update CLOB V2 exchange addresses and order domain version
- Done: add high-level helpers that sign and submit wrap/unwrap transactions end to end
- Done: add live wrap/unwrap round-trip test
- Done: audit examples and comments that described accounting values as USDC-denominated (now USD, since pUSD is $1-pegged)

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

- Done: add `getClobMarketInfo`
- Done: add Data API leaderboard support
- Done: add closed positions
- Done: add total portfolio value
- Done: add total markets traded
- Done: add positions-for-market
- Done: add Gamma comments endpoints
- Done: add Gamma series endpoints
- Done: add Gamma sports endpoints
- Done: add Gamma tag relationship endpoints
- Done: add unified search for markets, events, and profiles
- Done: add public profile lookup
- Done: add builder analytics endpoints

### Result

This closes the largest doc-visible holes without introducing new signing complexity.

---

## P1 — combo and RFQ parity

The official docs now expose combos as a first-class feature set. Shipped in v0.5.0:

- Done: combo markets (`ComboClient.getComboMarkets`)
- Done: combo user positions (`ComboClient.getComboPositions`)
- Done: combo user activity (`ComboClient.getComboActivity`)
- Done: quote submission (`ComboClient.submitQuote`)
- Done: quote cancellation (`ComboClient.cancelQuote`)
- Done: confirm/decline last look (`ComboClient.submitConfirmation`)
- Done: Quoter Gateway WebSocket (`QuoterGatewayClient`)

### Design decision taken

Introduced a new `ComboClient` (plus `QuoterGatewayClient`) and left the legacy
`RfqClient` in place. The older RFQ naming can be deprecated later if needed.

---

## P1 — relayer and deposit-wallet workflows

The current official SDK direction is more deposit-wallet and relayer centric than this Dart SDK. Shipped in v0.5.0:

- Done: relayer transaction submission (`RelayerClient.submitTransaction`)
- Done: relayer transaction lookup (`RelayerClient.getTransaction`, `waitForTransaction`)
- Done: relayer recent-transactions query (`RelayerClient.getRecentTransactions`)
- Done: relayer nonce helper (`RelayerClient.getRelayPayload`)
- Done: wallet deployment via relayer (`RelayerClient.deployDepositWallet`)
- Done: relayer API key queries (`RelayerClient.getApiKeys`)
- Remaining: withdrawal-address creation — docs describe withdrawals as relayer `WALLET` batches to the deposit wallet, no separate creation endpoint
- Remaining: higher-level trading-setup abstraction for deposit-wallet onboarding (derive + deploy + first-batch), plus POLY_1271 (`signatureType: 3`) order signing

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

- pUSD contract constants: done
- wrap calldata helper: done
- unwrap calldata helper: done
- pUSD approval migration: done
- CLOB V2 exchange domain migration: done
- high-level wrap/unwrap transaction helpers: done
- live pUSD wrap/unwrap test: done
- `getClobMarketInfo`: done
- leaderboard: done
- closed positions: done
- total value: done
- total markets traded: done
- positions-for-market: done
- series: done
- comments: done
- sports metadata: done
- teams: done
- tag relationships: done
- unified search: done
- public profile: done
- builder analytics: done

### v0.5.0

Focus on combos and relayer breadth:

- combo endpoints: done
- quoter gateway: done
- relayer transaction endpoints: done
- deposit-wallet deploy helper: done
- higher-level unified-client style trading setup: deferred to v0.6.0 (deposit-wallet onboarding + POLY_1271 signing)

### v0.6.0

Focus on WebSocket parity, pUSD position settlement, and deposit-wallet /
unified-SDK alignment. Implemented one piece at a time, in this order:

1. **Authenticated user WebSocket channel** — `wss://ws-subscriptions-clob.polymarket.com/ws/user`
   - subscribe by condition id with `{auth, markets, type: "user"}`
   - inbound `trade` and `order` messages (typed models)
2. **Sports WebSocket channel** — live sports event/score stream
3. **pUSD position settlement** — `split`, `merge`, `redeem` through the pUSD
   CTF collateral adapters (`ctfCollateralAdapter`, `negRiskCtfCollateralAdapter`)
   - parentCollectionId = 32 zero bytes, binary partition `[1, 2]`
   - **blocked on sourcing the exact adapter ABI** — the public docs describe
     the flow but do not publish the adapter's Solidity signatures; confirm
     against `docs.polymarket.com/llms.txt` or the on-chain contract before
     shipping calldata (do not guess signatures)
4. **Deposit-wallet onboarding** — CREATE2 address derivation (UUPS vs
   BeaconProxy via factory `BEACON()` probe) + high-level derive → deploy →
   wait-confirmed helper
5. **POLY_1271 order signing** (`signatureType: 3`) — ERC-7739-wrapped nested
   `TypedDataSign`, domain `{name: "DepositWallet", version: "1",
   verifyingContract: <wallet>, salt: 0}` — validate signatures against a live
   deposit wallet before release
6. **message-format audit** of market/RTDS channels; docs/examples aligned to
   the current official platform story

Sequencing note: items 1–2 are fully specced and low-risk; 3–5 involve
on-chain calldata / signing and must be validated against authoritative ABIs
and a live wallet, not inferred.

**Shipped in 0.6.0:**

- Done: authenticated user WebSocket channel
- Done: sports WebSocket channel
- Done: pUSD settlement calldata — `AbiEncoder.encodeCtf{Split,Merge,Redeem}`
  and `encodeNegRisk{Split,Merge,Redeem,Convert}`, selectors verified against
  the canonical Gnosis CTF values + NegRiskAdapter source, and confirmed live
  via read-only `eth_call` reaching the real functions

**Deferred to 0.6.1** (need validation against a deployed deposit wallet):

- deposit-wallet CREATE2 derivation + onboarding helper
- POLY_1271 (`signatureType: 3`) ERC-7739 order signing
- a higher-level "sign + send" settlement client wrapper (the 0.6.0 encoders are
  pure calldata; the caller currently chooses the target and signs/sends)

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
