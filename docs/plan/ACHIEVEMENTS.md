# Achievements — `polymarket_dart` v0.1.0

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
