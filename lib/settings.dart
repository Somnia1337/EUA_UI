import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ColorChangeNotifier extends ChangeNotifier {
  late Color seedColor;

  void updateColor({required Color seedColor}) {
    this.seedColor = seedColor;
    notifyListeners();
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.onLoginStatusChanged,
    this.onColorChanged,
    this.onLoggingProcessChanged,
    this.onToggleDarkMode,
  });

  static String userEmailAddr = '';

  final void Function({required bool isLoggedIn})? onLoginStatusChanged;
  final void Function({required Color seedColor})? onColorChanged;
  final void Function({required bool isLogging})? onLoggingProcessChanged;
  final void Function({required bool isDarkMode})? onToggleDarkMode;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String userEmailAddr = '';

  bool _isLoggedIn = false;
  bool _isLogging = false;
  bool _isPasswordVisible = false;
  final _yellow = const Color.fromRGBO(211, 211, 80, 0.8);
  final _red = const Color.fromRGBO(233, 95, 89, 0.8);
  Color _pickerColor = const Color.fromRGBO(56, 132, 255, 1);

  final _emailAddrController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  final _rustResultListener = RustResult.rustSignalStream;

  @override
  void dispose() {
    _emailAddrController.dispose();
    _passwordFocusNode.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _triggerLoginOrLogout() async {
    setState(() {
      _isLogging = true;
    });
    if (widget.onLoggingProcessChanged != null) {
      widget.onLoggingProcessChanged!(isLogging: true);
    }

    if (!_isLoggedIn) {
      final loginResult = await login();
      if (loginResult) {
        setState(() {
          _isLoggedIn = true;
        });
        if (widget.onLoginStatusChanged != null) {
          widget.onLoginStatusChanged!(isLoggedIn: true);
        }
        _passwordController.clear();
      } else {
        setState(() {
          _isLoggedIn = false;
        });
        if (widget.onLoginStatusChanged != null) {
          widget.onLoginStatusChanged!(isLoggedIn: false);
        }
      }
    } else {
      if (await _showLogoutDialog(context) && await logout()) {
        setState(() {
          _isLoggedIn = false;
        });
        if (widget.onLoginStatusChanged != null) {
          widget.onLoginStatusChanged!(isLoggedIn: false);
        }
      }
    }

    setState(() {
      _isLogging = false;
    });
    if (widget.onLoggingProcessChanged != null) {
      widget.onLoggingProcessChanged!(isLogging: false);
    }
  }

  Future<bool> login() async {
    if (_emailAddrController.text == '' && _passwordController.text == '') {
      _showSnackBar(
        '😵‍💫"邮箱"和"授权码"是必填字段！',
        _yellow,
        const Duration(seconds: 2),
      );
      return Future.value(false);
    }
    if (_emailAddrController.text == '') {
      _showSnackBar('😵‍💫"邮箱"是必填字段！', _yellow, const Duration(seconds: 2));
      return Future.value(false);
    }
    if (_passwordController.text == '') {
      _showSnackBar('😵‍💫"授权码"是必填字段！', _yellow, const Duration(seconds: 2));
      return Future.value(false);
    }

    pb.Action(action: 0).sendSignalToRust();
    UserProto(
      emailAddr: _emailAddrController.text,
      password: _passwordController.text,
    ).sendSignalToRust();

    final loginResult = (await _rustResultListener.first).message;
    if (loginResult.result) {
      _showSnackBar('🤗登录成功', null, const Duration(seconds: 1));
      setState(() {
        userEmailAddr = _emailAddrController.text;
        SettingsPage.userEmailAddr = userEmailAddr;
      });
      return true;
    }
    _showSnackBar(
      '😥登录失败: ${loginResult.info}',
      _red,
      const Duration(seconds: 3),
    );
    return false;
  }

  Future<bool> logout() async {
    pb.Action(action: 1).sendSignalToRust();
    final logoutResult = (await _rustResultListener.first).message;
    if (logoutResult.result) {
      _showSnackBar('🫥已退出登录', null, const Duration(seconds: 1));
      return true;
    }
    _showSnackBar(
      '😥退出登录失败: ${logoutResult.info}',
      _red,
      const Duration(seconds: 3),
    );
    return false;
  }

  void _showColorPickerDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300, maxWidth: 300),
            child: ColorPicker(
              color: _pickerColor,
              onColorChanged: (color) {
                if (widget.onColorChanged != null) {
                  widget.onColorChanged!(seedColor: color);
                }
                setState(() {
                  _pickerColor = color;
                });
              },
              borderRadius: 30,
              spacing: 8,
              runSpacing: 8,
              wheelDiameter: 130,
              wheelWidth: 12,
              wheelSquareBorderRadius: 5,
              heading: Text(
                '选择颜色',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              selectedPickerTypeColor: Theme.of(context).colorScheme.primary,
              pickersEnabled: const <ColorPickerType, bool>{
                ColorPickerType.both: false,
                ColorPickerType.primary: false,
                ColorPickerType.accent: false,
                ColorPickerType.bw: false,
                ColorPickerType.custom: false,
                ColorPickerType.wheel: true,
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('重置'),
              onPressed: () {
                setState(() {
                  _pickerColor = const Color.fromRGBO(56, 132, 255, 1);
                  if (widget.onColorChanged != null) {
                    widget.onColorChanged!(seedColor: _pickerColor);
                  }
                });
              },
            ),
            TextButton(
              child: const Text('完成'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showLogoutDialog(BuildContext context) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('确定要退出登录吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    return confirmation ?? false;
  }

  void _showSnackBar(String message, Color? color, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        duration: duration,
      ),
    );
  }

  Future<void> _launchUrl(String desc) async {
    final uri = switch (desc) {
      'Github' => 'https://github.com/Somnia1337/EUA_UI',
      'Flutter' => 'https://flutter.dev',
      'Rust' => 'https://www.rust-lang.org/',
      _ => '',
    };
    final url = Uri.parse(uri);
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final currentBrightness = Theme.of(context).brightness;

    const sizedBoxBig = SizedBox(height: 20);
    const sizedBoxSmall = SizedBox(height: 12);

    final emailAddrInputField = TextFormField(
      controller: _emailAddrController,
      decoration: InputDecoration(
        labelText: '邮箱',
        border: const UnderlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear_rounded),
          splashRadius: 20,
          onPressed: () {
            _emailAddrController.clear();
            _passwordController.clear();
          },
        ),
      ),
      keyboardType: TextInputType.emailAddress,
      onFieldSubmitted: (value) {
        FocusScope.of(context).requestFocus(_passwordFocusNode);
      },
    );
    final passwordInputField = TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      focusNode: _passwordFocusNode,
      decoration: InputDecoration(
        labelText: '授权码 (不是邮箱密码!!)',
        border: const UnderlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          splashRadius: 20,
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
      onEditingComplete: _triggerLoginOrLogout,
    );

    final welcome = Padding(
      padding: EdgeInsets.zero,
      child: Text(
        '欢迎 👋 $userEmailAddr',
        style: const TextStyle(
          fontSize: 20,
        ),
      ),
    );

    final logControlButton = IconButton(
      icon: Icon(!_isLoggedIn ? Icons.login_outlined : Icons.logout_outlined),
      tooltip: _isLoggedIn ? '退出登录' : '登录',
      onPressed: !_isLogging ? _triggerLoginOrLogout : null,
      splashRadius: 20,
    );

    final customizations = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              if (widget.onToggleDarkMode != null) {
                widget.onToggleDarkMode!(
                  isDarkMode: currentBrightness == Brightness.light,
                );
              }
            });
          },
          tooltip: currentBrightness == Brightness.light ? '浅色模式' : '深色模式',
          splashRadius: 20,
          icon: Icon(
            currentBrightness == Brightness.light
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_outlined,
          ),
        ),
        IconButton(
          onPressed: _showColorPickerDialog,
          tooltip: '颜色',
          splashRadius: 20,
          icon: Icon(
            Icons.color_lens_outlined,
            color: _pickerColor,
          ),
        ),
      ],
    );

    const info = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Text(
            '卢剑歌 2022141461145',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'DingTalk',
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.zero,
          child: Text(
            'v0.5.1',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Consolas',
            ),
          ),
        ),
      ],
    );

    final githubImage = InkWell(
      onTap: () {
        _launchUrl('Github');
      },
      child: Image.asset(
        currentBrightness == Brightness.light
            ? 'packages/eua_ui/images/github-mark.png'
            : 'packages/eua_ui/images/github-mark-white.png',
        width: 40,
        height: 40,
      ),
    );
    final flutterImage = InkWell(
      onTap: () {
        _launchUrl('Flutter');
      },
      child: Image.asset(
        'packages/eua_ui/images/Flutter.png',
        width: 30,
      ),
    );
    final rustImage = InkWell(
      onTap: () {
        _launchUrl('Rust');
      },
      child: Image.asset(
        currentBrightness == Brightness.light
            ? 'packages/eua_ui/images/Rust.png'
            : 'packages/eua_ui/images/Rust-white.png',
        width: 37,
      ),
    );
    final gallery = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        flutterImage,
        const SizedBox(
          width: 20,
        ),
        rustImage,
      ],
    );

    final customizationsAndInfo = Column(
      children: [
        logControlButton,
        sizedBoxBig,
        customizations,
        sizedBoxSmall,
        info,
        sizedBoxSmall,
        githubImage,
        sizedBoxSmall,
        gallery,
      ],
    );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoggedIn
                ? Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        welcome,
                        sizedBoxSmall,
                        customizationsAndInfo,
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: emailAddrInputField,
                        ),
                        sizedBoxSmall,
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: passwordInputField,
                        ),
                        sizedBoxSmall,
                        customizationsAndInfo,
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
