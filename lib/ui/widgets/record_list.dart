import 'package:flutter/material.dart';

import '../../parsing/log_record.dart';
import 'severity_badge.dart';

class RecordList extends StatelessWidget {
  final List<LogRecord> records;
  final LogRecord? selected;
  final ValueChanged<LogRecord> onSelect;

  const RecordList({
    super.key,
    required this.records,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final record = records[index];
        final isSelected = identical(record, selected);
        return _RecordTile(
          record: record,
          selected: isSelected,
          onTap: () => onSelect(record),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 28, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              'No entries match',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final LogRecord record;
  final bool selected;
  final VoidCallback onTap;

  const _RecordTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  String _timeLabel() {
    final t = record.timestamp;
    if (t == null) return '';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (record.kind == RecordKind.crash && record.severity != null)
                    SeverityBadge(severity: record.severity!)
                  else if (record.kind == RecordKind.apiError)
                    StatusCodeBadge(statusCode: record.statusCode)
                  else
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'UNPARSED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (_timeLabel().isNotEmpty)
                    Text(
                      _timeLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  const Spacer(),
                  if (record.kind == RecordKind.apiError && record.method != null)
                    Text(
                      record.method!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                record.kind == RecordKind.crash
                    ? (record.message ?? record.type ?? '(no message)')
                    : record.kind == RecordKind.apiError
                        ? (record.url ?? '(no url)')
                        : record.raw.split('\n').first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (record.kind == RecordKind.crash && record.source != null) ...[
                const SizedBox(height: 2),
                Text(
                  record.source!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
