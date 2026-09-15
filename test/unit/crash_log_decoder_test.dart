import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crash_logs_decode/crypto/crash_log_decryptor.dart';
import 'package:crash_logs_decode/parsing/decoded_archive.dart';

const _magic = [0x46, 0x4C, 0x4F, 0x57, 0x43, 0x4C, 0x45, 0x31]; // "FLOWCLE1"

/// Builds a FLOWCLE1 blob the same way the mobile app's encryptor does,
/// so the test exercises the real decrypt path end to end rather than a
/// hand-rolled shortcut.
Future<Uint8List> _encryptFlowcle1({
  required Uint8List recipientPublicKey,
  required Uint8List plaintext,
}) async {
  final x25519 = X25519();
  final ephemeralKeyPair = await x25519.newKeyPair();
  final ephemeralPublic = await ephemeralKeyPair.extractPublicKey();

  final sharedSecret = await x25519.sharedSecretKey(
    keyPair: ephemeralKeyPair,
    remotePublicKey: SimplePublicKey(recipientPublicKey, type: KeyPairType.x25519),
  );

  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final aesKey = await hkdf.deriveKey(
    secretKey: sharedSecret,
    nonce: ephemeralPublic.bytes,
    info: _magic,
  );

  final nonce = AesGcm.with256bits().newNonce();
  final secretBox = await AesGcm.with256bits().encrypt(
    plaintext,
    secretKey: aesKey,
    nonce: nonce,
  );

  return Uint8List.fromList([
    ..._magic,
    ...ephemeralPublic.bytes,
    ...nonce,
    ...secretBox.cipherText,
    ...secretBox.mac.bytes,
  ]);
}

void main() {
  group('CrashLogDecryptor (FLOWCLE1 round-trip)', () {
    late Uint8List recipientSeed;
    late Uint8List recipientPublicKey;
    late Uint8List plaintextZip;

    setUp(() async {
      final x25519 = X25519();
      final recipientKeyPair = await x25519.newKeyPair();
      recipientSeed = Uint8List.fromList(
        await (recipientKeyPair as SimpleKeyPairData).extractPrivateKeyBytes(),
      );
      recipientPublicKey =
          Uint8List.fromList((await recipientKeyPair.extractPublicKey()).bytes);

      final archive = Archive();
      const body = '--- CRASH ---\n'
          'Time     : 2026-09-10 14:32:07\n'
          'Severity : ERROR\n'
          'Category : ui\n'
          'Type     : StateError\n'
          'Message  : Bad state: no element\n'
          'Source   : GoalConfigScreen._onContinueTap\n'
          '\n'
          'Device   : Pixel 8 (Pixel 8) · physical\n'
          'OS       : Android 14 (SDK 34)\n'
          'RAM      : total 8.0 GB · free 3.2 GB · app RSS 210 MB (peak 340 MB)\n'
          'Disk     : free 45.1 GB / 128.0 GB\n'
          'Network  : wifi\n'
          'Locale   : en_IN · Asia/Kolkata\n'
          '\n'
          'App      : 4.12.0 (Build 812) · prod · com.wave.astha\n'
          'Uptime   : 00:14:22\n'
          'Route    : /stock_details_screen_route\n'
          'User     : AB1234\n'
          '\n'
          'Breadcrumbs :\n'
          'GoalListBloc: Loading -> Loaded\n'
          'GoalConfigBloc: Idle -> Submitting\n'
          '\n'
          'Stack    :\n'
          '#0 GoalConfigScreen._onContinueTap\n'
          '#1 _InkResponseState.handleTap\n'
          '--- END ---\n';
      final bytes = Uint8List.fromList(body.codeUnits);
      archive.addFile(ArchiveFile('crashes_ui_2026-09-10.txt', bytes.length, bytes));
      plaintextZip = Uint8List.fromList(ZipEncoder().encode(archive)!);
    });

    test('decrypts a well-formed archive and recovers the original zip bytes',
        () async {
      final blob = await _encryptFlowcle1(
        recipientPublicKey: recipientPublicKey,
        plaintext: plaintextZip,
      );

      final decrypted = await CrashLogDecryptor.decrypt(blob, recipientSeed);
      expect(decrypted, equals(plaintextZip));

      final files = DecodedArchive.unzipAndParse(decrypted);
      expect(files, hasLength(1));
      expect(files.single.records, hasLength(1));
      final record = files.single.records.single;
      expect(record.message, 'Bad state: no element');
      expect(record.user, 'AB1234');
      expect(record.breadcrumbs, contains('GoalConfigBloc: Idle -> Submitting'));
    });

    test('rejects a file shorter than the minimum header+tag length', () async {
      final tooShort = Uint8List(40);
      expect(
        () => CrashLogDecryptor.decrypt(tooShort, recipientSeed),
        throwsA(
          isA<CrashLogDecryptException>().having(
            (e) => e.kind,
            'kind',
            CrashLogDecryptErrorKind.fileTooShort,
          ),
        ),
      );
    });

    test('rejects a file with a corrupted magic header', () async {
      final blob = await _encryptFlowcle1(
        recipientPublicKey: recipientPublicKey,
        plaintext: plaintextZip,
      );
      blob[0] = 0x00;
      expect(
        () => CrashLogDecryptor.decrypt(blob, recipientSeed),
        throwsA(
          isA<CrashLogDecryptException>().having(
            (e) => e.kind,
            'kind',
            CrashLogDecryptErrorKind.badMagic,
          ),
        ),
      );
    });

    test('rejects a file whose GCM tag has been tampered with', () async {
      final blob = await _encryptFlowcle1(
        recipientPublicKey: recipientPublicKey,
        plaintext: plaintextZip,
      );
      blob[blob.length - 1] ^= 0xFF; // flip one bit of the mac
      expect(
        () => CrashLogDecryptor.decrypt(blob, recipientSeed),
        throwsA(
          isA<CrashLogDecryptException>().having(
            (e) => e.kind,
            'kind',
            CrashLogDecryptErrorKind.authenticationFailed,
          ),
        ),
      );
    });

    test('rejects decryption against the wrong private key', () async {
      final blob = await _encryptFlowcle1(
        recipientPublicKey: recipientPublicKey,
        plaintext: plaintextZip,
      );
      final x25519 = X25519();
      final wrongKeyPair = await x25519.newKeyPair();
      final wrongSeed = Uint8List.fromList(
        await (wrongKeyPair as SimpleKeyPairData).extractPrivateKeyBytes(),
      );
      expect(
        () => CrashLogDecryptor.decrypt(blob, wrongSeed),
        throwsA(
          isA<CrashLogDecryptException>().having(
            (e) => e.kind,
            'kind',
            CrashLogDecryptErrorKind.authenticationFailed,
          ),
        ),
      );
    });
  });
}
