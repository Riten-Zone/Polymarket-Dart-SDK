# Roadmap — `polymarket_dart`

---

## ✅ Done: v0.2.0 — GammaClient + DataClient + Rewards (2026-03-05)

Added `GammaClient` for market/event discovery, expanded `DataClient` with 4 new methods, added 10 new methods to `ClobClient` (rewards + read-only API keys).

**80 tests passing** (23 unit + 18 L0 + 8 auth + 14 approvals + 17 new)

Remaining work from v0.2.0:
- `getLeaderboard` — correct API path not yet found (404 on `/leaderboard`)
- Rewards endpoint paths speculative (404/405) — need verification against current API
- `getHolders` — works with `market` query param ✅

---

## ✅ Done: On-Chain Approvals + Order Placement (2026-03-05)

Both order paths now work end-to-end:
- **EOA**: `ensureEoaApprovals(wallet)` — direct Polygon JSON-RPC, 7 transactions, EOA pays MATIC gas
- **GnosisSafe**: `RelayerClient(wallet, creds).runApprovals(safeAddress)` — gasless via Polymarket relayer

Orders confirmed working:
- EOA `postOrder()` returns `orderId` directly after approvals set
- GnosisSafe `postOrder()` uses `signatureType: 2` (GnosisSafe)

Bug fixed: `SignedOrder.toJson()` serialized `side` as int (0/1) — API requires string ("BUY"/"SELL").

**63 tests passing** (23 unit + 18 L0 + 8 auth + 14 approvals)

---

## ✅ Done: Live Testing & Bug Fixes

All 18 integration tests pass against the live API. Fixes applied:
- `getServerTime` — API returns raw `int`, not JSON object
- `getFeeRateBps` — path was `/fee-rate-bps`, correct is `/fee-rate`; key was `fee_rate_bps`, correct is `base_fee`
- `OrderBookSummary.timestamp` — API returns timestamp as string, not int
- Integration tests now use dynamic market discovery (Gamma API, top 5 by 24h volume)

**✅ Done — auth tests 8/8 pass, all L2 paths verified against Python SDK**

All CLOB endpoint paths have been audited against `py_clob_client/endpoints.py`. Fixes applied:
- `getApiKeys`: `/auth/api-key` → `/auth/api-keys`
- `cancelAll`: `/orders` → `/cancel-all`
- `cancelMarketOrders`: `/orders` → `/cancel-market-orders`
- `getClosedOnlyMode`: `/closed-only-mode` → `/auth/ban-status/closed-only`
- `updateBalanceAllowance`: `/balance-allowance` → `/balance-allowance/update`
- HMAC signs bare path only (not including query string)
- EIP-55 checksummed addresses in query params (`owner`, `maker`, `user`)

**Remaining unverified (needs funds or real usage):**

| Item | Notes |
|------|-------|
| CLOB WS subscription message format | `action`/`channel` field names need live verification |
| RTDS ping format | May expect plain `"PING"` string |
| `postOrder` / `cancelOrder` end-to-end | ✅ Done — both EOA and GnosisSafe place orders successfully |

---

## v0.2 — GammaClient + DataClient

Two additional clients covering market discovery and user analytics.
Both are **zero-auth** — pure GET requests against separate base URLs.

### `GammaClient` (`https://gamma-api.polymarket.com`)
```dart
Future<List<GammaEvent>> getEvents({String? nextCursor});
Future<GammaEvent> getEvent(int eventId);
Future<List<GammaMarket>> getGammaMarkets({String? nextCursor, bool? active});
Future<GammaMarket> getGammaMarket(String slug);
Future<List<Tag>> getTags();
Future<List<GammaMarket>> searchMarkets(String query);
```

### `DataClient` (`https://data-api.polymarket.com`)
```dart
Future<List<Position>> getPositions(String userAddress);
Future<List<UserTrade>> getTrades(String userAddress);
Future<List<Activity>> getActivity(String userAddress);
Future<List<Holder>> getHolders(String conditionId);
Future<Leaderboard> getLeaderboard({String? interval});
```

New models: `GammaEvent`, `GammaMarket`, `Tag`, `Position`, `UserTrade`, `Activity`, `Holder`, `Leaderboard`

---

## v0.2 — Rewards & Earnings (CLOB)

6 methods missing from v0.1 that TypeScript and Rust SDKs have:
```dart
Future<List<UserEarning>> getEarningsForDay(String date);
Future<List<TotalUserEarning>> getTotalEarningsForDay(String date);
Future<List<UserRewardsEarning>> getUserEarningsAndMarketsConfig(String date);
Future<RewardsPercentages> getRewardPercentages();
Future<List<MarketReward>> getCurrentRewards();
Future<List<MarketReward>> getRawRewardsForMarket(String conditionId);
```

---

## v0.2 — Additional API Key Features

Currently skipped in v0.1:
- `createReadonlyApiKey()` — read-only keys for third-party integrations
- `getReadonlyApiKeys()` — list read-only keys
- `deleteReadonlyApiKey(key)` — revoke one
- `validateReadonlyApiKey(address, key)` — verify ownership

---

## ✅ Done: v0.3.0 — RFQ + Builder API + Bridge + Pub.dev Prep (2026-03-07)

- **RfqClient** — full Request-for-Quote system (requester + quoter side, all data queries)
- **BridgeClient** — cross-chain deposit API (EVM, Solana, Bitcoin → USDC.e on Polygon)
- **Builder API** extension to `ClobClient` — attributed orders/trades, builder leaderboard, `revokeBuilderApiKey`
- `ClobClient.createAndPostOrder()` — convenience one-call order wrapper
- `ClobClient.calculateMarketPrice()` — live orderbook price estimator
- `ClobClient.getSamplingSimplifiedMarkets()` + `getOrderBookHash()`
- Full `dartdoc` on all public classes, methods, and enums
- `dart pub publish --dry-run` passes with **0 warnings**
- **88+ tests passing**

---

## Next: Publish to pub.dev

The package is ready. Steps:
1. Run `dart pub publish` (requires pub.dev login)
2. Verify the pub.dev score after publishing

---

## Future — Privy Wallet Adapter

Since the main app uses Privy for auth, a `PrivyWalletAdapter` would let users
trade directly from their embedded Privy wallet without exposing a private key:

```dart
// In the Flutter app:
class PrivyWalletAdapter implements WalletAdapter {
  final PrivyEmbeddedWallet _privy;

  @override
  Future<String> getAddress() async => await _privy.address;

  @override
  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    return await _privy.signTypedData(typedData);
  }
}

// Usage:
final wallet = PrivyWalletAdapter(privyEmbeddedWallet);
final client = ClobClient(wallet: wallet);
```

This is the key integration between `polymarket_dart` and the Riten Flutter app.

---

## Version Summary

| Version | Focus | Status |
|---------|-------|--------|
| v0.1.0 | Core CLOB — 42 methods, full auth, WebSocket, 23 tests | ✅ Done |
| post v0.1 | Live testing — 49 tests passing, full path audit, all known bugs fixed | ✅ Done |
| post v0.1 | On-chain approvals (EOA + GnosisSafe), side bug fix, 63 tests passing | ✅ Done |
| v0.2.0 | GammaClient, DataClient, Rewards, Readonly keys | ✅ Done |
| v0.3.0 | RFQ, Builder API, Bridge, dartdoc, pub.dev prep | ✅ Done |
| Next | Publish to pub.dev | Ready |
| Future | Privy wallet adapter, fix leaderboard/rewards paths | Backlog |
