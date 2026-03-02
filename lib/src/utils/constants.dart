/// API URLs and chain constants for Polymarket.
library;

class PolymarketUrls {
  static const String clob = 'https://clob.polymarket.com';
  static const String gamma = 'https://gamma-api.polymarket.com';
  static const String data = 'https://data-api.polymarket.com';
  static const String clobWs =
      'wss://ws-subscriptions-clob.polymarket.com/ws/market';
  static const String rtdsWs = 'wss://ws-live-data.polymarket.com/ws';
}

class PolymarketChain {
  /// Polygon mainnet chain ID.
  static const int chainId = 137;

  /// CTF Exchange contract on Polygon (regular markets).
  static const String exchangeAddress =
      '0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E';

  /// CTF Exchange contract on Polygon (neg-risk markets).
  static const String negRiskExchangeAddress =
      '0xC5d563A36AE78145C45a50134d48A1215220f80a';

  /// Zero address — used as default taker for open orders.
  static const String zeroAddress =
      '0x0000000000000000000000000000000000000000';
}
