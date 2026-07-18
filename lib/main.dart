import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/network/api_client.dart';
import 'core/network/api_client_provider.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  await apiClient.init();

  runApp(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    // Restore session once the widget tree (and providers) are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    _router ??= buildRouter(auth);

    if (auth.initializing) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    return MaterialApp.router(
      title: 'Mom Masale Admin',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF7B1120), useMaterial3: true),
      routerConfig: _router,
    );
  }
}