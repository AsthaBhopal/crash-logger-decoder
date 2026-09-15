import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../crypto/crash_log_decryptor.dart';
import '../crypto/default_key.dart';
import '../parsing/decoded_archive.dart';
import '../parsing/log_record.dart';

enum AppScreen { keyEntry, filePicker, viewer }

class AppState extends ChangeNotifier {
  // Private key lives in memory only for the life of this tab. Never
  // persisted — see crash-log-decoder spec §5a/§6.
  Uint8List? _privateKey;
  String? keyErrorText;

  AppState() {
    // Preloaded so the common case skips the key-entry screen entirely.
    // "Change key" still routes back here for a rotation-window override.
    setPrivateKeyFromBase64(kDefaultPrivateKeyBase64);
  }

  bool isDecoding = false;
  String? decodeErrorText;

  List<DecodedFile> decodedFiles = [];
  List<String> openTabs = [];
  List<String> closedTabs = [];
  String? activeTab;
  LogRecord? selectedRecord;

  String searchQuery = '';
  final Set<CrashSeverity> severityFilter = {}; // empty == show all

  AppScreen get screen {
    if (_privateKey == null) return AppScreen.keyEntry;
    if (decodedFiles.isEmpty) return AppScreen.filePicker;
    return AppScreen.viewer;
  }

  bool get hasKey => _privateKey != null;

  /// Validates and stores the private key. Returns true on success.
  bool setPrivateKeyFromBase64(String input) {
    final trimmed = input.trim();
    try {
      final decoded = base64.decode(trimmed);
      if (decoded.length != 32) {
        keyErrorText =
            "Doesn't look like a valid key (expected 32 bytes after decoding, got ${decoded.length}).";
        notifyListeners();
        return false;
      }
      _privateKey = Uint8List.fromList(decoded);
      keyErrorText = null;
      notifyListeners();
      return true;
    } catch (_) {
      keyErrorText = "Doesn't look like valid base64.";
      notifyListeners();
      return false;
    }
  }

  void clearKey() {
    _privateKey = null;
    keyErrorText = null;
    _resetArchive();
    notifyListeners();
  }

  Future<void> decodeFile(Uint8List bytes) async {
    if (_privateKey == null) return;
    isDecoding = true;
    decodeErrorText = null;
    notifyListeners();

    try {
      final plaintext = await CrashLogDecryptor.decrypt(bytes, _privateKey!);
      final files = DecodedArchive.unzipAndParse(plaintext);

      decodedFiles = files;
      openTabs = files.map((f) => f.fileName).toList();
      closedTabs = [];
      activeTab = openTabs.isNotEmpty ? openTabs.first : null;
      selectedRecord = null;
    } on CrashLogDecryptException catch (e) {
      decodeErrorText = e.message;
    } on InvalidZipException catch (e) {
      decodeErrorText = e.message;
    } catch (e) {
      decodeErrorText = 'Unexpected error while decoding: $e';
    } finally {
      isDecoding = false;
      notifyListeners();
    }
  }

  void _resetArchive() {
    decodedFiles = [];
    openTabs = [];
    closedTabs = [];
    activeTab = null;
    selectedRecord = null;
    decodeErrorText = null;
    searchQuery = '';
    severityFilter.clear();
  }

  void openAnotherFile() {
    _resetArchive();
    notifyListeners();
  }

  DecodedFile? get activeFile {
    if (activeTab == null) return null;
    return decodedFiles.firstWhere(
      (f) => f.fileName == activeTab,
      orElse: () => decodedFiles.isNotEmpty
          ? decodedFiles.first
          : DecodedFile(fileName: '', records: const []),
    );
  }

  void selectTab(String fileName) {
    activeTab = fileName;
    selectedRecord = null;
    notifyListeners();
  }

  void closeTab(String fileName) {
    openTabs.remove(fileName);
    closedTabs.add(fileName);
    if (activeTab == fileName) {
      activeTab = openTabs.isNotEmpty ? openTabs.first : null;
      selectedRecord = null;
    }
    notifyListeners();
  }

  void reopenTab(String fileName) {
    closedTabs.remove(fileName);
    openTabs.add(fileName);
    activeTab = fileName;
    notifyListeners();
  }

  void selectRecord(LogRecord? record) {
    selectedRecord = record;
    notifyListeners();
  }

  void setSearch(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void toggleSeverity(CrashSeverity severity) {
    if (severityFilter.contains(severity)) {
      severityFilter.remove(severity);
    } else {
      severityFilter.add(severity);
    }
    notifyListeners();
  }

  List<LogRecord> filteredRecords(List<LogRecord> records) {
    Iterable<LogRecord> result = records;
    if (severityFilter.isNotEmpty) {
      result = result.where(
        (r) => r.severity != null && severityFilter.contains(r.severity),
      );
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((r) {
        return (r.message?.toLowerCase().contains(q) ?? false) ||
            (r.source?.toLowerCase().contains(q) ?? false) ||
            (r.url?.toLowerCase().contains(q) ?? false) ||
            (r.stack?.toLowerCase().contains(q) ?? false) ||
            (r.type?.toLowerCase().contains(q) ?? false) ||
            r.raw.toLowerCase().contains(q);
      });
    }
    return result.toList();
  }
}
