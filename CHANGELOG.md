# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-07-18

### Added

- **`ComboClient`** — Combos / RFQ REST client:
  - `getComboMarkets()` — public combo-eligible markets (combos-rfq-api), volume-ordered with cursor pagination
  - `getComboPositions()` / `getComboActivity()` — public user combo positions and lifecycle activity (Data API)
  - `submitQuote()`, `cancelQuote()`, `submitConfirmation()` — Level 2 maker quote flow, including Last Look confirm/decline
- **`QuoterGatewayClient`** — Quoter Gateway WebSocket for market makers: auth handshake, inbound `RFQ_REQUEST` / `RFQ_CONFIRMATION_REQUEST` streams, and outbound quote / cancel / confirmation frames
- **Combo models** — `ComboMarket`, `ComboMarketsPage`, `ComboPosition`(`sPage`), `ComboActivity`(`Page`), `SignedRfqOrder`, `SubmitQuoteParams`, `CancelQuoteParams`, `ConfirmationParams`, `RfqSnapshot`, `RfqRequestEvent`, `RfqConfirmationRequestEvent`, `LastLookDecision`
- **Relayer v2 breadth** — new `RelayerClient` methods: `getRelayPayload()` (address + nonce), `submitTransaction()`, `getTransaction()`, `getRecentTransactions()`, `getApiKeys()`, `deployDepositWallet()` (deposit-wallet `WALLET-CREATE`), and `waitForTransaction()` polling helper
- **Relayer models** — `RelayerPayload`, `RelayerSubmitRequest`, `RelayerSignatureParams`, `SubmitTransactionResult`, `RelayerTransaction` (with `isConfirmed` / `isFailed`), `RelayerApiKey`, `RelayerWalletType`
- **New endpoints/constants** — `combos-rfq-api.polymarket.com`, `relayer-v2.polymarket.com`, and the `combos-rfq-gateway-quoter` WebSocket URL
- **Tests** — offline mock-client coverage for the combo REST flow, the relayer v2 endpoints, and the quoter gateway (auth, inbound routing, outbound frames)

## [0.4.1] - 2026-07-17

### Added

- **pUSD collateral support** — current pUSD, CollateralOnramp, CollateralOfframp, CTF Exchange V2, and Neg-Risk Exchange V2 contract constants
- **`CollateralClient`** — signed live transaction helpers for wrapping USDC.e to pUSD and unwrapping pUSD back to USDC.e
- **pUSD ABI helpers** — `AbiEncoder.encodeWrap()`, `AbiEncoder.encodeUnwrap()`, `AbiEncoder.encodeBalanceOf()`, and exact-amount `encodeApprove()`
- **Live pUSD test** — `test/pusd_live_test.dart` performs a USDC.e -> pUSD -> USDC.e round trip on Polygon
- **`ClobClient.getClobMarketInfo()`** — public CLOB V2 market details endpoint for tokens, fees, rewards, RFQ status, and market flags

### Changed

- EOA and Safe approval helpers now approve pUSD collateral for current CLOB V2 contracts
- CLOB order EIP-712 domain now uses Exchange version `2` and current CLOB V2 exchange addresses

## [0.4.0] - 2026-03-08

### Added

- **`GammaMarket.outcomePrices`** — parsed from the API's JSON-encoded `outcomePrices` string, giving ready-to-use `List<double>` YES/NO prices (e.g. `[0.72, 0.28]`) without extra CLOB calls

## [0.3.1] - 2026-03-08

### Fixed

- **Reward endpoints** — all 6 methods now use correct paths and require Level 2 HMAC auth (previously miscoded as Level 0 public)
  - `getEarningsForDay` → `GET /rewards/user` (added required `address` param)
  - `getTotalEarningsForDay` → `GET /rewards/user/total`
  - `getUserEarningsAndMarketsConfig` → `GET /rewards/user/markets`
  - `getRewardPercentages` → `GET /rewards/user/percentages` (added `signature_type: 0` param)
  - `getCurrentRewards` → `GET /rewards/markets/current`
  - `getRawRewardsForMarket` → `GET /rewards/markets/{conditionId}` (path param, not query string)
- **`DataClient.getLeaderboard` removed** — no public leaderboard endpoint exists on Polymarket's Data API
- Reward integration tests updated to use Level 2 credentials from `.env`

---

## [0.3.0] - 2026-03-07

### Added

- **ClobClient parity with Python SDK** — 4 additional methods
  - `getSamplingSimplifiedMarkets()` — `GET /sampling-simplified-markets`
  - `getOrderBookHash(tokenId)` — `GET /order-book-hash` for a given token
  - `calculateMarketPrice(tokenId, side, amount)` — walks the live orderbook to estimate fill price
  - `createAndPostOrder(params)` — convenience wrapper: builds, signs, and posts an order in one call
- **RfqClient** — full Request-for-Quote system (`https://clob.polymarket.com/rfq/...`)
  - `createRequest()`, `cancelRequest()`, `acceptQuote()` — requester side
  - `createQuote()`, `cancelQuote()`, `approveOrder()` — quoter (market-maker) side
  - `getRequests()`, `getRequesterQuotes()`, `getQuoterQuotes()`, `getBestQuote()`, `getConfig()` — data queries
  - All methods require Level 2 HMAC auth
- **BridgeClient** — cross-chain deposit API (`https://bridge.polymarket.com`)
  - `createDeposit(address)` — generate EVM + Solana + Bitcoin deposit addresses
  - `getSupportedAssets()` — discover supported chains and tokens
  - `getQuote(params)` — estimate fees and output amounts
  - `getStatus(address)` — track deposit progress by deposit address
  - No authentication required
- **Builder API extension** to `ClobClient`
  - `getBuilderOrders()`, `getBuilderOpenOrders()`, `getBuilderTrades()` — attributed order/trade queries
  - `revokeBuilderApiKey()` — revoke builder credentials
  - `getBuilderLeaderboard()` — `GET /v1/builders/leaderboard` (public)
  - Constructor now accepts `BuilderCredentials? builderCredentials`
- **`builder_auth.dart`** — extracted `BuilderCredentials` and `generateBuilderHeaders()` from `RelayerClient`
  - `RelayerClient` now imports and re-exports from `builder_auth.dart` (no breaking change)
- New models: `RfqUserRequest`, `RfqUserQuote`, `RfqRequest`, `RfqQuote`, `RfqPaginatedResponse<T>`, `AcceptQuoteParams`, `ApproveOrderParams`, `CancelRfqRequestParams`, `CancelRfqQuoteParams`, `GetRfqRequestsParams`, `GetRfqQuotesParams`, `GetRfqBestQuoteParams`, `RfqRequestResponse`, `RfqQuoteResponse`, `MatchType` (RFQ)
- New models: `DepositAddresses`, `DepositResponse`, `SupportedAsset`, `TokenInfo`, `BridgeQuoteParams`, `BridgeQuote`, `FeeBreakdown`, `DepositTransaction`, `DepositStatus`, `DepositState` (Bridge)
- New model: `BuilderLeaderboardEntry`
- `PolymarketUrls.bridge` constant added
- Neg-risk guide added to `docs/plan/GUIDES.md`
- 8 new integration tests (bridge: 5, rfq: 3)

---

## [0.2.0] - 2026-03-05

### Added

- **GammaClient** — market and event discovery via `https://gamma-api.polymarket.com`
  - `getMarkets()` — list markets with filters (active, closed, order, limit)
  - `getMarket(int id)` — single market by numeric ID
  - `getEvents()` — list events with filters
  - `getEvent(int id)` — single event by numeric ID
  - `getTags()` — all category tags
  - `searchMarkets(String query)` — text search
- **DataClient** expanded with 4 new methods
  - `getTrades(userAddress)` — completed trades for a user
  - `getActivity(userAddress)` — activity events (trades, redemptions, etc.)
  - `getHolders(conditionId)` — outcome token holders for a market
  - `getLeaderboard()` — top traders (path TBD)
- **ClobClient** — 10 new methods
  - Rewards (Level 0): `getRewardPercentages`, `getCurrentRewards`, `getEarningsForDay`, `getTotalEarningsForDay`, `getUserEarningsAndMarketsConfig`, `getRawRewardsForMarket`
  - Read-Only API Keys (Level 2): `createReadonlyApiKey`, `getReadonlyApiKeys`, `deleteReadonlyApiKey`, `validateReadonlyApiKey`
- New models: `GammaMarket`, `GammaEvent`, `Tag`, `UserTrade`, `Activity`, `Holder`, `LeaderboardEntry`
- 17 new integration tests (80 total)

---

## [0.1.0] - 2026-03-03

### Added

- **ClobClient** — 42 methods across 3 authentication levels
  - Level 0 (public): markets, orderbook, pricing, price history, market config
  - Level 1 (EIP-712): API key creation and management
  - Level 2 (HMAC): order placement, cancellation, account data, notifications
- **DataClient** — user positions and proxy wallet lookup
- **WebSocketClient** — real-time CLOB orderbook/trades and RTDS price/comment feeds
- **RelayerClient** — gasless GnosisSafe approvals via Polymarket relayer
- **EIP-712 signing** — ClobAuth (Level 1) and Order signing for EOA and GnosisSafe wallets
- **HMAC auth** — Level 2 request signing matching Python SDK behavior
- **On-chain approvals** — `ensureEoaApprovals()` for direct EOA setup (7 transactions)
- **PrivateKeyWalletAdapter** — full secp256k1 ECDSA with EIP-155 raw transaction signing
- 63 tests (23 unit + 40 integration)
