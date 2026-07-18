/// Polymarket Combos / RFQ REST client.
///
/// Combos combine several market outcomes into a single YES/NO position that
/// trades through an RFQ auction. This client covers:
///
/// - **Public discovery** — combo markets (combos-rfq-api), and a user's combo
///   positions and activity (data-api). No authentication required.
/// - **Maker flow** — submit/cancel quotes and respond to Last Look. These
///   require Level 2 (CLOB HMAC) credentials.
///
/// ```dart
/// // Public: browse combo-eligible markets
/// final combo = ComboClient();
/// final page = await combo.getComboMarkets(
///   const GetComboMarketsParams(limit: 20),
/// );
///
/// // Maker: submit a quote (requires CLOB L2 credentials)
/// final maker = ComboClient(wallet: wallet, credentials: creds);
/// await maker.submitQuote(SubmitQuoteParams(...));
/// ```
library;

import 'dart:convert';

import '../models/clob_types.dart';
import '../models/combo_types.dart';
import '../signing/hmac_auth.dart';
import '../signing/wallet_adapter.dart';
import '../transport/http_transport.dart';
import '../utils/constants.dart';

/// Client for the Polymarket Combos / RFQ API.
///
/// Public discovery methods work with no arguments. Maker methods
/// ([submitQuote], [cancelQuote], [submitConfirmation]) require a [wallet] and
/// Level 2 [ApiCredentials]; calling them without credentials throws
/// [StateError].
class ComboClient {
  final HttpTransport _transport;
  final WalletAdapter? _wallet;
  final HmacAuth? _hmac;

  ComboClient({
    WalletAdapter? wallet,
    ApiCredentials? credentials,
    HttpTransport? transport,
  })  : _wallet = wallet,
        _hmac = credentials == null
            ? null
            : HmacAuth(
                apiKey: credentials.apiKey,
                secret: credentials.secret,
                passphrase: credentials.passphrase,
              ),
        _transport = transport ?? HttpTransport();

  // ---------------------------------------------------------------------------
  // Public discovery
  // ---------------------------------------------------------------------------

  /// List combo-eligible markets, ordered by volume descending.
  ///
  /// Public — no authentication required.
  Future<ComboMarketsPage> getComboMarkets([
    GetComboMarketsParams? params,
  ]) async {
    final res = await _transport.get(
      PolymarketUrls.combosRfq,
      '/v1/rfq/combo-markets',
      queryParams: params?.toQueryParams(),
    ) as Map<String, dynamic>;
    return ComboMarketsPage.fromJson(res);
  }

  /// List a user's combo positions (Data API).
  ///
  /// Public — no authentication required. [GetComboPositionsParams.user] is
  /// the wallet address to query.
  Future<ComboPositionsPage> getComboPositions(
    GetComboPositionsParams params,
  ) async {
    final res = await _transport.get(
      PolymarketUrls.data,
      '/v1/positions/combos',
      queryParams: params.toQueryParams(),
    ) as Map<String, dynamic>;
    return ComboPositionsPage.fromJson(res);
  }

  /// List a user's combo lifecycle activity (Data API).
  ///
  /// Public — no authentication required.
  Future<ComboActivityPage> getComboActivity(
    GetComboActivityParams params,
  ) async {
    final res = await _transport.get(
      PolymarketUrls.data,
      '/v1/activity/combos',
      queryParams: params.toQueryParams(),
    ) as Map<String, dynamic>;
    return ComboActivityPage.fromJson(res);
  }

  // ---------------------------------------------------------------------------
  // Maker flow (Level 2 auth)
  // ---------------------------------------------------------------------------

  /// Submit a signed quote in response to an RFQ (`POST /v1/maker/quotes`).
  ///
  /// Requires Level 2 credentials.
  Future<RfqSnapshot> submitQuote(SubmitQuoteParams params) async {
    return _postAuthed('/v1/maker/quotes', params.toJson());
  }

  /// Cancel a previously submitted quote (`POST /v1/maker/quotes/cancel`).
  ///
  /// Requires Level 2 credentials.
  Future<RfqSnapshot> cancelQuote(CancelQuoteParams params) async {
    return _postAuthed('/v1/maker/quotes/cancel', params.toJson());
  }

  /// Confirm or decline a Last Look fill (`POST /v1/maker/confirmations`).
  ///
  /// On CONFIRM the response carries an `execution` object; while awaiting
  /// other makers, or on DECLINE, it carries a `snapshot`. Either way the raw
  /// body is available via [RfqSnapshot.raw].
  ///
  /// Requires Level 2 credentials.
  Future<RfqSnapshot> submitConfirmation(ConfirmationParams params) async {
    return _postAuthed('/v1/maker/confirmations', params.toJson());
  }

  /// Close the underlying HTTP client.
  void close() => _transport.close();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<RfqSnapshot> _postAuthed(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final wallet = _wallet;
    final hmac = _hmac;
    if (wallet == null || hmac == null) {
      throw StateError(
        'ComboClient maker endpoints require a wallet and Level 2 credentials. '
        'Construct ComboClient(wallet: ..., credentials: ...).',
      );
    }
    final address = (await wallet.getAddress()).toLowerCase();
    final body = jsonEncode(payload);
    final headers = hmac.generateHeaders(
      walletAddress: address,
      method: 'POST',
      path: path,
      body: body,
    );
    final res = await _transport.post(
      PolymarketUrls.combosRfq,
      path,
      body: jsonDecode(body),
      headers: headers,
    ) as Map<String, dynamic>;
    return RfqSnapshot.fromJson(res);
  }
}
