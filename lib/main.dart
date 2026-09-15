import 'package:flutter/material.dart';

import 'ui/app_state.dart';
import 'ui/key_entry_screen.dart';
import 'ui/file_picker_screen.dart';
import 'ui/viewer_screen.dart';

void main() {
  runApp(const CrashLogDecoderApp());
}

class CrashLogDecoderApp extends StatefulWidget {
  const CrashLogDecoderApp({super.key});

  @override
  State<CrashLogDecoderApp> createState() => _CrashLogDecoderAppState();
}

class _CrashLogDecoderAppState extends State<CrashLogDecoderApp> {
  final AppState appState = AppState();

  static const _seed = Color(0xFF4F5BD5);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crash Log Decoder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          switch (appState.screen) {
            case AppScreen.keyEntry:
              return KeyEntryScreen(appState: appState);
            case AppScreen.filePicker:
              return FilePickerScreen(appState: appState);
            case AppScreen.viewer:
              return ViewerScreen(appState: appState);
          }
        },
      ),
    );
  }
}
