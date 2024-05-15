import 'package:flutter/material.dart';
import './messages/generated.dart';
import 'package:eua_ui/compose.dart';
import 'package:eua_ui/inbox.dart';
import 'package:eua_ui/settings.dart';

void main() async {
  await initializeRust();
  runApp(const MyApp());
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

  final _seedColor = const Color.fromRGBO(56, 132, 255, 1);

  late final ThemeData _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    useMaterial3: false,
  );

  late final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: false,
  );

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

  void _toggleDarkMode(bool isOn) {
    setState(() {
      _isDarkMode = isOn;
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
                _seedColor.red,
                _seedColor.green,
                _seedColor.blue,
                0.1,
              ),
              selectedLabelTextStyle: TextStyle(
                fontSize: 16,
                color: _seedColor,
              ),
              leading: const Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text('谐声收藏家',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DingTalk',
                        )),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                    child: Text('你的 📧 用户代理',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DingTalk',
                        )),
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
                  label: const Text('写信'),
                  disabled: !_isLoggedIn,
                ),
                NavigationRailDestination(
                  icon: const Icon(
                    Icons.inbox_outlined,
                    size: 30,
                  ),
                  selectedIcon: const Icon(
                    Icons.inbox,
                    size: 50,
                  ),
                  label: const Text('收信'),
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
                  label: Text('设置'),
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
                    onLoginStatusChanged: _loginStatusChanged,
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
