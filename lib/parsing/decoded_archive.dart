import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'log_parser.dart';
import 'log_record.dart';

class DecodedFile {
  final String fileName;
  final List<LogRecord> records;

  DecodedFile({required this.fileName, required this.records});

  /// "api" | "bloc" | "ui" | null, parsed from the filename.
  String? get category {
    final m = RegExp(r'^crashes_(api|bloc|ui)_').firstMatch(fileName);
    return m?.group(1);
  }

  /// yyyy-MM-dd, parsed from the filename.
  String? get date {
    final m = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(fileName);
    return m?.group(1);
  }
}

class InvalidZipException implements Exception {
  final String message;
  InvalidZipException(this.message);
  @override
  String toString() => message;
}

class DecodedArchive {
  static List<DecodedFile> unzipAndParse(Uint8List plaintextZip) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(plaintextZip);
    } catch (e) {
      throw InvalidZipException(
        'Decrypted, but the contents aren\'t a valid zip — this shouldn\'t '
        'normally happen; the archive may be from an incompatible/future '
        'format version.',
      );
    }

    final files = <DecodedFile>[];
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final bytes = entry.content as List<int>;
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      final records = LogParser.parseFile(entry.name, text);
      files.add(DecodedFile(fileName: entry.name, records: records));
    }

    files.sort((a, b) {
      final ad = a.date;
      final bd = b.date;
      if (ad == null && bd == null) return a.fileName.compareTo(b.fileName);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad); // newest first
    });

    return files;
  }
}
