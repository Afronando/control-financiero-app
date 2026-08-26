import 'package:flutter/material.dart';
import 'api_client.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

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
  final ThemeController themeController = ThemeController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.wait([api.loadToken(), themeController.load()]).then((_) {
      setState(() => _loading = false);
    });
    themeController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Planificador Financiero',
      debugShowCheckedModeBanner: false,
      themeMode: themeController.mode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (api.isLoggedIn
                ? HomeScreen(api: api, themeController: themeController)
                : LoginScreen(api: api, themeController: themeController)),
    );
  }
}
