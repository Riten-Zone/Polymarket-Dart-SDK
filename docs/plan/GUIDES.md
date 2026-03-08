# Guides — `polymarket_dart`

Practical examples for common tasks. All examples assume `polymarket_dart` is imported:

```dart
import 'package:polymarket_dart/polymarket_dart.dart';
```

---

## 1. Public Market Data (no auth)

```dart
final client = ClobClient();

// Fetch active markets
final markets = await client.getMarkets();
print(markets.data.first.question);

// Get orderbook for a specific token
final book = await client.getOrderBook('0xabc...');
print('Best bid: ${book.bids.first.price}');

// Get mid price
final mid = await client.getMidpoint('0xabc...');
print('Mid: ${mid.mid}');

// Get last trade price
final ltp = await client.getLastTradePrice('0xabc...');
print('Last trade: ${ltp.price}');

client.close();
```

---

## 2. Wallet Setup

```dart
// From a raw private key
final wallet = PrivateKeyWalletAdapter('0x<your_private_key>');
final address = await wallet.getAddress();
print('EOA address: $address');
```

---

## 3. API Key Management (Level 1 — EIP-712)

Run once per session to get HMAC credentials:

```dart
final wallet = PrivateKeyWalletAdapter('0x...');
final client = ClobClient(wallet: wallet);

// Create or reuse an existing API key
final creds = await client.createOrDeriveApiKey();
print('API key: ${creds.apiKey}');
print('Secret:  ${creds.secret}');
```

---

## 4. Authenticated Requests (Level 2 — HMAC)

```dart
final client = ClobClient(
  wallet: wallet,
  credentials: ApiCredentials(
    apiKey: '...',
    secret: '...',
    passphrase: '...',
  ),
);

// Check balance/allowance
final balance = await client.getBalanceAllowance(
  BalanceAllowanceParams(assetType: 'COLLATERAL'),
);
print('Allowance: ${balance.allowance}');

// Get open orders
final orders = await client.getOpenOrders();
print('Open orders: ${orders.data.length}');
```

---

## 5. EOA On-Chain Approvals (one-time setup)

Required before placing any orders with an EOA wallet. Sends 7 Polygon transactions (costs MATIC gas).

```dart
final wallet = PrivateKeyWalletAdapter('0x...');

await ensureEoaApprovals(
  wallet,
  onStatus: print, // optional progress callback
);
// Output:
// Checking approvals for 0xD53D...
// [1/7] setApprovalForAll CTF → CTF_EXCHANGE ... tx: 0xabc... confirmed
// ...
// ✅ All EOA approvals set!
```

Idempotent — safe to call again if already approved, will skip existing approvals.

---

## 6. GnosisSafe Gasless Approvals (one-time setup)

For GnosisSafe wallets — no MATIC needed. Requires Builder Program API credentials from [polymarket.com/settings?tab=builder](https://polymarket.com/settings?tab=builder).

```dart
final wallet = PrivateKeyWalletAdapter('0x<eoa_key>');
final safeAddress = '0x<gnosis_safe_address>';

final relayer = RelayerClient(
  wallet: wallet,
  creds: BuilderCredentials(
    apiKey: 'your_builder_api_key',
    secret: 'your_builder_secret',
    passphrase: 'your_passphrase',
  ),
);

await relayer.runApprovals(
  safeAddress,
  onStatus: print, // optional progress callback
);
relayer.close();
// Output:
// Safe nonce: 5
// Submitting relayer transaction...
// Transaction ID: abc123 — polling...
// ✅ All Safe approvals complete!
```

---

## 7. Placing Orders (EOA)

After approvals are set:

```dart
final wallet = PrivateKeyWalletAdapter('0x...');
final client = ClobClient(
  wallet: wallet,
  credentials: ApiCredentials(apiKey: '...', secret: '...', passphrase: '...'),
);

// Build and sign a limit order
final order = await client.createOrder(
  OrderArgs(
    tokenId: '0x<outcome_token_id>',
    price: 0.65,       // 65 cents per share
    size: 10.0,        // 10 USDC worth
    side: OrderSide.buy,
  ),
);

// Submit
final response = await client.postOrder(order);
print('Order ID: ${response.orderId}');

client.close();
```

---

## 8. Placing Orders (GnosisSafe)

```dart
final wallet = PrivateKeyWalletAdapter('0x...');
final safeAddress = '0x<gnosis_safe>';

final client = ClobClient(
  wallet: wallet,
  credentials: ApiCredentials(apiKey: '...', secret: '...', passphrase: '...'),
);

// GnosisSafe uses signatureType: 2
final order = await client.createOrder(
  OrderArgs(
    tokenId: '0x<outcome_token_id>',
    price: 0.65,
    size: 10.0,
    side: OrderSide.buy,
    funderAddress: safeAddress, // funds come from the Safe
    signatureType: SignatureType.gnosisSafe,
  ),
);

final response = await client.postOrder(order);
print('Order ID: ${response.orderId}');
```

---

## 9. Cancel Orders

```dart
// Cancel a single order
await client.cancelOrder(orderId: 'abc123');

// Cancel multiple
await client.cancelOrders(['id1', 'id2']);

// Cancel all open orders
await client.cancelAll();

// Cancel all orders for a specific market
await client.cancelMarketOrders(
  assetId: '0x<outcome_token_id>',
);
```

---

## 10. WebSocket — Live Orderbook

```dart
final ws = WebSocketClient();

final subscription = ws.subscribeOrderbook('0x<token_id>');
subscription.listen((update) {
  print('Bids: ${update.bids.first.price} × ${update.bids.first.size}');
  print('Asks: ${update.asks.first.price} × ${update.asks.first.size}');
});

// Disconnect when done
ws.close();
```

---

## 11. WebSocket — Live Trades

```dart
final ws = WebSocketClient();

final subscription = ws.subscribeTrades('0x<token_id>');
subscription.listen((trade) {
  print('${trade.side} ${trade.size} @ ${trade.price}');
});
```

---

## 12. Reading On-Chain State Directly

```dart
final rpc = PolygonRpc();

// Check USDC allowance for CTF Exchange
final data = AbiEncoder.encodeAllowance(
  '0x<your_address>',
  PolymarketContracts.ctfExchange,
);
final hex = await rpc.ethCall(
  to: PolymarketContracts.usdc,
  data: '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
);
final allowance = BigInt.parse(hex.substring(2), radix: 16);
print('USDC allowance: $allowance');

// Check CTF approval status
final isApprovedData = AbiEncoder.encodeIsApprovedForAll(
  '0x<your_address>',
  PolymarketContracts.ctfExchange,
);
final result = await rpc.ethCall(
  to: PolymarketContracts.ctf,
  data: '0x${isApprovedData.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
);
final isApproved = BigInt.parse(result.substring(2), radix: 16) == BigInt.one;
print('CTF approved: $isApproved');

rpc.close();
```

---

## Environment Setup (`.env`)

```
# EOA private key (hex, with or without 0x prefix)
PRIVATE_KEY=0x...

# GnosisSafe address (for relayer path)
FUNDER_ADDRESS=0x...

# Builder Program credentials (for GnosisSafe approvals)
# Get from: https://polymarket.com/settings?tab=builder
BUILDER_API_KEY=...
BUILDER_API_SECRET=...
BUILDER_API_PASSPHRASE=...
```

---

## 13. Neg-Risk Markets

Neg-risk markets (multi-outcome markets) use a different exchange contract. Detection and order placement is automatic:

```dart
final wallet = PrivateKeyWalletAdapter('0x...');
final client = ClobClient(
  wallet: wallet,
  credentials: ApiCredentials(apiKey: '...', secret: '...', passphrase: '...'),
);

// Check if a market is neg-risk
final tokenId = '0x<outcome_token_id>';
final isNegRisk = await client.getNegRisk(tokenId);
print('Neg-risk: $isNegRisk');

// Place an order — pass negRisk: true to use the correct exchange contract.
// When negRisk: true, EIP-712 signing uses 0xC5d563A... instead of 0x4bFb41d...
final order = await client.createOrder(
  OrderArgs(
    tokenId: tokenId,
    price: 0.40,
    size: 20.0,
    side: OrderSide.buy,
  ),
  options: CreateOrderOptions(negRisk: true),
);

final response = await client.postOrder(order);
print('Order ID: ${response.orderId}');
```

On-chain approvals (`ensureEoaApprovals`) already include the neg-risk adapter and exchange — no extra setup needed.

---

## Contract Address Reference

```dart
// Access via PolymarketContracts constants
PolymarketContracts.usdc            // USDC (USDC.e on Polygon)
PolymarketContracts.ctf             // Conditional Token Framework
PolymarketContracts.ctfExchange     // CTF Exchange
PolymarketContracts.negRiskExchange // Neg Risk Exchange
PolymarketContracts.negRiskAdapter  // Neg Risk Adapter
PolymarketContracts.multisend       // Gnosis Safe Multisend
PolymarketContracts.relayerUrl      // Polymarket relayer endpoint
PolymarketContracts.polygonRpc      // Default Polygon RPC URL
```

---

## 14. GammaClient — Market Discovery

`GammaClient` hits `https://gamma-api.polymarket.com`. No auth required.

```dart
final gamma = GammaClient();

// Top active markets by 24h volume
final markets = await gamma.getMarkets(
  active: true,
  closed: false,
  order: 'volume24hr',
  ascending: false,
  limit: 20,
);
for (final m in markets) {
  print('${m.question}  vol24h=${m.volume24hr}');
}

// Single market by numeric ID
final market = await gamma.getMarket(markets.first.id);
print('Tokens: ${market.clobTokenIds}');

// Browse events (topic groups containing multiple markets)
final events = await gamma.getEvents(active: true, limit: 5);
for (final e in events) {
  print('${e.title} — ${e.markets.length} markets');
}

// All category tags
final tags = await gamma.getTags();
print(tags.map((t) => t.label).join(', '));

// Free-text search
final results = await gamma.searchMarkets('trump tariff');
print('Found ${results.length} markets');

gamma.close();
```

---

## 15. DataClient — User Analytics

`DataClient` hits `https://data-api.polymarket.com`. No auth required.

```dart
final data = DataClient();

final eoaAddress = '0xYourEOAAddress';

// All active positions (accepts EOA or proxy wallet)
final positions = await data.getPositions(eoaAddress);
for (final p in positions) {
  print('${p.title}: ${p.size} shares @ conditionId=${p.conditionId}');
}

// Lookup the Polymarket Safe proxy wallet for an EOA
final proxy = await data.getProxyWallet(eoaAddress);
print('Proxy wallet: $proxy'); // 0xProxyAddress or null

// Completed trades
final trades = await data.getTrades(eoaAddress, limit: 20);
for (final t in trades) {
  print('${t.side} ${t.size} @ ${t.price}  tx=${t.transactionHash}');
}

// Activity events (trades, redemptions, etc.)
final activity = await data.getActivity(eoaAddress, limit: 10);
for (final a in activity) {
  print('${a.type}  size=${a.size}  ts=${a.timestamp}');
}

// Outcome token holders for a market
final conditionId = '0x...'; // CTF condition ID
final holders = await data.getHolders(conditionId, limit: 50);
for (final h in holders) {
  print('${h.pseudonym ?? h.address}: ${h.amount}');
}

data.close();
```

---

## 16. Quick Order (createAndPostOrder)

Convenience wrapper — builds, signs, and posts an order in one call:

```dart
final client = ClobClient(
  wallet: PrivateKeyWalletAdapter('0x...'),
  credentials: ApiCredentials(apiKey: '...', secret: '...', passphrase: '...'),
);

// GTC limit order — buy 50 USDC worth of YES shares at 65¢
final response = await client.createAndPostOrder(
  OrderArgs(
    tokenId: '0x<outcome_token_id>',
    price: 0.65,
    size: 50.0,
    side: OrderSide.buy,
  ),
  orderType: 'GTC',
);
print('Order ID: ${response.orderId}');

// Post-only (maker only, rejected if it would fill immediately)
final makerOnly = await client.createAndPostOrder(
  OrderArgs(
    tokenId: '0x<outcome_token_id>',
    price: 0.60,
    size: 20.0,
    side: OrderSide.buy,
  ),
  postOnly: true,
);

client.close();
```

---

## 17. Market Price Estimation (calculateMarketPrice)

Walks the live orderbook to estimate fill price before placing an order:

```dart
final client = ClobClient();

final tokenId = '0x<outcome_token_id>';

// Estimate cost to BUY 100 USDC worth of shares
final buyPrice = await client.calculateMarketPrice(
  tokenId,
  'BUY',
  100.0,
  OrderType.gtc,
);
print('Estimated buy price: $buyPrice'); // e.g. 0.67

// Estimate proceeds from SELL 200 shares
final sellPrice = await client.calculateMarketPrice(
  tokenId,
  'SELL',
  200.0,
  OrderType.gtc,
);
print('Estimated sell price: $sellPrice');

// FOK — throws if the book cannot fill the full amount
try {
  final fokPrice = await client.calculateMarketPrice(
    tokenId,
    'BUY',
    10000.0,
    OrderType.fok,
  );
  print('FOK price: $fokPrice');
} on StateError catch (e) {
  print('Cannot fill: $e');
}

client.close();
```

---

## 18. RTDS WebSocket — Crypto Prices

Real-time crypto price feed from `wss://ws-live-data.polymarket.com/ws`:

```dart
final ws = WebSocketClient();

// Subscribe to BTC, ETH, and SOL prices
final stream = ws.subscribePrices(['BTC', 'ETH', 'SOL']);
stream.listen((update) {
  print('${update.asset}: \$${update.price}  ts=${update.timestamp}');
});

// Run for 30 seconds then close
await Future.delayed(const Duration(seconds: 30));
ws.close();
```

---

## 19. RTDS WebSocket — Market Comments

Live comment feed for a specific market:

```dart
final ws = WebSocketClient();

final marketId = '0x<condition_id_or_market_id>';

final stream = ws.subscribeComments(marketId);
stream.listen((comment) {
  print('[${comment.author}] ${comment.content}');
});

await Future.delayed(const Duration(seconds: 60));
ws.close();
```

---

## 20. BridgeClient — Cross-Chain Deposits

Deposit ETH, USDC, SOL, BTC etc. and receive USDC.e on Polygon:

```dart
final bridge = BridgeClient();

// Your Polymarket proxy wallet address (from DataClient.getProxyWallet)
final polymarketAddress = '0xYourProxyWallet';

// Generate deposit addresses
final deposit = await bridge.createDeposit(polymarketAddress);
print('Send EVM tokens to:     ${deposit.address.evm}');
print('Send Solana tokens to:  ${deposit.address.svm}');
print('Send Bitcoin to:        ${deposit.address.btc}');

// List supported chains and tokens
final assets = await bridge.getSupportedAssets();
for (final a in assets) {
  print('${a.chainName}  ${a.token.symbol}  min=\$${a.minCheckoutUsd}');
}

// Track deposit status (poll until completed)
final status = await bridge.getStatus(deposit.address.evm);
for (final tx in status.transactions) {
  print('${tx.state}  amount=${tx.amount}  hash=${tx.hash}');
}

bridge.close();
```

---

## 21. RfqClient — Request for Quote

RFQ is a private liquidity system where requesters post desired trades and
market makers respond with competing quotes.

All methods require Level 2 HMAC auth.

```dart
final wallet = PrivateKeyWalletAdapter('0x...');
final clob = ClobClient(wallet: wallet);
final creds = await clob.createOrDeriveApiKey();
clob.close();

final rfq = RfqClient(wallet: wallet, credentials: creds);

// ── Requester side ──────────────────────────────────────────────────────────

// Post a buy request (you want to buy 50 YES shares at max 65¢)
final req = await rfq.createRequest(RfqUserRequest(
  tokenId: '0x<outcome_token_id>',
  side: 'BUY',
  price: 0.65,
  size: 50.0,
));
print('Request ID: ${req.requestId}');

// View quotes received on your request
final quotes = await rfq.getRequesterQuotes();
for (final q in quotes.data) {
  print('Quote ${q.quoteId}: ${q.price} × ${q.size}');
}

// Accept the best quote
if (quotes.data.isNotEmpty) {
  await rfq.acceptQuote(AcceptQuoteParams(quoteId: quotes.data.first.quoteId));
}

// Cancel a request
await rfq.cancelRequest(CancelRfqRequestParams(requestId: req.requestId));

// ── Quoter (market-maker) side ──────────────────────────────────────────────

// Browse open requests from all requesters
final requests = await rfq.getRequests(GetRfqRequestsParams(limit: 10));
for (final r in requests.data) {
  print('${r.side} ${r.size} @ ${r.price}  token=${r.tokenId}');
}

// Respond to a request with a quote
final quote = await rfq.createQuote(RfqUserQuote(
  requestId: requests.data.first.requestId,
  price: 0.63,
  size: 50.0,
));
print('Quote ID: ${quote.quoteId}');

// Get global RFQ config (min sizes, fee rates, etc.)
final config = await rfq.getConfig();
print('RFQ config: $config');

rfq.close();
```

---

## 22. Builder API

Builder credentials let you attribute orders and trades to your builder account
and access the builder-specific endpoints.

```dart
final wallet = PrivateKeyWalletAdapter('0x...');
final creds = ApiCredentials(apiKey: '...', secret: '...', passphrase: '...');
final builderCreds = BuilderCredentials(
  apiKey: 'your_builder_api_key',
  secret: 'your_builder_secret',
  passphrase: 'your_builder_passphrase',
);

// Pass builderCredentials to the constructor
final client = ClobClient(
  wallet: wallet,
  credentials: creds,
  builderCredentials: builderCreds,
);

// All orders attributed to your builder account
final orders = await client.getBuilderOrders();
print('Builder orders: ${orders.length}');

// Open orders only, optionally filtered by market (conditionId)
final openOrders = await client.getBuilderOpenOrders();
print('Open: ${openOrders.data.length}');

// Trades routed through your builder account
final trades = await client.getBuilderTrades(limit: 50);
print('Trades: ${trades.data.length}');

// Public builder leaderboard (no builder creds needed)
final leaderboard = await client.getBuilderLeaderboard(limit: 10);
for (final entry in leaderboard) {
  print('${entry.builderAddress}  vol=\$${entry.volumeUsd}');
}

// Revoke builder API key
await client.revokeBuilderApiKey();

client.close();
```

---

## 23. Rewards (LP Earnings)

All reward methods require Level 2 HMAC auth. Returns raw JSON maps —
the Polymarket API returns variable structures depending on wallet activity.

```dart
final client = ClobClient(
  wallet: PrivateKeyWalletAdapter('0x...'),
  credentials: ApiCredentials(apiKey: '...', secret: '...', passphrase: '...'),
);

// Currently active reward markets (which markets earn LP rewards)
final current = await client.getCurrentRewards();
print('Active reward markets: ${(current['data'] as List?)?.length}');

// Your LP earnings for a specific date (YYYY-MM-DD)
final earnings = await client.getEarningsForDay('2026-03-01');
print('Earnings: $earnings');

// Total cumulative earnings for a date
final total = await client.getTotalEarningsForDay('2026-03-01');
print('Total: $total');

// Per-market earnings and reward config for a date
final markets = await client.getUserEarningsAndMarketsConfig('2026-03-01');
print('Markets config: $markets');

// Your reward percentage allocation
final pct = await client.getRewardPercentages();
print('Percentages: $pct');

// Raw reward data for a specific market
final conditionId = '0x<condition_id>';
final raw = await client.getRawRewardsForMarket(conditionId);
print('Market rewards: $raw');

client.close();
```

---

## 24. Read-Only API Keys

Read-only keys let third parties query your account data without being able
to place or cancel orders.

```dart
final client = ClobClient(
  wallet: PrivateKeyWalletAdapter('0x...'),
  credentials: ApiCredentials(apiKey: '...', secret: '...', passphrase: '...'),
);

// Create a new read-only key
final roKey = await client.createReadonlyApiKey();
print('Read-only key: ${roKey.apiKey}');
print('Secret:        ${roKey.secret}');

// List all read-only keys on this wallet
final keys = await client.getReadonlyApiKeys();
print('${keys.length} read-only keys');

// Validate a read-only key (useful to verify before sharing)
final ownerAddress = await client.getAddress();
final valid = await client.validateReadonlyApiKey(ownerAddress, roKey.apiKey);
print('Valid: $valid'); // true

// Revoke a read-only key
await client.deleteReadonlyApiKey(roKey.apiKey);
print('Key revoked');

client.close();
```
