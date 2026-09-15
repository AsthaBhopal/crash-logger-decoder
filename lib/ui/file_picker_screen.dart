import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';

class FilePickerScreen extends StatelessWidget {
  final AppState appState;
  const FilePickerScreen({super.key, required this.appState});

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;
    await appState.decodeFile(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = appState.decodeErrorText;

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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: appState.isDecoding ? null : () => _pickFile(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        width: 1.4,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (appState.isDecoding)
                          const SizedBox(
                            height: 40,
                            width: 40,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.upload_file_outlined,
                              size: 28,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          appState.isDecoding
                              ? 'Decrypting…'
                              : 'Select a crash log file',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appState.isDecoding
                              ? 'Decrypting and unpacking the archive'
                              : 'flow_crash_logs_*.enc — or any renamed copy of it',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!appState.isDecoding)
                          FilledButton.tonalIcon(
                            onPressed: () => _pickFile(context),
                            icon: const Icon(Icons.folder_open_outlined, size: 18),
                            label: const Text('Browse files…'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
