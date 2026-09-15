import 'package:flutter/material.dart';

import '../../parsing/log_record.dart';

class SeverityBadge extends StatelessWidget {
  final CrashSeverity severity;
  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (severity) {
      CrashSeverity.fatal => (
          const Color(0xFFFDE2E1),
          const Color(0xFFB3261E),
          'FATAL',
        ),
      CrashSeverity.error => (
          const Color(0xFFFFE8D6),
          const Color(0xFFB5540A),
          'ERROR',
        ),
      CrashSeverity.warning => (
          const Color(0xFFFFF4CC),
          const Color(0xFF8A6D00),
          'WARNING',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class StatusCodeBadge extends StatelessWidget {
  final int? statusCode;
  const StatusCodeBadge({super.key, this.statusCode});

  @override
  Widget build(BuildContext context) {
    final code = statusCode;
    final Color bg;
    final Color fg;
    final String label;
    if (code == null) {
      bg = const Color(0xFFE6E6FA);
      fg = const Color(0xFF4B3FA0);
      label = 'TRANSPORT';
    } else if (code >= 500) {
      bg = const Color(0xFFFDE2E1);
      fg = const Color(0xFFB3261E);
      label = '$code';
    } else {
      bg = const Color(0xFFFFE8D6);
      fg = const Color(0xFFB5540A);
      label = '$code';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
