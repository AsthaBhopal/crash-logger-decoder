import 'log_record.dart';

/// Parses the plaintext `crashes_<category>_<date>.txt` files per
/// crash-log-decoder spec §3. The format is hand-written free text with
/// optional lines, so parsing is deliberately lenient: split on the
/// `--- CRASH ---` / `--- API ERROR ---` ... `--- END ---` banners, then
/// read label-prefixed lines until the next banner. Anything that doesn't
/// match either banner is kept as an `unparsed` record rather than dropped.
class LogParser {
  static const _crashStart = '--- CRASH ---';
  static const _apiStart = '--- API ERROR ---';
  static const _end = '--- END ---';

  static final _fileDateRegex = RegExp(
    r'^crashes_(api|bloc|ui)_(\d{4}-\d{2}-\d{2})\.txt$',
  );

  static final _apiFirstLineRegex = RegExp(
    r'^\[(\d{2}:\d{2}:\d{2})\]\s+(\S+)\s+(.*)$',
  );

  static const _crashSingleLineLabels = {
    'Time',
    'Severity',
    'Category',
    'Type',
    'Message',
    'Source',
    'Device',
    'OS',
    'RAM',
    'Disk',
    'Network',
    'Locale',
    'App',
    'Uptime',
    'Route',
    'User',
  };
  static const _crashMultiLineLabels = {'Breadcrumbs', 'Stack'};

  static List<LogRecord> parseFile(String fileName, String content) {
    final fileDateMatch = _fileDateRegex.firstMatch(fileName);
    final fileDate = fileDateMatch?.group(2);
    final fileCategory = fileDateMatch?.group(1);

    final records = <LogRecord>[];
    final lines = content.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trimRight();

      if (line.trim() == _crashStart) {
        final end = _findEnd(lines, i + 1);
        final block = lines.sublist(i + 1, end).join('\n');
        final raw = lines.sublist(i, end < lines.length ? end + 1 : end).join('\n');
        records.add(_parseCrash(fileName, fileCategory, fileDate, block, raw));
        i = end + 1;
        continue;
      }

      if (line.trim() == _apiStart) {
        final end = _findEnd(lines, i + 1);
        final block = lines.sublist(i + 1, end).join('\n');
        final raw = lines.sublist(i, end < lines.length ? end + 1 : end).join('\n');
        records.add(_parseApiError(fileName, fileDate, block, raw));
        i = end + 1;
        continue;
      }

      if (line.trim().isEmpty) {
        i++;
        continue;
      }

      // Unrecognized content outside any known banner — collect until the
      // next banner (or EOF) and surface it rather than dropping it.
      final start = i;
      while (i < lines.length &&
          lines[i].trim() != _crashStart &&
          lines[i].trim() != _apiStart) {
        i++;
      }
      final raw = lines.sublist(start, i).join('\n').trim();
      if (raw.isNotEmpty) {
        records.add(LogRecord(
          kind: RecordKind.unparsed,
          sourceFile: fileName,
          raw: raw,
        ));
      }
    }

    return records;
  }

  static int _findEnd(List<String> lines, int from) {
    for (var j = from; j < lines.length; j++) {
      if (lines[j].trim() == _end) return j;
    }
    return lines.length; // unterminated (e.g. truncated write) — take the rest
  }

  static LogRecord _parseCrash(
    String fileName,
    String? fileCategory,
    String? fileDate,
    String block,
    String raw,
  ) {
    final lines = block.split('\n');
    final fields = <String, String>{};
    String? currentMultiLabel;
    final buffers = <String, List<String>>{};

    final labelRegex = RegExp(r'^([A-Za-z]+)\s*:(.*)$');

    for (final rawLine in lines) {
      final match = labelRegex.firstMatch(rawLine);
      if (match != null && _crashSingleLineLabels.contains(match.group(1))) {
        currentMultiLabel = null;
        fields[match.group(1)!] = match.group(2)!.trim();
        continue;
      }
      if (match != null && _crashMultiLineLabels.contains(match.group(1))) {
        currentMultiLabel = match.group(1);
        buffers[currentMultiLabel!] = [];
        final rest = match.group(2)!.trim();
        if (rest.isNotEmpty) buffers[currentMultiLabel]!.add(rest);
        continue;
      }
      if (currentMultiLabel != null) {
        buffers[currentMultiLabel]!.add(rawLine);
      }
    }

    for (final label in _crashMultiLineLabels) {
      if (buffers.containsKey(label)) {
        // Trim trailing blank lines only — interior blank lines are content.
        final buf = List<String>.from(buffers[label]!);
        while (buf.isNotEmpty && buf.last.trim().isEmpty) {
          buf.removeLast();
        }
        fields[label] = buf.join('\n');
      }
    }

    DateTime? timestamp;
    final timeStr = fields['Time'];
    if (timeStr != null) {
      timestamp = DateTime.tryParse(timeStr);
    }

    CrashSeverity? severity;
    switch (fields['Severity']) {
      case 'FATAL':
        severity = CrashSeverity.fatal;
        break;
      case 'ERROR':
        severity = CrashSeverity.error;
        break;
      case 'WARNING':
        severity = CrashSeverity.warning;
        break;
    }

    return LogRecord(
      kind: RecordKind.crash,
      sourceFile: fileName,
      raw: raw,
      timestamp: timestamp,
      severity: severity,
      category: fields['Category'] ?? fileCategory,
      type: fields['Type'],
      message: fields['Message'],
      source: fields['Source'],
      device: fields['Device'],
      os: fields['OS'],
      ram: fields['RAM'],
      disk: fields['Disk'],
      network: fields['Network'],
      locale: fields['Locale'],
      app: fields['App'],
      uptime: fields['Uptime'],
      route: fields['Route'],
      user: fields['User'],
      breadcrumbs: fields['Breadcrumbs'],
      stack: fields['Stack'],
    );
  }

  static LogRecord _parseApiError(
    String fileName,
    String? fileDate,
    String block,
    String raw,
  ) {
    final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
    String? timeStr;
    String? method;
    String? url;
    final fields = <String, String>{};

    final labelRegex = RegExp(r'^([A-Za-z ]+):\s*(.*)$');

    for (final line in lines) {
      final firstLineMatch = _apiFirstLineRegex.firstMatch(line);
      if (firstLineMatch != null && timeStr == null && method == null) {
        timeStr = firstLineMatch.group(1);
        method = firstLineMatch.group(2);
        url = firstLineMatch.group(3);
        continue;
      }
      final match = labelRegex.firstMatch(line);
      if (match != null) {
        fields[match.group(1)!.trim()] = match.group(2)!.trim();
      }
    }

    DateTime? timestamp;
    if (timeStr != null && fileDate != null) {
      timestamp = DateTime.tryParse('$fileDate $timeStr');
    }

    int? statusCode;
    if (fields.containsKey('Status Code')) {
      statusCode = int.tryParse(fields['Status Code']!);
    }

    int? responseTimeMs;
    final rt = fields['Response Time'];
    if (rt != null) {
      responseTimeMs = int.tryParse(rt.replaceAll(RegExp(r'[^0-9]'), ''));
    }

    return LogRecord(
      kind: RecordKind.apiError,
      sourceFile: fileName,
      raw: raw,
      timestamp: timestamp,
      category: 'api',
      method: method,
      url: url,
      statusCode: statusCode,
      responseTimeMs: responseTimeMs,
      transportError: fields['Error'],
      requestHeaders: fields['Request Headers'],
      requestBody: fields['Request Body'],
      responseBody: fields['Response Body'],
      device: fields['Device'],
      user: fields['User'],
    );
  }
}
