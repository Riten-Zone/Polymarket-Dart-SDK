/// Live pUSD wrap/unwrap transaction tests.
///
/// Requires `.env`:
///   PRIVATE_KEY=...
///
/// Optional:
///   PUSD_LIVE_TEST_AMOUNT=10000
///
/// `PUSD_LIVE_TEST_AMOUNT` is in token base units. pUSD and USDC.e have 6
/// decimals, so the default `10000` is 0.01 USDC.e / pUSD.
///
/// Run with:
///   dart test test/pusd_live_test.dart --tags pusd-live
@Tags(['integration', 'pusd-live'])
library;

import 'dart:io';

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

String? _loadEnv(String key) {
  try {
    final env = File('.env').readAsStringSync();
    for (final line in env.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('$key=')) {
        final value = trimmed.substring('$key='.length).trim();
        return value.isEmpty ? null : value;
      }
    }
  } catch (_) {}
  return null;
}

void main() {
  late PrivateKeyWalletAdapter wallet;
  late String address;
  late CollateralClient collateral;
  late BigInt amount;
  bool skip = false;

  setUpAll(() async {
    final privateKey = _loadEnv('PRIVATE_KEY');
    if (privateKey == null) {
      print('Skipping: PRIVATE_KEY not found in .env');
      skip = true;
      return;
    }

    final rawAmount = _loadEnv('PUSD_LIVE_TEST_AMOUNT') ?? '10000';
    amount = BigInt.parse(rawAmount);
    wallet = PrivateKeyWalletAdapter(
      privateKey.startsWith('0x') ? privateKey : '0x$privateKey',
    );
    address = await wallet.getAddress();
    collateral = CollateralClient(wallet: wallet);
    print('Wallet: $address');
    print('Live wrap/unwrap amount: $amount base units');
  });

  tearDownAll(() {
    if (!skip) {
      collateral.close();
    }
  });

  test(
    'wraps USDC.e to pUSD and unwraps pUSD back to USDC.e',
    () async {
      if (skip) {
        return;
      }

      final polBalance = await collateral.nativeBalance(address);
      print('POL balance wei: $polBalance');
      expect(
        polBalance,
        greaterThan(BigInt.zero),
        reason: 'Wallet needs POL for gas.',
      );

      final usdcBefore = await collateral.balanceOf(
        token: PolymarketContracts.usdc,
        owner: address,
      );
      final pusdBefore = await collateral.balanceOf(
        token: PolymarketContracts.pusd,
        owner: address,
      );
      print('USDC.e before: $usdcBefore');
      print('pUSD before:   $pusdBefore');

      if (usdcBefore < amount) {
        print('Skipping: insufficient USDC.e balance for live wrap test.');
        return;
      }

      final wrap = await collateral.wrapUsdcToPusd(amount, onStatus: print);
      print('Wrap approval tx: ${wrap.approvalTxHash}');
      print('Wrap tx:          ${wrap.actionTxHash}');

      final usdcAfterWrap = await collateral.balanceOf(
        token: PolymarketContracts.usdc,
        owner: address,
      );
      final pusdAfterWrap = await collateral.balanceOf(
        token: PolymarketContracts.pusd,
        owner: address,
      );
      print('USDC.e after wrap: $usdcAfterWrap');
      print('pUSD after wrap:   $pusdAfterWrap');

      expect(usdcAfterWrap, equals(usdcBefore - amount));
      expect(pusdAfterWrap, equals(pusdBefore + amount));

      final unwrap = await collateral.unwrapPusdToUsdc(amount, onStatus: print);
      print('Unwrap approval tx: ${unwrap.approvalTxHash}');
      print('Unwrap tx:          ${unwrap.actionTxHash}');

      final usdcAfterUnwrap = await collateral.balanceOf(
        token: PolymarketContracts.usdc,
        owner: address,
      );
      final pusdAfterUnwrap = await collateral.balanceOf(
        token: PolymarketContracts.pusd,
        owner: address,
      );
      print('USDC.e after unwrap: $usdcAfterUnwrap');
      print('pUSD after unwrap:   $pusdAfterUnwrap');

      expect(usdcAfterUnwrap, equals(usdcBefore));
      expect(pusdAfterUnwrap, equals(pusdBefore));
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
