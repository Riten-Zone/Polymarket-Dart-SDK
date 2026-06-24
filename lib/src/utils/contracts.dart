/// Polygon contract addresses and RPC constants for Polymarket.
library;

class PolymarketContracts {
  /// USDC.e (bridged USDC) on Polygon mainnet.
  static const String usdc = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';

  /// Polymarket USD (pUSD) collateral token on Polygon mainnet.
  static const String pusd = '0xC011a7E12a19f7B1f670d46F03B03f3342E82DFB';

  /// pUSD collateral token implementation contract.
  static const String pusdImplementation =
      '0x6bBCef9f7ef3B6C592c99e0f206a0DE94Ad0925f';

  /// Wraps USDC.e into pUSD.
  static const String collateralOnramp =
      '0x93070a847efEf7F70739046A929D47a521F5B8ee';

  /// Unwraps pUSD back into USDC.e.
  static const String collateralOfframp =
      '0x2957922Eb93258b93368531d39fAcCA3B4dC5854';

  /// Permissioned collateral ramp.
  static const String permissionedRamp =
      '0xebC2459Ec962869ca4c0bd1E06368272732BCb08';

  /// Conditional Token Framework (CTF) contract.
  static const String ctf = '0x4D97DCd97eC945f40cF65F87097ACe5EA0476045';

  /// CTF Exchange V2 — standard (non-neg-risk) markets.
  static const String ctfExchange =
      '0xE111180000d2663C0091e4f400237545B87B996B';

  /// Neg-Risk CTF Exchange V2 — neg-risk markets.
  static const String negRiskExchange =
      '0xe2222d279d744050d28e00520010520000310F59';

  /// Legacy CTF Exchange V1 address retained for migration tooling.
  static const String legacyCtfExchange =
      '0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E';

  /// Legacy Neg-Risk CTF Exchange V1 address retained for migration tooling.
  static const String legacyNegRiskExchange =
      '0xC5d563A36AE78145C45a50134d48A1215220f80a';

  /// Neg-Risk Adapter.
  static const String negRiskAdapter =
      '0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296';

  /// CTF collateral adapter for pUSD-native split/merge/redeem flows.
  static const String ctfCollateralAdapter =
      '0xAdA100Db00Ca00073811820692005400218FcE1f';

  /// Neg-risk CTF collateral adapter for pUSD-native split/merge/redeem flows.
  static const String negRiskCtfCollateralAdapter =
      '0xadA2005600Dec949baf300f4C6120000bDB6eAab';

  /// Gnosis Safe Multisend contract (used for batching relayer transactions).
  static const String multisend = '0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761';

  /// Deposit Wallet Factory.
  static const String depositWalletFactory =
      '0x00000000000Fb5C9ADea0298D729A0CB3823Cc07';

  /// Deposit Wallet Beacon.
  static const String depositWalletBeacon =
      '0x7A18EDfe055488A3128f01F563e5B479D92ffc3a';

  /// Gnosis Safe proxy factory (used to derive expected Safe address).
  static const String safeFactory =
      '0xaacFeEa03eb1561514521C813Bf91927Cd87aD6D';

  /// Polymarket proxy factory.
  static const String polymarketProxyFactory =
      '0xaB45c5A4B0c941a2F231C04C3f49182e1A254052';

  /// Default Polygon mainnet RPC endpoint (public, no API key required).
  static const String polygonRpc = 'https://polygon.drpc.org';

  /// Polymarket relayer URL (gasless Safe transactions).
  static const String relayerUrl = 'https://relayer-v2.polymarket.com';
}
