/// Offline tests for the authenticated CLOB user channel — verifies the
/// `trade` and `order` message parsing against the documented field names, and
/// the credential guard. No network (the socket itself is covered by opt-in
/// integration runs).
library;

import 'package:polymarket_dart/polymarket_dart.dart';
import 'package:test/test.dart';

void main() {
  group('UserChannelTrade parsing', () {
    test('parses a full trade message incl. maker_orders', () {
      final trade = UserChannelTrade.fromJson({
        'event_type': 'trade',
        'type': 'TRADE',
        'id': 'trade-1',
        'asset_id': '0xasset',
        'market': '0xcondition',
        'side': 'BUY',
        'size': '12.5',
        'price': '0.63',
        'outcome': 'Yes',
        'owner': '0xowner',
        'status': 'MATCHED',
        'match_time': '1700000000',
        'taker_order_id': '0xtaker',
        'trade_owner': '0xtradeowner',
        'timestamp': '1700000001',
        'maker_orders': [
          {
            'asset_id': '0xasset',
            'matched_amount': '5',
            'order_id': '0xmaker1',
            'outcome': 'Yes',
            'owner': '0xmakerowner',
            'price': '0.62',
          },
        ],
      });

      expect(trade.id, equals('trade-1'));
      expect(trade.market, equals('0xcondition'));
      expect(trade.side, equals('BUY'));
      expect(trade.status, equals('MATCHED'));
      expect(trade.takerOrderId, equals('0xtaker'));
      expect(trade.makerOrders, hasLength(1));
      expect(trade.makerOrders.first.orderId, equals('0xmaker1'));
      expect(trade.makerOrders.first.matchedAmount, equals('5'));
      // Raw payload preserved for forward compatibility.
      expect(trade.raw['event_type'], equals('trade'));
    });

    test('tolerates a trade with no maker_orders', () {
      final trade = UserChannelTrade.fromJson({
        'id': 't2',
        'market': '0xc',
        'status': 'CONFIRMED',
      });
      expect(trade.makerOrders, isEmpty);
      expect(trade.status, equals('CONFIRMED'));
    });
  });

  group('UserChannelOrder parsing', () {
    test('parses a placement order with associate_trades', () {
      final order = UserChannelOrder.fromJson({
        'event_type': 'order',
        'type': 'PLACEMENT',
        'id': '0xorder',
        'asset_id': '0xasset',
        'market': '0xcondition',
        'order_owner': '0xorderowner',
        'owner': '0xowner',
        'original_size': '100',
        'size_matched': '25',
        'outcome': 'No',
        'price': '0.41',
        'side': 'SELL',
        'timestamp': '1700000002',
        'associate_trades': ['trade-1', 'trade-2'],
      });

      expect(order.id, equals('0xorder'));
      expect(order.type, equals('PLACEMENT'));
      expect(order.originalSize, equals('100'));
      expect(order.sizeMatched, equals('25'));
      expect(order.orderOwner, equals('0xorderowner'));
      expect(order.associateTrades, equals(['trade-1', 'trade-2']));
    });

    test('handles cancellation with no associate_trades', () {
      final order = UserChannelOrder.fromJson({
        'type': 'CANCELLATION',
        'id': '0xorder',
        'market': '0xcondition',
      });
      expect(order.type, equals('CANCELLATION'));
      expect(order.associateTrades, isEmpty);
    });
  });

  group('user channel guards', () {
    test('subscribeUserChannelOrders without connect throws StateError', () {
      final ws = WebSocketClient();
      expect(() => ws.subscribeUserChannelOrders(['0xcond']),
          throwsA(isA<StateError>()));
    });

    test('subscribeUserChannelTrades without connect throws StateError', () {
      final ws = WebSocketClient();
      expect(() => ws.subscribeUserChannelTrades(['0xcond']),
          throwsA(isA<StateError>()));
    });

    test('isUserConnected is false before connecting', () {
      final ws = WebSocketClient();
      expect(ws.isUserConnected, isFalse);
    });
  });
}
