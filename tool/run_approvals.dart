import 'package:polymarket_dart/polymarket_dart.dart';
import 'dart:io';

void main() async {
  final env = File('.env').readAsStringSync();
  String? pk;
  for (final line in env.split('\n')) {
    if (line.trim().startsWith('PRIVATE_KEY=')) {
      pk = line.trim().substring('PRIVATE_KEY='.length).trim();
    }
  }
  if (pk == null) { print('No PRIVATE_KEY'); return; }
  if (!pk.startsWith('0x')) pk = '0x$pk';

  final wallet = PrivateKeyWalletAdapter(pk);
  print('EOA: ${await wallet.getAddress()}');
  await ensureEoaApprovals(wallet);
}
