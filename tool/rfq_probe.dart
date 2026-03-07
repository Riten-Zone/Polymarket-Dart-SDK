import 'dart:io';
import 'package:polymarket_dart/polymarket_dart.dart';

Future<void> main() async {
  final lines = File('.env').readAsLinesSync();
  String? privateKey;
  for (final line in lines) {
    if (line.startsWith('PRIVATE_KEY=')) privateKey = line.substring(12);
  }

  final wallet = PrivateKeyWalletAdapter(privateKey!);
  final clob = ClobClient(wallet: wallet);
  final creds = await clob.createOrDeriveApiKey();
  clob.close();

  final rfq = RfqClient(wallet: wallet, credentials: creds);

  print('--- getConfig ---');
  try {
    final cfg = await rfq.getConfig();
    print(cfg);
  } catch (e) { print('ERROR: $e'); }

  print('--- getRequests ---');
  try {
    final resp = await rfq.getRequests(GetRfqRequestsParams(limit: 5));
    print('count: ${resp.count}, totalCount: ${resp.totalCount}, data: ${resp.data}');
  } catch (e) { print('ERROR: $e'); }

  print('--- getRequesterQuotes ---');
  try {
    final resp = await rfq.getRequesterQuotes(GetRfqQuotesParams(limit: 5));
    print('count: ${resp.count}, data: ${resp.data}');
  } catch (e) { print('ERROR: $e'); }

  rfq.close();
}
