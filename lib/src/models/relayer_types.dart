/// Data models for the Polymarket gasless relayer (v2) API.
///
/// Host: `https://relayer-v2.polymarket.com`.
library;

/// Proxy-wallet type used by relayer endpoints.
enum RelayerWalletType {
  proxy,
  safe;

  /// API spelling — `PROXY` or `SAFE`.
  String toApi() => name.toUpperCase();
}

/// Response of `GET /relay-payload` — the relayer address and the current
/// nonce to use for the next transaction.
class RelayerPayload {
  final String address;
  final String nonce;

  const RelayerPayload({required this.address, required this.nonce});

  factory RelayerPayload.fromJson(Map<String, dynamic> json) => RelayerPayload(
        address: json['address'] as String? ?? '',
        nonce: json['nonce']?.toString() ?? '0',
      );
}

/// EIP-712 Safe signature parameters accompanying a relayer submission.
class RelayerSignatureParams {
  final String gasPrice;
  final String operation;
  final String safeTxnGas;
  final String baseGas;
  final String gasToken;
  final String refundReceiver;

  const RelayerSignatureParams({
    this.gasPrice = '0',
    this.operation = '0',
    this.safeTxnGas = '0',
    this.baseGas = '0',
    this.gasToken = '0x0000000000000000000000000000000000000000',
    this.refundReceiver = '0x0000000000000000000000000000000000000000',
  });

  Map<String, dynamic> toJson() => {
        'gasPrice': gasPrice,
        'operation': operation,
        'safeTxnGas': safeTxnGas,
        'baseGas': baseGas,
        'gasToken': gasToken,
        'refundReceiver': refundReceiver,
      };
}

/// Request body for `POST /submit`.
class RelayerSubmitRequest {
  final String from;
  final String to;
  final String proxyWallet;

  /// 0x-prefixed encoded transaction data.
  final String data;
  final String nonce;

  /// 0x-prefixed signature.
  final String signature;

  /// `SAFE` or `PROXY`.
  final RelayerWalletType type;
  final RelayerSignatureParams signatureParams;
  final String? value;
  final String? metadata;

  const RelayerSubmitRequest({
    required this.from,
    required this.to,
    required this.proxyWallet,
    required this.data,
    required this.nonce,
    required this.signature,
    required this.type,
    this.signatureParams = const RelayerSignatureParams(),
    this.value,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'proxyWallet': proxyWallet,
        'data': data,
        'nonce': nonce,
        'signature': signature,
        'type': type.toApi(),
        'signatureParams': signatureParams.toJson(),
        if (value != null) 'value': value,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Response of `POST /submit` — the created transaction id and its state.
class SubmitTransactionResult {
  final String transactionId;
  final String? state;

  const SubmitTransactionResult({required this.transactionId, this.state});

  factory SubmitTransactionResult.fromJson(Map<String, dynamic> json) =>
      SubmitTransactionResult(
        transactionId: json['transactionID'] as String? ?? '',
        state: json['state'] as String?,
      );
}

/// A relayer transaction record (`GET /transaction`, `GET /transactions`).
class RelayerTransaction {
  final String transactionId;
  final String? transactionHash;
  final String? from;
  final String? to;
  final String? proxyAddress;
  final String? data;
  final String? nonce;
  final String? value;
  final String? signature;

  /// One of STATE_NEW, STATE_EXECUTED, STATE_MINED, STATE_CONFIRMED,
  /// STATE_INVALID, STATE_FAILED.
  final String? state;

  /// `SAFE` or `PROXY`.
  final String? type;
  final String? owner;
  final String? metadata;
  final String? createdAt;
  final String? updatedAt;

  const RelayerTransaction({
    required this.transactionId,
    this.transactionHash,
    this.from,
    this.to,
    this.proxyAddress,
    this.data,
    this.nonce,
    this.value,
    this.signature,
    this.state,
    this.type,
    this.owner,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory RelayerTransaction.fromJson(Map<String, dynamic> json) =>
      RelayerTransaction(
        transactionId: json['transactionID'] as String? ?? '',
        transactionHash: json['transactionHash'] as String?,
        from: json['from'] as String?,
        to: json['to'] as String?,
        proxyAddress: json['proxyAddress'] as String?,
        data: json['data'] as String?,
        nonce: json['nonce']?.toString(),
        value: json['value']?.toString(),
        signature: json['signature'] as String?,
        state: json['state'] as String?,
        type: json['type'] as String?,
        owner: json['owner'] as String?,
        metadata: json['metadata'] as String?,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );

  /// Whether the relayer has fully confirmed this transaction on-chain.
  bool get isConfirmed => state == 'STATE_CONFIRMED';

  /// Whether the relayer marked this transaction invalid or failed.
  bool get isFailed => state == 'STATE_INVALID' || state == 'STATE_FAILED';
}

/// A relayer API key record (`GET /relayer/api/keys`).
class RelayerApiKey {
  final String apiKey;
  final String address;
  final String? createdAt;
  final String? updatedAt;

  const RelayerApiKey({
    required this.apiKey,
    required this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory RelayerApiKey.fromJson(Map<String, dynamic> json) => RelayerApiKey(
        apiKey: json['apiKey'] as String? ?? '',
        address: json['address'] as String? ?? '',
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}
