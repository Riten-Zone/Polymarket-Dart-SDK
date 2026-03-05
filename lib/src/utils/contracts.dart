/// Polygon contract addresses and RPC constants for Polymarket.
library;

class PolymarketContracts {
  /// USDC.e (bridged USDC) on Polygon mainnet.
  static const String usdc = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';

  /// Conditional Token Framework (CTF) contract.
  static const String ctf = '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045';

  /// CTF Exchange — standard (non-neg-risk) markets.
  static const String ctfExchange = '0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E';

  /// Neg-Risk CTF Exchange — neg-risk markets.
  static const String negRiskExchange = '0xC5d563A36AE78145C45a50134d48A1215220f80a';

  /// Neg-Risk Adapter.
  static const String negRiskAdapter = '0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296';

  /// Gnosis Safe Multisend contract (used for batching relayer transactions).
  static const String multisend = '0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761';

  /// Gnosis Safe proxy factory (used to derive expected Safe address).
  static const String safeFactory = '0xaacFeEa03eb1561514521C813Bf91927Cd87aD6D';

  /// Default Polygon mainnet RPC endpoint (public, no API key required).
  static const String polygonRpc = 'https://polygon.drpc.org';

  /// Polymarket relayer URL (gasless Safe transactions).
  static const String relayerUrl = 'https://relayer-v2.polymarket.com';
}
