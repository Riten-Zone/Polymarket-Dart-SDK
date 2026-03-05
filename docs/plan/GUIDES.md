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
