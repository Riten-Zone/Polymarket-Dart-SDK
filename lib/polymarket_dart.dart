/// Polymarket Dart SDK — REST API, WebSocket streams, EIP-712 signing, HMAC auth.
///
/// Quick start:
/// ```dart
/// import 'package:polymarket_dart/polymarket_dart.dart';
///
/// // Public data — no wallet needed
/// final client = ClobClient();
/// final markets = await client.getMarkets();
/// final book = await client.getOrderBook('21742633...');
///
/// // Authenticated — wallet required
/// final wallet = PrivateKeyWalletAdapter('0xYourPrivateKey');
/// final authedClient = ClobClient(wallet: wallet);
/// final creds = await authedClient.createOrDeriveApiKey();
/// authedClient.setCredentials(creds);
///
/// // Place an order
/// final order = await authedClient.createOrder(
///   OrderArgs(
///     tokenId: '21742633...',
///     price: 0.65,
///     size: 10,
///     side: OrderSide.buy,
///   ),
/// );
/// await authedClient.postOrder(order);
///
/// // Real-time WebSocket
/// final ws = WebSocketClient();
/// await ws.connectClob();
/// ws.subscribeOrderbook('21742633...').listen((update) {
///   print('Best bid: ${update.bids.first.price}');
/// });
/// ```
library;

// Clients
export 'src/clients/clob_client.dart';
export 'src/clients/data_client.dart';
export 'src/clients/websocket_client.dart';

// Models
export 'src/models/clob_types.dart';
export 'src/models/data_types.dart';
export 'src/models/websocket_types.dart';

// Signing
export 'src/signing/wallet_adapter.dart';
export 'src/signing/private_key_wallet_adapter.dart';
export 'src/signing/eip712.dart';
export 'src/signing/hmac_auth.dart';

// Transport
export 'src/transport/http_transport.dart';
export 'src/transport/websocket_transport.dart';

// Utils
export 'src/utils/constants.dart';
