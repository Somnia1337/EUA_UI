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
        ChangeNotifierProvider(create: (_) => SeedColorNotifier()),
      ],
      child: const MainPage(),
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

class SeedColorNotifier extends ChangeNotifier {
  late Color seedColor;

  void updateColor({required Color seedColor}) {
    this.seedColor = seedColor;
    notifyListeners();
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedPageIndex = 2;
  bool _isLoggedIn = false;
  bool _isDarkMode = false;

  Color _seedColor = const Color.fromRGBO(56, 132, 255, 1);
  late ThemeData _lightTheme;
  late ThemeData _darkTheme;

  @override
  void initState() {
    super.initState();

    _buildThemes();
  }

  void _buildThemes() {
    _lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        primary: _seedColor,
      ),
      useMaterial3: false,
    );

    _darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
      useMaterial3: false,
    );
  }

  void _onPageSelected(int pageIndex) {
    setState(() {
      _selectedPageIndex = pageIndex;
    });
  }

  void _onLoginStatusChanged(bool isLoggedIn) {
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
  }

  void _onToggleDarkMode({required bool isDarkMode}) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  void _onSeedColorChanged(Color seedColor) {
    setState(() {
      _seedColor = seedColor;
      _buildThemes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final railBackgroundColor = Color.fromRGBO(
      _seedColor.red,
      _seedColor.green,
      _seedColor.blue,
      0.1,
    );
    final selectedLabelTextStyle = TextStyle(
      fontSize: 18,
      color: _seedColor,
    );

    const headerFont = 'DingTalk';
    const header = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            '谐声收藏家',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: headerFont,
            ),
          ),
        ),
        Text(
          '你的 📧 用户代理',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: headerFont,
          ),
        ),
        SizedBox(
          height: 32,
        ),
      ],
    );

    const destinationIconSizeSmall = 30.0;
    const destinationIconSizeLarge = 50.0;
    final destinations = [
      NavigationRailDestination(
        icon: const Icon(
          Icons.email_outlined,
          size: destinationIconSizeSmall,
        ),
        selectedIcon: const Icon(
          Icons.email,
          size: destinationIconSizeLarge,
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
          size: destinationIconSizeSmall,
        ),
        selectedIcon: const Icon(
          Icons.markunread_mailbox,
          size: destinationIconSizeLarge,
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
          size: destinationIconSizeSmall,
        ),
        selectedIcon: Icon(
          Icons.settings,
          size: destinationIconSizeLarge,
        ),
        label: Text(
          '设置',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];

    final pagesStack = IndexedStack(
      index: _selectedPageIndex,
      children: [
        const ComposePage(),
        const InboxPage(),
        SettingsPage(
          onLoginStatusChanged: ({required bool isLoggedIn}) {
            Provider.of<LoginStatusNotifier>(context, listen: false)
                .updateLoginStatus(isLoggedIn: isLoggedIn);
            _onLoginStatusChanged(isLoggedIn);
          },
          onColorChanged: ({required Color seedColor}) {
            Provider.of<SeedColorNotifier>(context, listen: false)
                .updateColor(seedColor: seedColor);
            _onSeedColorChanged(seedColor);
          },
          onToggleDarkMode: _onToggleDarkMode,
        ),
      ],
    );

    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedPageIndex,
              onDestinationSelected: _onPageSelected,
              labelType: NavigationRailLabelType.all,
              backgroundColor: railBackgroundColor,
              selectedLabelTextStyle: selectedLabelTextStyle,
              leading: header,
              destinations: destinations,
            ),
            Expanded(
              child: pagesStack,
            ),
          ],
        ),
      ),
      theme: _isDarkMode ? _darkTheme : _lightTheme,
    );
  }
}
