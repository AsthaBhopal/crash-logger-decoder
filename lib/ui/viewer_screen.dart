import 'package:flutter/material.dart';

import '../parsing/log_record.dart';
import 'app_state.dart';
import 'widgets/closable_tabs.dart';
import 'widgets/detail_panel.dart';
import 'widgets/record_list.dart';

class ViewerScreen extends StatelessWidget {
  final AppState appState;
  const ViewerScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeFile = appState.activeFile;
    final records = activeFile != null
        ? appState.filteredRecords(activeFile.records)
        : <LogRecord>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crash Log Decoder'),
        actions: [
          TextButton.icon(
            onPressed: appState.clearKey,
            icon: const Icon(Icons.key_off_outlined, size: 18),
            label: const Text('Change key'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          ClosableTabs(
            tabs: appState.decodedFiles
                .where((f) => appState.openTabs.contains(f.fileName))
                .map((f) => TabSpec(
                      id: f.fileName,
                      label: _tabLabel(f.fileName),
                      count: f.records.length,
                    ))
                .toList(),
            activeId: appState.activeTab,
            closedTabLabels: appState.closedTabs,
            onSelect: appState.selectTab,
            onClose: appState.closeTab,
            onReopen: appState.reopenTab,
            onOpenAnother: appState.openAnotherFile,
          ),
          const Divider(height: 1),
          Expanded(
            child: appState.openTabs.isEmpty
                ? Center(
                    child: Text(
                      'All tabs closed — use the reopen menu or open another file.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;
                      final listPane = _ListPane(
                        appState: appState,
                        records: records,
                      );
                      final detailPane = Container(
                        color: theme.colorScheme.surface,
                        child: DetailPanel(record: appState.selectedRecord),
                      );

                      if (wide) {
                        return Row(
                          children: [
                            SizedBox(width: 380, child: listPane),
                            const VerticalDivider(width: 1),
                            Expanded(child: detailPane),
                          ],
                        );
                      }

                      if (appState.selectedRecord != null) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => appState.selectRecord(null),
                                  icon: const Icon(Icons.arrow_back, size: 16),
                                  label: const Text('Back to list'),
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(child: detailPane),
                          ],
                        );
                      }
                      return listPane;
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(String fileName) {
    final m = RegExp(r'^crashes_(api|bloc|ui)_(\d{4}-\d{2}-\d{2})\.txt$')
        .firstMatch(fileName);
    if (m == null) return fileName;
    return '${m.group(1)} · ${m.group(2)}';
  }
}

class _ListPane extends StatelessWidget {
  final AppState appState;
  final List<LogRecord> records;
  const _ListPane({required this.appState, required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: appState.setSearch,
                  decoration: InputDecoration(
                    hintText: 'Search message, source, URL, stack…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: CrashSeverity.values.map((s) {
                    final selected = appState.severityFilter.contains(s);
                    return FilterChip(
                      label: Text(s.name.toUpperCase()),
                      labelStyle: const TextStyle(fontSize: 11),
                      visualDensity: VisualDensity.compact,
                      selected: selected,
                      onSelected: (_) => appState.toggleSeverity(s),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RecordList(
              records: records,
              selected: appState.selectedRecord,
              onSelect: appState.selectRecord,
            ),
          ),
        ],
      ),
    );
  }
}
