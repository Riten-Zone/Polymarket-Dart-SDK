import 'package:polymarket_dart/polymarket_dart.dart';

Future<void> main() async {
  // ── Public CLOB API ───────────────────────────────────────────────────────
  final clob = ClobClient();

  final markets = await clob.getMarkets(limit: 3);
  print('CLOB markets (first 3):');
  for (final m in markets.data) {
    print('  ${m.question}');
  }

  final time = await clob.getServerTime();
  print('Server time: $time\n');

  clob.close();

  // ── Gamma API — market discovery ─────────────────────────────────────────
  final gamma = GammaClient();

  final top = await gamma.getMarkets(
    active: true,
    order: 'volume24hr',
    ascending: false,
    limit: 3,
  );
  print('Top markets by 24h volume:');
  for (final m in top) {
    print('  ${m.question}  (volume: ${m.volume24hr})');
  }

  final tags = await gamma.getTags();
  print('\nCategories: ${tags.map((t) => t.label).join(', ')}\n');

  gamma.close();

  // ── Data API — user analytics ─────────────────────────────────────────────
  final data = DataClient();

  // Replace with a real address to see live data
  const address = '0x0000000000000000000000000000000000000000';
  final positions = await data.getPositions(address);
  print('Positions for $address: ${positions.length}');

  data.close();
}
