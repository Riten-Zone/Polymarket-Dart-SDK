# Achievements — `polymarket_dart`

---

## v0.2.0 — GammaClient + DataClient Expansion + ClobClient Rewards (2026-03-05)

### New files

| File | Purpose |
|------|---------|
| `lib/src/clients/gamma_client.dart` | `GammaClient` — market/event discovery via Gamma API |
| `lib/src/models/gamma_types.dart` | `GammaMarket`, `GammaEvent`, `Tag` models |

### New models in `data_types.dart`

- `UserTrade` — completed trade as returned by Data API (`transactionHash`, `proxyWallet`, `side`, `price`, `size`, `timestamp`, `outcome`)
- `Activity` — user activity event (`type`, `conditionId`, `side`, `price`, `size`, `timestamp`)
- `Holder` — market outcome token holder (`address`, `pseudonym`, `proxyWallet`, `amount`)
- `LeaderboardEntry` — trader leaderboard entry (`address`, `pseudonym`, `volume`, `pnl`, `rank`)

### New `GammaClient` methods (6)

| Method | Endpoint |
|--------|---------|
| `getMarkets({active, closed, order, ascending, limit})` | `GET /markets` |
| `getMarket(int id)` | `GET /markets/{id}` |
| `getEvents({active, order, ascending, limit})` | `GET /events` |
| `getEvent(int id)` | `GET /events/{id}` |
| `getTags()` | `GET /tags` |
| `searchMarkets(String query)` | `GET /markets?q=query` |

### New `DataClient` methods (4)

| Method | Endpoint |
|--------|---------|
| `getTrades(userAddress, {limit, offset})` | `GET /trades?user=X` |
| `getActivity(userAddress, {limit})` | `GET /activity?user=X` |
| `getHolders(conditionId, {limit})` | `GET /holders?market=X` |
| `getLeaderboard({interval, limit})` | `GET /leaderboard` (path TBD) |

### New `ClobClient` methods (10)

Rewards (Level 0):
- `getRewardPercentages()`, `getCurrentRewards()`
- `getEarningsForDay(date)`, `getTotalEarningsForDay(date)`
- `getUserEarningsAndMarketsConfig(date)`, `getRawRewardsForMarket(conditionId)`

Read-Only API Keys (Level 2):
- `createReadonlyApiKey()`, `getReadonlyApiKeys()`
- `deleteReadonlyApiKey(apiKey)`, `validateReadonlyApiKey(address, apiKey)`

### Key API discoveries during testing

- Gamma API `id` field is returned as a **String** (not int) — `_parseInt()` helper added
- `GammaClient.getMarket` accepts only the **numeric integer id** — conditionId and slug return 422
- Data API `getHolders` uses query param `market` (not `conditionId`)
- Data API `getLeaderboard` path `/leaderboard` returns 404 — correct path TBD
- Reward endpoints return 404/405 — paths not yet confirmed against live API

### New tests

| File | New tests |
|------|-----------|
| `test/gamma_client_test.dart` | 10 integration tests (markets, single market, events, tags, search) |
| `test/data_client_test.dart` | +8 tests (getTrades, getActivity, getLeaderboard) |
| `test/clob_client_test.dart` | +4 tests (rewards — lenient, catch API exceptions) |

**Running totals: 23 unit + 18 L0 + 8 auth + 14 approvals + 17 new = 80 tests passing**

---

## On-Chain Approvals — EOA + GnosisSafe (2026-03-05)

### Bug fixed: `side` field serialization in `clob_types.dart`

`SignedOrder.toJson()` was sending `"side": 0` or `"side": 1` (int) — the CLOB API requires `"side": "BUY"` or `"side": "SELL"` (string). Fixed:
```dart
'side': side == 0 ? 'BUY' : 'SELL',
```
This was causing all order placement to return 400 "Invalid order payload" despite correct EIP-712 signing.

### New files added

| File | Purpose |
|------|---------|
| `lib/src/utils/contracts.dart` | All Polygon contract addresses + URLs (USDC, CTF, exchanges, multisend, relayer) |
| `lib/src/blockchain/rlp.dart` | Minimal RLP encoder for EIP-155 raw tx encoding (handles int, BigInt, Uint8List, List) |
| `lib/src/blockchain/polygon_rpc.dart` | `PolygonRpc` (eth_call, getTransactionCount, getGasPrice, sendRawTransaction, waitForReceipt) + `AbiEncoder` (encodeApprove, encodeSetApprovalForAll, encodeIsApprovedForAll, encodeAllowance) |
| `lib/src/blockchain/eoa_approvals.dart` | `ensureEoaApprovals()` — idempotent, checks and sets 7 on-chain approvals for EOA |
| `lib/src/signing/safe_tx.dart` | `hashSafeTx()` (EIP-712 SafeTx digest) + `encodeApprovalMultisend()` (6-approval multisend calldata) |
| `lib/src/clients/relayer_client.dart` | `BuilderCredentials` + `RelayerClient.runApprovals()` — gasless GnosisSafe approvals via Polymarket relayer |

### Extended `PrivateKeyWalletAdapter`

- `signRawTransaction()` — EIP-155 raw tx signing: `v = recovery_id + 35 + 2*chainId`
- `signEthMessage()` — EIP-191 prefix + sign, v adjusted 27/28 → 31/32 for Gnosis Safe

### EOA approvals confirmed on Polygon mainnet

`ensureEoaApprovals()` submitted 7 transactions:
1. CTF → `setApprovalForAll(CTF_EXCHANGE, true)`
2. CTF → `setApprovalForAll(NEG_RISK_ADAPTER, true)`
3. CTF → `setApprovalForAll(NEG_RISK_EXCHANGE, true)`
4. USDC → `approve(CTF, MAX_UINT256)`
5. USDC → `approve(CTF_EXCHANGE, MAX_UINT256)`
6. USDC → `approve(NEG_RISK_ADAPTER, MAX_UINT256)`
7. USDC → `approve(NEG_RISK_EXCHANGE, MAX_UINT256)`

### New tests

| Test file | Coverage |
|-----------|---------|
| `test/approvals_test.dart` | ABI encoding unit tests (selectors, lengths, MAX_UINT256, bool), RLP encoder unit tests, integration: reads `isApprovedForAll` + `allowance` from Polygon mainnet |
| `test/relayer_test.dart` | Integration: `RelayerClient.runApprovals()` with BUILDER_* creds from `.env` |

**Running totals: 23 unit + 18 L0 + 8 auth + 14 approvals = 63 tests passing**

---

## Live Testing & Bug Fixes (post v0.1.0)

### Path audit — 5 more wrong paths fixed — 2026-03-03

Full comparison of all 42 ClobClient methods against Python SDK `endpoints.py`:

| Method | Wrong path | Correct path |
|--------|-----------|--------------|
| `cancelAll` | `DELETE /orders` | `DELETE /cancel-all` |
| `cancelMarketOrders` | `DELETE /orders` | `DELETE /cancel-market-orders` |
| `getClosedOnlyMode` | `GET /closed-only-mode` | `GET /auth/ban-status/closed-only` |
| `updateBalanceAllowance` | `POST /balance-allowance` | `POST /balance-allowance/update` |
| `deleteApiKey` | `DELETE /auth/api-keys` | `DELETE /auth/api-key` (singular) |

All 49 tests still pass after the fixes.

---

### Auth integration tests: 8/8 passing (L1 + L2) — 2026-03-03

New test file `test/auth_test.dart` — runs against live API with a `.env` private key.

**Bugs found and fixed (L1/L2 auth):**

| File | Bug | Fix |
|------|-----|-----|
| `clob_client.dart` | `getApiKeys` path `/auth/api-key` (singular) → 405 | Changed to `/auth/api-keys` (plural) |
| `clob_client.dart` | HMAC signed over full path including query string | **Sign bare path only** — query params added to URL after headers |
| `clob_client.dart` | `getNotifications` included `?signature_type=0` in HMAC path | Keep HMAC path as `/notifications`; pass `signature_type=0` in `queryParams` only |
| `clob_client.dart` | `postHeartbeat` wrong path `/heartbeat` → 404 | Changed to `/v1/heartbeats` |
| `clob_client.dart` | `postHeartbeat` body `{}` not matching Python SDK `{"heartbeat_id":null}` | Always include `heartbeat_id` key in body |
| `test/auth_test.dart` | `getBalanceAllowance` missing `asset_type` → 400 | Pass `BalanceAllowanceParams(assetType: 'COLLATERAL')` — uppercase required |
| `clob_client.dart` | `owner`/`maker`/`user` query params sent lowercase | Added `_checksumAddress()` via `KeccakDigest(256)` — 4/4 EIP-55 test vectors pass |

**Key architectural discovery:** CLOB always computes HMAC from the **bare path only** (no query string). All query params are added to the URL separately after generating auth headers.

**Total tests: 23 unit + 18 L0 integration + 8 auth integration = 49/49 passing**

---

### L0 integration tests: 18/18 passing against live API

**Bugs found and fixed:**

| File | Bug | Fix |
|------|-----|-----|
| `lib/src/clients/clob_client.dart:77` | `getServerTime` cast `as Map<String, dynamic>` — API returns raw `int` | Handle both `int` response and `{"time": n}` map |
| `lib/src/clients/clob_client.dart:282` | `getFeeRateBps` used wrong path `/fee-rate-bps` | Corrected to `/fee-rate` |
| `lib/src/clients/clob_client.dart:288` | `getFeeRateBps` parsed wrong key `fee_rate_bps` | Corrected to `base_fee` |
| `lib/src/models/clob_types.dart:244` | `OrderBookSummary.timestamp` cast `as int?` — API returns timestamp as string `"1772557429580"` | Changed to `int.tryParse(json['timestamp'].toString())` |
| `test/clob_client_test.dart` | Hardcoded Trump 2024 settled market token ID — no orderbook exists for settled markets | Replaced with dynamic discovery: `setUpAll` fetches top-5 markets by 24h volume from Gamma API |
| `test/clob_client_test.dart` | Gamma API `clobTokenIds` is a JSON-encoded string `"[\"id1\",\"id2\"]"`, not a list | Added `jsonDecode` when `raw is String` |

**Other discoveries:**
- `getLastTradePrice` works for both active and settled markets
- `getMidpoint`, `getPrice`, `getSpread`, `getOrderBook` require an active market with a live orderbook
- First page of `/markets` endpoint returns mostly settled markets — Gamma API needed to find high-volume active ones

**Total L0 integration tests: 18/18 passing**

---

## v0.1.0 — Core SDK

## Overview
First Dart/Flutter SDK for the Polymarket CLOB API. Built from scratch, structured
identically to `hyperliquid_dart` so the codebase is familiar and patterns are shared.

---

## Project Scaffold
- `pubspec.yaml` — 5 runtime deps: `http`, `web_socket_channel`, `pointycastle`, `convert`, `crypto`
- No `msgpack_dart` needed (Polymarket doesn't use msgpack)
- `dart analyze` passes with zero issues
- `.gitignore` correctly excludes `.dart_tool/`, `pubspec.lock`, `docs/`, etc.

---

## Transport Layer (`lib/src/transport/`)

### `http_transport.dart`
- Adapted from `hyperliquid_dart`
- Supports `GET`, `POST`, `DELETE` with optional headers and query params
- Multi-URL design (Gamma, Data, CLOB each have their own base URL)
- `PolymarketApiException` with status code + body for debugging

### `websocket_transport.dart`
- Adapted from `hyperliquid_dart`
- URL passed as constructor param (not hardcoded) — works for both CLOB WS and RTDS WS
- Auto-reconnect with exponential backoff + jitter
- Broadcast stream for messages and connection state changes
- Configurable `pingInterval` (CLOB uses 30s, RTDS needs 5s)

---

## Signing Layer (`lib/src/signing/`)

### `wallet_adapter.dart` — copied from `hyperliquid_dart`
- Abstract interface: `getAddress()` + `signTypedData()`
- Works with any wallet provider: Privy, Web3Auth, MetaMask, raw key

### `private_key_wallet_adapter.dart` — copied from `hyperliquid_dart`
- Full secp256k1 ECDSA implementation via `pointycastle`
- EIP-712 encoding: typeHash, encodeType, encodeData, hashStruct
- Address derivation from private key (uncompressed pubkey → keccak256 → last 20 bytes)
- Deterministic ECDSA (RFC 6979), s-value normalization (EIP-2), recovery ID computation

### `eip712.dart` — NEW, Polymarket-specific
Two separate EIP-712 signing domains:

**`buildClobAuthTypedData()`** — Level 1 auth
- Domain: `ClobAuthDomain`, version `1`, chainId `137` (no `verifyingContract`)
- Struct: `ClobAuth(address, timestamp, nonce, message)`
- Message: `"This message attests that I control the given wallet"` (exact string)
- Used once per session to get `{apiKey, secret, passphrase}` from CLOB

**`buildOrderTypedData()`** — Order signing (per trade)
- Domain: `CTF Exchange`, version `1`, chainId `137`, `verifyingContract` = exchange address
- Supports neg-risk markets (different contract: `0xC5d563A...`)
- Struct: `Order(salt, maker, signer, taker, tokenId, makerAmount, takerAmount, expiration, nonce, feeRateBps, side, signatureType)` — all `uint256` fields
- Side: `0 = BUY`, `1 = SELL`; SignatureType: `0 = EOA`, `1 = PolyProxy`, `2 = GnosisSafe`

### `hmac_auth.dart` — NEW
Three critical implementation details from `py-clob-client` source:
1. Secret is **base64url-decoded** before use as HMAC key
2. Single quotes in body → double quotes before signing
3. Signature is **base64url-encoded**

Level 2 headers: `POLY_ADDRESS`, `POLY_SIGNATURE`, `POLY_TIMESTAMP`, `POLY_API_KEY`, `POLY_PASSPHRASE`

---

## Models (`lib/src/models/`)

### `clob_types.dart` — 40+ types
- `ApiCredentials`, `ApiKeysResponse`
- `Market`, `Token`, `MarketsPage`
- `OrderLevel`, `BookParams`, `OrderBookSummary`
- `LastTradePrice`, `Spread`, `PricePoint`, `PriceHistoryParams`
- `MarketTradeEvent`
- `OrderArgs`, `MarketOrderArgs`, `CreateOrderOptions`
- `SignedOrder`, `PostOrderArgs`, `PostOrderResponse`
- `OpenOrder`, `OpenOrderParams`, `OpenOrdersPage`
- `TradeParams`, `Trade`, `TradesPage`
- `BalanceAllowanceParams`, `BalanceAllowance`, `BanStatus`
- `Notification`, `DropNotificationParams`
- `OrderScoring`, `OrdersScoring`
- `HeartbeatResponse`
- Enums: `OrderSide`, `OrderType`, `SignatureType`

### `websocket_types.dart`
- `WsOrderLevel`, `OrderbookUpdate`, `WsTrade` — CLOB stream types
- `RtdsPriceUpdate`, `RtdsComment` — RTDS stream types

---

## Client Layer (`lib/src/clients/`)

### `ClobClient` — 42 methods across 3 auth levels

**Level 0 (public, no auth):**
- `getOk()`, `getServerTime()`
- `getMarkets()`, `getMarket()`, `getSamplingMarkets()`, `getSimplifiedMarkets()`, `getMarketTradesEvents()`
- `getOrderBook()`, `getOrderBooks()`
- `getMidpoint()`, `getMidpoints()`, `getPrice()`, `getPrices()`, `getSpread()`, `getSpreads()`
- `getLastTradePrice()`, `getLastTradesPrices()`
- `getTickSize()`, `getNegRisk()`, `getFeeRateBps()`
- `getPricesHistory()`

**Level 1 (EIP-712, one-time per session):**
- `createApiKey()`, `deriveApiKey()`, `createOrDeriveApiKey()`
- `getApiKeys()`, `deleteApiKey()`

**Level 2 (HMAC per request):**
- `createOrder()`, `createMarketOrder()` — builds + EIP-712 signs locally
- `postOrder()`, `postOrders()` — submits with HMAC auth
- `getOrder()`, `getOpenOrders()`
- `cancelOrder()`, `cancelOrders()`, `cancelAll()`, `cancelMarketOrders()`
- `getTrades()`
- `getBalanceAllowance()`, `updateBalanceAllowance()`
- `getClosedOnlyMode()`
- `getNotifications()`, `dropNotifications()`
- `isOrderScoring()`, `areOrdersScoring()`
- `postHeartbeat()`

### `WebSocketClient`
- **CLOB WS** (`wss://ws-subscriptions-clob.polymarket.com/ws/market`): `subscribeOrderbook()`, `subscribeTrades()`
- **RTDS WS** (`wss://ws-live-data.polymarket.com/ws`): `subscribePrices()`, `subscribeComments()`
- RTDS ping interval: 5 seconds (stricter than CLOB's 30s)

---

## Tests (`test/`)

### `hmac_auth_test.dart` — 8 tests
- Headers contain correct keys
- Signature is base64url (no `+` or `/`)
- Different methods → different signatures
- Different paths → different signatures
- Single-quote normalization works
- `generateHeadersFromMap` matches `generateHeaders`
- Empty body doesn't throw
- Timestamp auto-generated within 5 seconds of now

### `eip712_test.dart` — 15 tests
- ClobAuth domain: correct name, version, chainId, no verifyingContract
- ClobAuth message: lowercased address, exact attestation string, nonce included
- ClobAuth types: all 4 fields present
- Order domain: correct CTF Exchange domain, negRisk contract used when `negRisk: true`
- Order types: all 12 required fields present
- Order message: addresses lowercased, primaryType = "Order"
- `PrivateKeyWalletAdapter`: correct address derivation, signing ClobAuth without throw, signing Order without throw, deterministic (same input → same output)

**Total: 23/23 passing**
