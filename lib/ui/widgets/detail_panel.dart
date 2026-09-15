import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../parsing/log_record.dart';
import 'severity_badge.dart';

class DetailPanel extends StatefulWidget {
  final LogRecord? record;
  const DetailPanel({super.key, required this.record});

  @override
  State<DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<DetailPanel> {
  bool _showRaw = false;

  @override
  void didUpdateWidget(DetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.record, widget.record)) {
      _showRaw = false;
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied $what'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;

    if (record == null) {
      return Center(
        child: Text(
          'Select an entry to view details',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _title(record),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _copy(record.raw, 'raw block'),
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                label: const Text('Copy raw'),
              ),
              const SizedBox(width: 4),
              FilterChip(
                label: const Text('View raw'),
                selected: _showRaw,
                onSelected: (v) => setState(() => _showRaw = v),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: _showRaw ? _RawView(text: record.raw) : _StructuredView(
              record: record,
              onCopy: _copy,
            ),
          ),
        ),
      ],
    );
  }

  String _title(LogRecord record) {
    switch (record.kind) {
      case RecordKind.crash:
        return record.type ?? 'Crash';
      case RecordKind.apiError:
        return '${record.method ?? ''} ${record.url ?? ''}'.trim();
      case RecordKind.unparsed:
        return 'Unparsed block';
    }
  }
}

class _RawView extends StatelessWidget {
  final String text;
  const _RawView({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5),
      ),
    );
  }
}

class _StructuredView extends StatelessWidget {
  final LogRecord record;
  final void Function(String text, String what) onCopy;
  const _StructuredView({required this.record, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.kind == RecordKind.crash) ..._crashSections(context, r),
        if (r.kind == RecordKind.apiError) ..._apiSections(context, r),
        if (r.kind == RecordKind.unparsed) _RawView(text: r.raw),
      ],
    );
  }

  List<Widget> _crashSections(BuildContext context, LogRecord r) {
    return [
      _Section(
        title: 'Overview',
        children: [
          if (r.severity != null) _FieldRow('Severity', null, trailing: SeverityBadge(severity: r.severity!)),
          _FieldRow('Type', r.type),
          _FieldRow('Message', r.message),
          _FieldRow('Source', r.source),
          _FieldRow('Category', r.category),
          _FieldRow('Time', r.timestamp?.toString()),
        ],
      ),
      _Section(
        title: 'Device & session',
        children: [
          _FieldRow('Device', r.device),
          _FieldRow('OS', r.os),
          _FieldRow('RAM', r.ram),
          _FieldRow('Disk', r.disk),
          _FieldRow('Network', r.network),
          _FieldRow('Locale', r.locale),
          _FieldRow('App', r.app),
          _FieldRow('Uptime', r.uptime),
          _FieldRow('Route', r.route),
          _FieldRow('User', r.user ?? '(logged out)'),
        ],
      ),
      if (r.breadcrumbs != null && r.breadcrumbs!.isNotEmpty)
        _Section(
          title: 'Breadcrumbs',
          onCopy: () => onCopy(r.breadcrumbs!, 'breadcrumbs'),
          children: [_MonoBlock(r.breadcrumbs!)],
        ),
      if (r.stack != null && r.stack!.isNotEmpty)
        _Section(
          title: 'Stack trace',
          onCopy: () => onCopy(r.stack!, 'stack trace'),
          children: [_MonoBlock(r.stack!)],
        ),
    ];
  }

  List<Widget> _apiSections(BuildContext context, LogRecord r) {
    return [
      _Section(
        title: 'Request',
        children: [
          _FieldRow('Method', r.method),
          _FieldRow('URL', r.url),
          _FieldRow('Time', r.timestamp?.toString()),
          _FieldRow('Status code', r.statusCode?.toString() ?? (r.transportError != null ? 'transport error' : null)),
          _FieldRow('Response time', r.responseTimeMs != null ? '${r.responseTimeMs}ms' : null),
          _FieldRow('Transport error', r.transportError),
        ],
      ),
      if (r.requestHeaders != null)
        _Section(
          title: 'Request headers',
          onCopy: () => onCopy(r.requestHeaders!, 'request headers'),
          children: [_MonoBlock(r.requestHeaders!)],
        ),
      if (r.requestBody != null)
        _Section(
          title: 'Request body',
          onCopy: () => onCopy(r.requestBody!, 'request body'),
          children: [_MonoBlock(r.requestBody!)],
        ),
      if (r.responseBody != null)
        _Section(
          title: 'Response body',
          onCopy: () => onCopy(r.responseBody!, 'response body'),
          children: [_MonoBlock(r.responseBody!)],
        ),
      _Section(
        title: 'Device & session',
        children: [
          _FieldRow('Device', r.device),
          _FieldRow('User', r.user ?? '(logged out)'),
        ],
      ),
    ];
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onCopy;
  const _Section({required this.title, required this.children, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (onCopy != null)
                IconButton(
                  tooltip: 'Copy',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;
  const _FieldRow(this.label, this.value, {this.trailing});

  @override
  Widget build(BuildContext context) {
    if (value == null && trailing == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: trailing ??
                SelectableText(
                  value!,
                  style: theme.textTheme.bodyMedium,
                ),
          ),
        ],
      ),
    );
  }
}

class _MonoBlock extends StatelessWidget {
  final String text;
  const _MonoBlock(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5),
      ),
    );
  }
}
