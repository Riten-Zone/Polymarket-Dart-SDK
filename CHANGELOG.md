# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-03-05

### Added

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
