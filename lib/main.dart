import 'package:eua_ui/compose.dart';
import 'package:eua_ui/inbox.dart';
import 'package:eua_ui/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './messages/generated.dart';

void main() async {
  await initializeRust();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginStatusNotifier()),
        ChangeNotifierProvider(create: (_) => ColorChangeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class LoginStatusNotifier extends ChangeNotifier {
  bool isLoggedIn = false;

  void updateLoginStatus({required bool isLoggedIn}) {
    this.isLoggedIn = isLoggedIn;
    notifyListeners();
  }
}

class ColorChangeNotifier extends ChangeNotifier {
  Color seedColor = const Color.fromRGBO(0, 0, 0, 1);

  void updateColor({required Color seedColor}) {
    this.seedColor = seedColor;
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 2;

  bool _isLoggedIn = false;
  bool _isDarkMode = false;

  Color seedColor = const Color.fromRGBO(56, 132, 255, 1);

  late ThemeData _lightTheme;
  late ThemeData _darkTheme;

  @override
  void initState() {
    super.initState();
    _rebuildThemes();
  }

  void _rebuildThemes() {
    _lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        primary: seedColor,
      ),
      useMaterial3: false,
    );

    _darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: false,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      if (_isLoggedIn) {
        _selectedIndex = index;
      } else if (index != 2) {
        _showSnackBar('请先登录!');
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _loginStatusChanged(bool isLoggedIn) {
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  void _colorChanged(Color seedColor) {
    setState(() {
      this.seedColor = seedColor;
      _rebuildThemes();
    });
  }

  void _toggleDarkMode({required bool isDarkMode}) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Color.fromRGBO(
                seedColor.red,
                seedColor.green,
                seedColor.blue,
                0.1,
              ),
              selectedLabelTextStyle: TextStyle(
                fontSize: 16,
                color: seedColor,
              ),
              leading: const Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      '谐声收藏家',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DingTalk',
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                    child: Text(
                      '你的 📧 用户代理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DingTalk',
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(
                    Icons.email_outlined,
                    size: 30,
                  ),
                  selectedIcon: const Icon(
                    Icons.email,
                    size: 50,
                  ),
                  label: const Text(
                    '写邮件',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  disabled: !_isLoggedIn,
                ),
                NavigationRailDestination(
                  icon: const Icon(
                    Icons.markunread_mailbox_outlined,
                    size: 30,
                  ),
                  selectedIcon: const Icon(
                    Icons.markunread_mailbox,
                    size: 50,
                  ),
                  label: const Text(
                    '收件箱',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  disabled: !_isLoggedIn,
                ),
                const NavigationRailDestination(
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 30,
                  ),
                  selectedIcon: Icon(
                    Icons.settings,
                    size: 50,
                  ),
                  indicatorShape: LinearBorder.none,
                  label: Text(
                    '设置',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  const ComposePage(),
                  const InboxPage(),
                  SettingsPage(
                    onLoginStatusChanged: ({required bool isLoggedIn}) {
                      Provider.of<LoginStatusNotifier>(context, listen: false)
                          .updateLoginStatus(isLoggedIn: isLoggedIn);
                      _loginStatusChanged(isLoggedIn);
                    },
                    onColorChanged: ({required Color seedColor}) {
                      Provider.of<ColorChangeNotifier>(context, listen: false)
                          .updateColor(seedColor: seedColor);
                      _colorChanged(seedColor);
                    },
                    onToggleDarkMode: _toggleDarkMode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      theme: _isDarkMode ? _darkTheme : _lightTheme,
    );
  }
}
