import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/backup.dart';
import 'services/file_storage.dart';
import 'state/app_data.dart';
import 'state/settings_data.dart';
import 'state/stopwatch_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_background.dart';
import 'widgets/status_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackupService().ensureBackup();
  final data = AppData(FileStorage());
  await data.load();
  final settings = SettingsData(FileStorage(fileName: 'settings.json'));
  await settings.load();
  runApp(SixAmApp(data: data, settings: settings));
}

class SixAmApp extends StatelessWidget {
  const SixAmApp({super.key, required this.data, required this.settings});

  final AppData data;
  final SettingsData settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppData>.value(value: data),
        ChangeNotifierProvider<SettingsData>.value(value: settings),
        ChangeNotifierProvider<StopwatchController>(
          create: (_) => StopwatchController(data),
        ),
      ],
      child: Consumer<SettingsData>(
        builder: (context, settings, _) => MaterialApp(
          title: '6AM',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(settings),
          builder: (context, child) =>
              AppBackground(child: child ?? const SizedBox.shrink()),
          home: const StatusSync(child: HomeScreen()),
        ),
      ),
    );
  }
}
