import 'package:flutter/material.dart';
import 'api_client.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(const ControlFinancieroApp());
}

class ControlFinancieroApp extends StatefulWidget {
  const ControlFinancieroApp({super.key});

  @override
  State<ControlFinancieroApp> createState() => _ControlFinancieroAppState();
}

class _ControlFinancieroAppState extends State<ControlFinancieroApp> {
  final ApiClient api = ApiClient();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    api.loadToken().then((_) => setState(() => _loading = false));
  }

  @override
  Widget build(BuildContext context) {
    // Neutral dark palette matching the web app's slate background + near-
    // white primary accents (see globals.css / manifest.json background_color).
    const background = Color(0xFF0F172A);
    const surface = Color(0xFF1E293B);
    const primary = Color(0xFFF1F5F9);

    return MaterialApp(
      title: 'Mi Planificador Financiero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          surface: surface,
          primary: primary,
          onPrimary: background,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: background,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (api.isLoggedIn ? MainShell(api: api) : LoginScreen(api: api)),
    );
  }
}
