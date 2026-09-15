import 'package:flutter/material.dart';

class TabSpec {
  final String id;
  final String label;
  final int count;
  const TabSpec({required this.id, required this.label, required this.count});
}

/// A browser-style tab strip: each tab has its own close (x) button, and
/// closed tabs are recoverable via the trailing "reopen" menu. Flutter's
/// built-in TabBar has no per-tab close affordance, hence this custom strip.
class ClosableTabs extends StatelessWidget {
  final List<TabSpec> tabs;
  final String? activeId;
  final List<String> closedTabLabels;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final ValueChanged<String> onReopen;
  final VoidCallback onOpenAnother;

  const ClosableTabs({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.closedTabLabels,
    required this.onSelect,
    required this.onClose,
    required this.onReopen,
    required this.onOpenAnother,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((tab) {
                  final active = tab.id == activeId;
                  return _TabChip(
                    tab: tab,
                    active: active,
                    onSelect: () => onSelect(tab.id),
                    onClose: () => onClose(tab.id),
                  );
                }).toList(),
              ),
            ),
          ),
          if (closedTabLabels.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Reopen closed tab',
              icon: const Icon(Icons.history, size: 20),
              onSelected: onReopen,
              itemBuilder: (context) => closedTabLabels
                  .map((label) => PopupMenuItem(value: label, child: Text(label)))
                  .toList(),
            ),
          IconButton(
            tooltip: 'Open a different archive',
            onPressed: onOpenAnother,
            icon: const Icon(Icons.drive_folder_upload_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  final TabSpec tab;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.active;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          margin: const EdgeInsets.only(top: 8, right: 4),
          padding: const EdgeInsets.only(left: 14, right: 6, top: 9, bottom: 9),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(
              bottom: BorderSide(
                color: active ? theme.colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.tab.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.tab.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 22,
                height: 22,
                child: _hovering || active
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: widget.onClose,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
