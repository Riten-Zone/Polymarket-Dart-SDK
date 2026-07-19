/// API URLs and chain constants for Polymarket.
library;

class PolymarketUrls {
  static const String clob = 'https://clob.polymarket.com';
  static const String gamma = 'https://gamma-api.polymarket.com';
  static const String data = 'https://data-api.polymarket.com';
  static const String bridge = 'https://bridge.polymarket.com';

  /// Combos / RFQ REST API (combo markets, maker quotes, last-look).
  static const String combosRfq = 'https://combos-rfq-api.polymarket.com';

  /// Gasless relayer (v2) REST API — transaction submit/lookup, nonce, keys.
  static const String relayer = 'https://relayer-v2.polymarket.com';

  static const String clobWs =
      'wss://ws-subscriptions-clob.polymarket.com/ws/market';

  /// Authenticated CLOB user channel — per-user order and trade updates.
  static const String clobUserWs =
      'wss://ws-subscriptions-clob.polymarket.com/ws/user';

  static const String rtdsWs = 'wss://ws-live-data.polymarket.com/ws';

  /// Sports data WebSocket — unauthenticated live scores for all active games.
  static const String sportsWs = 'wss://sports-api.polymarket.com/ws';

  /// Quoter Gateway WebSocket — market makers stream RFQ requests and quotes.
  static const String quoterGatewayWs =
      'wss://combos-rfq-gateway-quoter.polymarket.com/ws/rfq';
}

class PolymarketChain {
  /// Polygon mainnet chain ID.
  static const int chainId = 137;

  /// CTF Exchange V2 contract on Polygon (regular markets).
  static const String exchangeAddress =
      '0xE111180000d2663C0091e4f400237545B87B996B';

  /// CTF Exchange V2 contract on Polygon (neg-risk markets).
  static const String negRiskExchangeAddress =
      '0xe2222d279d744050d28e00520010520000310F59';

  /// EIP-712 Exchange domain version for CLOB V2 orders.
  static const String exchangeDomainVersion = '2';

  /// Zero address — used as default taker for open orders.
  static const String zeroAddress =
      '0x0000000000000000000000000000000000000000';
}
