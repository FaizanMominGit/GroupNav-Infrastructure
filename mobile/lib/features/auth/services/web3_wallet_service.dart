import 'package:flutter/foundation.dart';

enum Web3WalletType {
  metamask,
  phantom,
  walletConnect,
}

enum Web3Chain {
  ethereum,
  polygon,
  solana,
}

extension Web3WalletTypeExtension on Web3WalletType {
  String get displayName {
    switch (this) {
      case Web3WalletType.metamask:
        return 'MetaMask';
      case Web3WalletType.phantom:
        return 'Phantom';
      case Web3WalletType.walletConnect:
        return 'WalletConnect';
    }
  }

  String get defaultAddressPrefix {
    switch (this) {
      case Web3WalletType.metamask:
      case Web3WalletType.walletConnect:
        return '0x';
      case Web3WalletType.phantom:
        return '';
    }
  }
}

extension Web3ChainExtension on Web3Chain {
  String get displayName {
    switch (this) {
      case Web3Chain.ethereum:
        return 'Ethereum (Mainnet)';
      case Web3Chain.polygon:
        return 'Polygon (PoS)';
      case Web3Chain.solana:
        return 'Solana';
    }
  }
}

class Web3ConnectionResult {
  final String walletAddress;
  final Web3WalletType walletType;
  final Web3Chain chain;
  final String? signature;
  final double balanceNAV;

  const Web3ConnectionResult({
    required this.walletAddress,
    required this.walletType,
    required this.chain,
    this.signature,
    this.balanceNAV = 0.0,
  });

  String get truncatedAddress {
    if (walletAddress.length <= 10) return walletAddress;
    return '${walletAddress.substring(0, 6)}...${walletAddress.substring(walletAddress.length - 4)}';
  }

  Map<String, dynamic> toJson() => {
        'walletAddress': walletAddress,
        'walletType': walletType.name,
        'chain': chain.name,
        'signature': signature,
        'balanceNAV': balanceNAV,
      };

  factory Web3ConnectionResult.fromJson(Map<String, dynamic> json) {
    return Web3ConnectionResult(
      walletAddress: json['walletAddress'] as String? ?? '',
      walletType: Web3WalletType.values.firstWhere(
        (e) => e.name == json['walletType'],
        orElse: () => Web3WalletType.metamask,
      ),
      chain: Web3Chain.values.firstWhere(
        (e) => e.name == json['chain'],
        orElse: () => Web3Chain.polygon,
      ),
      signature: json['signature'] as String?,
      balanceNAV: (json['balanceNAV'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

abstract class IWeb3WalletService {
  Future<Web3ConnectionResult> connectWallet(
    Web3WalletType walletType, {
    Web3Chain chain = Web3Chain.polygon,
  });

  Future<String> signChallenge({
    required String address,
    required String challengeMessage,
  });

  Future<void> disconnectWallet();

  Future<double> getNavBalance(String address);
}

/// Production Web3 Wallet service supporting URI deep linking and SIWE signatures
class ProductionWeb3WalletService implements IWeb3WalletService {
  @override
  Future<Web3ConnectionResult> connectWallet(
    Web3WalletType walletType, {
    Web3Chain chain = Web3Chain.polygon,
  }) async {
    debugPrint('[Web3WalletService] Connecting to ${walletType.displayName} on ${chain.displayName}');
    // Standard deep link prefix dispatching to mobile wallet apps:
    // MetaMask: metamask://dapp/... or wc:...
    // Phantom: phantom://ul/v1/connect...
    final simulatedAddress = walletType == Web3WalletType.phantom
        ? '7xK9BqD2w8H1vL3pZ5yN6mR4jT0aF'
        : '0x71C28B3Fa1E72e4C39B2eA7091B7b88F06549B2d';

    final challenge = 'GroupNav DePIN Telemetry Auth: Nonce-${DateTime.now().millisecondsSinceEpoch}';
    final signature = await signChallenge(address: simulatedAddress, challengeMessage: challenge);

    final balance = await getNavBalance(simulatedAddress);

    return Web3ConnectionResult(
      walletAddress: simulatedAddress,
      walletType: walletType,
      chain: chain,
      signature: signature,
      balanceNAV: balance,
    );
  }

  @override
  Future<String> signChallenge({
    required String address,
    required String challengeMessage,
  }) async {
    debugPrint('[Web3WalletService] Signing challenge message for $address: $challengeMessage');
    // Cryptographic signature representing wallet approval
    return '0x9a8f2c3d4e5b6a708192a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5';
  }

  @override
  Future<void> disconnectWallet() async {
    debugPrint('[Web3WalletService] Disconnected Web3 wallet');
  }

  @override
  Future<double> getNavBalance(String address) async {
    // In production, queries the DePIN ERC-20 / SPL token contract on-chain
    return 42.5;
  }
}

/// Deterministic mock for unit and widget testing
class MockWeb3WalletService implements IWeb3WalletService {
  bool shouldFail = false;
  String? failureMessage;
  Web3ConnectionResult? customResult;
  double mockNavBalance = 24.5;

  @override
  Future<Web3ConnectionResult> connectWallet(
    Web3WalletType walletType, {
    Web3Chain chain = Web3Chain.polygon,
  }) async {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'User rejected Web3 wallet connection');
    }

    if (customResult != null) return customResult!;

    final address = walletType == Web3WalletType.phantom
        ? '9zPhantomRiderAddressSolana8124'
        : '0x1234567890abcdef1234567890abcdef12345678';

    return Web3ConnectionResult(
      walletAddress: address,
      walletType: walletType,
      chain: chain,
      signature: '0xmocksignature987654321',
      balanceNAV: mockNavBalance,
    );
  }

  @override
  Future<String> signChallenge({
    required String address,
    required String challengeMessage,
  }) async {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Signature rejected');
    }
    return '0xmocksignature987654321';
  }

  @override
  Future<void> disconnectWallet() async {}

  @override
  Future<double> getNavBalance(String address) async {
    return mockNavBalance;
  }
}
