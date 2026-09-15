enum RecordKind { crash, apiError, unparsed }

enum CrashSeverity { fatal, error, warning }

/// Normalized shape for a single `--- CRASH ---` / `--- API ERROR ---` block,
/// per crash-log-decoder spec §3. Every field besides [kind]/[sourceFile]/[raw]
/// is optional because the source format itself makes most lines optional.
class LogRecord {
  final RecordKind kind;
  final String sourceFile;
  final String raw;

  final DateTime? timestamp;
  final CrashSeverity? severity;
  final String? category; // api | bloc | ui, as stated by the record itself
  final String? type;
  final String? message;
  final String? source;

  final String? method;
  final String? url;
  final int? statusCode;
  final int? responseTimeMs;
  final String? transportError;
  final String? requestHeaders;
  final String? requestBody;
  final String? responseBody;

  final String? device;
  final String? os;
  final String? ram;
  final String? disk;
  final String? network;
  final String? locale;
  final String? app;
  final String? uptime;
  final String? route;
  final String? user;

  final String? breadcrumbs;
  final String? stack;

  const LogRecord({
    required this.kind,
    required this.sourceFile,
    required this.raw,
    this.timestamp,
    this.severity,
    this.category,
    this.type,
    this.message,
    this.source,
    this.method,
    this.url,
    this.statusCode,
    this.responseTimeMs,
    this.transportError,
    this.requestHeaders,
    this.requestBody,
    this.responseBody,
    this.device,
    this.os,
    this.ram,
    this.disk,
    this.network,
    this.locale,
    this.app,
    this.uptime,
    this.route,
    this.user,
    this.breadcrumbs,
    this.stack,
  });

  /// Short one-line label for list rows.
  String get summary {
    switch (kind) {
      case RecordKind.crash:
        return message ?? type ?? 'Crash';
      case RecordKind.apiError:
        final status = statusCode != null ? 'HTTP $statusCode' : 'transport error';
        return '${method ?? ''} ${url ?? ''} ($status)'.trim();
      case RecordKind.unparsed:
        return 'Unparsed block';
    }
  }
}
