import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Decrypts the FLOWCLE1 wire format produced by the mobile app's
/// `CrashLogEncryptor`. Byte layout (see crash-log-decoder spec §2):
///
/// magic(8) | ephemeralPub(32) | nonce(12) | ciphertext(N) | mac(16)
class CrashLogDecryptException implements Exception {
  final CrashLogDecryptErrorKind kind;
  final String message;
  CrashLogDecryptException(this.kind, this.message);

  @override
  String toString() => message;
}

enum CrashLogDecryptErrorKind {
  fileTooShort,
  badMagic,
  authenticationFailed,
  invalidKey,
}

class CrashLogDecryptor {
  static const List<int> _magic = [
    0x46, 0x4C, 0x4F, 0x57, 0x43, 0x4C, 0x45, 0x31, // "FLOWCLE1"
  ];

  static const int _headerLen = 8 + 32 + 12; // magic + ephemeralPub + nonce
  static const int _macLen = 16;
  static const int _minLen = _headerLen + _macLen;

  /// [privateKeySeed] is the recipient's 32-byte X25519 seed.
  static Future<Uint8List> decrypt(
    Uint8List blob,
    Uint8List privateKeySeed,
  ) async {
    if (blob.length < _minLen) {
      throw CrashLogDecryptException(
        CrashLogDecryptErrorKind.fileTooShort,
        "This doesn't look like a crash-log archive (file too short).",
      );
    }

    final magic = blob.sublist(0, 8);
    if (!_bytesEqual(magic, _magic)) {
      throw CrashLogDecryptException(
        CrashLogDecryptErrorKind.badMagic,
        "This doesn't look like a crash-log archive (bad file header).",
      );
    }

    final ephemeralPub = blob.sublist(8, 40);
    final nonce = blob.sublist(40, 52);
    final mac = blob.sublist(blob.length - _macLen, blob.length);
    final cipherText = blob.sublist(52, blob.length - _macLen);

    if (privateKeySeed.length != 32) {
      throw CrashLogDecryptException(
        CrashLogDecryptErrorKind.invalidKey,
        'Private key must be exactly 32 bytes after base64 decoding.',
      );
    }

    final x25519 = X25519();
    final recipientKeyPair = await x25519.newKeyPairFromSeed(privateKeySeed);

    final sharedSecret = await x25519.sharedSecretKey(
      keyPair: recipientKeyPair,
      remotePublicKey: SimplePublicKey(
        ephemeralPub,
        type: KeyPairType.x25519,
      ),
    );

    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final aesKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: ephemeralPub, // HKDF salt == ephemeral public key (see spec §2)
      info: _magic,
    );

    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    try {
      final plaintext = await aesGcm.decrypt(secretBox, secretKey: aesKey);
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw CrashLogDecryptException(
        CrashLogDecryptErrorKind.authenticationFailed,
        "Couldn't decrypt — either this isn't the matching private key for "
        'this file, or the file is corrupted/was modified after export. '
        'If you have more than one key (e.g. after a rotation), try another.',
      );
    }
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
