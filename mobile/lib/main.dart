import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/client_config.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell_screen.dart';

import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load infrastructure outputs from client-config.json
  final config = await ClientConfig.loadFromAsset();

  runApp(
    ProviderScope(
      overrides: [
        clientConfigProvider.overrideWithValue(config),
      ],
      child: GroupNavApp(config: config),
    ),
  );
}

class GroupNavApp extends StatelessWidget {
  final ClientConfig config;

  const GroupNavApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GroupNav',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: MainShellScreen(config: config),
    );
  }
}
