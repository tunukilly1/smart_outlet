import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/theme.dart';
import 'screens/splash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SmartOutlet());
}

class SmartOutlet extends StatefulWidget {
  const SmartOutlet({super.key});

  // Static method so any screen can call SmartOutlet.restartApp(context)
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_SmartOutletAppState>()?.restartApp();
  }
    static ThemeProvider
    themeProvider(BuildContext context){
    return context
        .findAncestorStateOfType<_SmartOutletAppState>()!
        ._themeProvider;
    }


  @override
  State<SmartOutlet> createState() => _SmartOutletAppState();
}

class _SmartOutletAppState extends State<SmartOutlet> {
  late final ThemeProvider _themeProvider = ThemeProvider();
  Key _appKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    setState(() {});
  }

  void restartApp() {
    setState(() => _appKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, child) {
        return MaterialApp(
          key: _appKey,
          title: 'SmartOutlet',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeProvider.isLight? ThemeMode.light : ThemeMode.dark,
          home: const SplashScreen(),
        );
      },
    );
  }
}
