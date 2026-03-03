# Roadmap — `polymarket_dart`

---

## ✅ Done: Live Testing & Bug Fixes

All 18 integration tests pass against the live API. Fixes applied:
- `getServerTime` — API returns raw `int`, not JSON object
- `getFeeRateBps` — path was `/fee-rate-bps`, correct is `/fee-rate`; key was `fee_rate_bps`, correct is `base_fee`
- `OrderBookSummary.timestamp` — API returns timestamp as string, not int
- Integration tests now use dynamic market discovery (Gamma API, top 5 by 24h volume)

**Still to test (needs a private key, no money):**
```dart
final wallet = PrivateKeyWalletAdapter('0xYourKey');
final client = ClobClient(wallet: wallet);
final creds = await client.createOrDeriveApiKey();
client.setCredentials(creds);
final orders = await client.getOpenOrders(); // should return empty list, not throw
```

**Known L2 paths still unverified (low risk):**

| Item | Risk | Notes |
|------|------|-------|
| `/data/order/{id}` path | Medium | Might be `/order/{id}` without `/data/` prefix |
| `/data/orders` path | Medium | Might be `/orders` |
| `/data/trades` path | Medium | Might be `/trades` |
| CLOB WS subscription message format | High | `action`/`channel` field names need live verification |
| RTDS ping format | Medium | May expect plain `"PING"` string, not JSON `{"method":"ping"}` |

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

## v0.3 — Pub.dev Publishing Prep

Before publishing to `pub.dev`:

1. **`README.md`** — usage examples, feature table, installation
2. **`CHANGELOG.md`** — version history
3. **`LICENSE`** — MIT (match `hyperliquid_dart`)
4. **`example/`** — runnable example file
   ```dart
   // example/example.dart
   import 'package:polymarket_dart/polymarket_dart.dart';
   void main() async {
     final client = ClobClient();
     final markets = await client.getMarkets();
     print(markets.data.first.question);
   }
   ```
5. **`dartdoc` comments** — add `///` docs to all public methods (like `hyperliquid_dart`)
6. **`analysis_options.yaml`** — match linting rules from `hyperliquid_dart`
7. Run `dart pub publish --dry-run` to check score

---

## v0.3 — Builder Features

For market makers building on Polymarket:
```dart
Future<BuilderApiKey> createBuilderApiKey();
Future<List<BuilderApiKey>> getBuilderApiKeys();
Future<void> revokeBuilderApiKey();
Future<TradesPage> getBuilderTrades({TradeParams? params});
```

---

## Future — RFQ (Request for Quote)

Only available in the Rust SDK currently. Adds institutional-grade liquidity features:
```dart
Future<RfqRequest> createRfqRequest(CreateRfqRequestArgs args);
Future<void> cancelRfqRequest(String requestId);
Future<RfqPage> getRfqRequests({RfqRequestsParams? params});
Future<RfqQuote> createRfqQuote(CreateRfqQuoteArgs args);
Future<void> cancelRfqQuote(String quoteId);
Future<RfqQuotePage> getRfqQuotes({RfqQuotesParams? params});
Future<RfqAcceptResponse> acceptRfqQuote(String quoteId);
Future<void> approveRfqOrder(String orderId);
```

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
| post v0.1 | Live testing — 18 integration tests passing, 4 bugs fixed | ✅ Done |
| v0.2.0 | GammaClient, DataClient, Rewards, Readonly keys | Planned |
| v0.3.0 | Pub.dev publish, dartdoc, README, example | Planned |
| Future | RFQ, Builder features, Privy wallet adapter | Backlog |
