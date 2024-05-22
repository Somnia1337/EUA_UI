import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const red = Color.fromRGBO(242, 93, 80, 0.8);

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
  final _emailAddrController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  final _rustResultListener = RustResult.rustSignalStream;

  bool _isLoggedIn = false;
  bool _isLogging = false;
  bool _isPasswordVisible = false;

  String _userEmailAddr = '';

  Color _pickerColor = const Color.fromRGBO(2, 125, 253, 1);

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
        red,
        const Duration(seconds: 2),
      );
      return Future.value(false);
    }
    if (_emailAddrController.text == '') {
      _showSnackBar('😵‍💫"邮箱"是必填字段！', red, const Duration(seconds: 2));
      return Future.value(false);
    }
    if (_passwordController.text == '') {
      _showSnackBar('😵‍💫"授权码"是必填字段！', red, const Duration(seconds: 2));
      return Future.value(false);
    }

    LoginAction(loginAction: true).sendSignalToRust();
    UserProto(
      emailAddr: _emailAddrController.text,
      password: _passwordController.text,
    ).sendSignalToRust();

    final loginResult = (await _rustResultListener.first).message;
    if (loginResult.result) {
      _showSnackBar('🤗登录成功', null, const Duration(seconds: 1));
      setState(() {
        _userEmailAddr = _emailAddrController.text;
        SettingsPage.userEmailAddr = _userEmailAddr;
      });
      return true;
    }
    _showSnackBar(
      '😥登录失败: ${loginResult.info}',
      red,
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
      red,
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
                setState(() {
                  _pickerColor = color;
                });
                if (widget.onColorChanged != null) {
                  widget.onColorChanged!(seedColor: color);
                }
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
              child: Text(
                '重置',
                style: TextStyle(color: _pickerColor),
              ),
              onPressed: () {
                setState(() {
                  _pickerColor = const Color.fromRGBO(2, 125, 253, 1);
                });
                if (widget.onColorChanged != null) {
                  widget.onColorChanged!(seedColor: _pickerColor);
                }
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                '完成',
                style: TextStyle(color: _pickerColor),
              ),
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

  Future<void> _launchUrl() async {
    final url = Uri.parse('https://github.com/Somnia1337/EUA_UI');
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final currentBrightness = Theme.of(context).brightness;

    const sizedBox = SizedBox(height: 12);

    final inputFields = Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: TextFormField(
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
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: TextFormField(
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
          ),
        ),
      ],
    );

    final welcome = Text(
      '欢迎 👋 $_userEmailAddr',
      style: const TextStyle(
        fontSize: 20,
      ),
    );

    final logAndTheme = Row(
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
        const SizedBox(width: 20),
        IconButton(
          icon:
              Icon(!_isLoggedIn ? Icons.login_outlined : Icons.logout_outlined),
          tooltip: _isLoggedIn ? '退出登录' : '登录',
          onPressed: !_isLogging ? _triggerLoginOrLogout : null,
          splashRadius: 20,
        ),
        const SizedBox(width: 20),
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
        Text(
          '卢剑歌 2022141461145',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'DingTalk',
          ),
        ),
        SizedBox(
          height: 8,
        ),
        Text(
          'Built with',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'DingTalk',
          ),
        ),
        Text(
          '🎯Dart, 🦀Rust & 🩷Love.',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'DingTalk',
          ),
        ),
        SizedBox(
          height: 8,
        ),
        Text(
          'v0.5.6',
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'JetbrainsMONO',
          ),
        ),
      ],
    );

    final githubImage = InkWell(
      onTap: _launchUrl,
      child: Image.asset(
        currentBrightness == Brightness.light
            ? 'packages/eua_ui/images/github-mark.png'
            : 'packages/eua_ui/images/github-mark-white.png',
        width: 50,
      ),
    );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoggedIn ? welcome : inputFields,
            sizedBox,
            logAndTheme,
            sizedBox,
            info,
            sizedBox,
            githubImage,
          ],
        ),
      ),
    );
  }
}
