# polymarket_dart

A Dart SDK for the [Polymarket](https://polymarket.com) CLOB API — REST, WebSocket, EIP-712 signing, HMAC auth, on-chain approvals, and order management.

## Features

- **53 CLOB API methods** — markets, CLOB market info, orderbook, pricing, order management, rewards, auth
- **GammaClient** — 6 methods for market/event discovery, tags, and search (no auth required)
- **DataClient** — 5 methods for user positions, trades, activity, and holders
- **EIP-712 signing** — order signing for both EOA and GnosisSafe wallets
- **HMAC Level 2 auth** — API key management and authenticated requests
- **On-chain approvals** — EOA (direct Polygon RPC) and GnosisSafe (gasless relayer)
- **WebSocket** — live orderbook, trades, RTDS price feeds
- **Pure Dart** — no Flutter dependency, works in any Dart environment

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  polymarket_dart: ^0.3.1
```

Then run:

```bash
dart pub get
```

## Quick Start

```dart
import 'package:polymarket_dart/polymarket_dart.dart';

void main() async {
  // CLOB public API — no auth needed
  final client = ClobClient();
  final markets = await client.getMarkets();
  print(markets.data.first.question);
  client.close();

  // Market discovery via Gamma API — no auth needed
  final gamma = GammaClient();
  final topMarkets = await gamma.getMarkets(
    active: true,
    order: 'volume24hr',
    ascending: false,
    limit: 5,
  );
  print(topMarkets.first.question);
  gamma.close();
}
```

## Usage

See [docs/plan/GUIDES.md](docs/plan/GUIDES.md) for detailed examples covering public market data, GammaClient discovery, DataClient analytics, EIP-712 API key creation, placing orders (EOA and GnosisSafe), on-chain approvals, and WebSocket subscriptions.

## Prerequisites

### EOA Trading

1. A Polygon wallet private key with MATIC for gas
2. pUSD on Polygon for trading collateral

Run on-chain approvals once before trading:

```dart
final wallet = PrivateKeyWalletAdapter('0x...');
await ensureEoaApprovals(wallet, onStatus: print);
```

### GnosisSafe Trading

1. A GnosisSafe address funded with pUSD
2. Builder Program API credentials from [polymarket.com/settings?tab=builder](https://polymarket.com/settings?tab=builder)

Run gasless approvals once:

```dart
final relayer = RelayerClient(
  wallet: wallet,
  creds: BuilderCredentials(
    apiKey: '...',
    secret: '...',
    passphrase: '...',
  ),
);
await relayer.runApprovals(safeAddress);
```

## Contract Addresses (Polygon)

| Contract | Address |
|----------|---------|
| USDC (USDC.e) | `0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174` |
| pUSD | `0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB` |
| Collateral Onramp | `0x93070a847efEf7F70739046A929D47a521F5B8ee` |
| Collateral Offramp | `0x2957922Eb93258b93368531d39fAcCA3B4dC5854` |
| CTF | `0x4D97DCd97eC945f40cF65F87097ACe5EA0476045` |
| CTF Exchange V2 | `0xE111180000d2663C0091e4f400237545B87B996B` |
| Neg Risk Exchange V2 | `0xe2222d279d744050d28e00520010520000310F59` |
| Neg Risk Adapter | `0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296` |

## Testing

```bash
# Unit tests (no network)
dart test test/hmac_auth_test.dart test/eip712_test.dart

# CLOB public API
dart test test/clob_client_test.dart --tags integration

# Gamma API (market discovery)
dart test test/gamma_client_test.dart --tags gamma

# Data API (user analytics)
dart test test/data_client_test.dart --tags data

# L2 auth (requires PRIVATE_KEY in .env)
dart test test/auth_test.dart --tags auth

# Approvals (requires PRIVATE_KEY in .env)
dart test test/approvals_test.dart --tags approvals

# pUSD live wrap/unwrap (requires PRIVATE_KEY, POL gas, and USDC.e)
dart test test/pusd_live_test.dart --tags pusd-live

# GnosisSafe relayer (requires BUILDER_* creds in .env)
dart test test/relayer_test.dart --tags relayer

# Full suite (91 tests)
dart test --tags integration
```

Create a `.env` file in the project root:

```
PRIVATE_KEY=0x...
PUSD_LIVE_TEST_AMOUNT=10000  # optional; base units, 10000 = 0.01 USDC.e/pUSD
FUNDER_ADDRESS=0x...          # GnosisSafe address
BUILDER_API_KEY=...
BUILDER_API_SECRET=...
BUILDER_API_PASSPHRASE=...
```

## Dependencies

- [`http`](https://pub.dev/packages/http) — HTTP client
- [`web_socket_channel`](https://pub.dev/packages/web_socket_channel) — WebSocket
- [`pointycastle`](https://pub.dev/packages/pointycastle) — secp256k1 ECDSA, Keccak-256
- [`crypto`](https://pub.dev/packages/crypto) — HMAC-SHA256
- [`convert`](https://pub.dev/packages/convert) — hex encoding

## License

MIT
