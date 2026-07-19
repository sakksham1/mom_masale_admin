import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the user's preferred theme mode. Defaults to following the phone's
/// system setting (light/dark). If you later want a manual toggle in
/// Settings, just do `ref.read(themeModeProvider.notifier).state = ThemeMode.dark;`
/// To persist the choice across restarts, back this with shared_preferences.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
