import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/history_store.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsStore();
  await settings.load();
  final history = HistoryStore();
  await history.load();
  runApp(IWantFigureApp(settings: settings, history: history));
}
