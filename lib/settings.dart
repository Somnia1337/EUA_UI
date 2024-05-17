import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.onLoginStatusChanged,
    this.onColorChanged,
    this.onLoggingProcessChanged,
    this.onToggleDarkMode,
  });
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

  final green = const Color.fromRGBO(66, 184, 131, 0.8);
  final red = const Color.fromRGBO(233, 95, 89, 0.8);

  String _userEmailAddr = '';

  bool _isLoggedIn = false;
  bool _isLogging = false;
  bool _isPasswordVisible = false;

  Color _pickerColor = const Color.fromRGBO(56, 132, 255, 1);

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
      _logoutDialog(context);
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
      _showSnackBar('❗"邮箱"和"授权码"是必填字段！', red, const Duration(seconds: 3));
      return Future.value(false);
    }
    if (_emailAddrController.text == '') {
      _showSnackBar('❗"邮箱"是必填字段！', red, const Duration(seconds: 3));
      return Future.value(false);
    }
    if (_passwordController.text == '') {
      _showSnackBar('❗"授权码"是必填字段！', red, const Duration(seconds: 3));
      return Future.value(false);
    }

    pb.Action(action: 0).sendSignalToRust();
    UserProto(
      emailAddr: _emailAddrController.text,
      password: _passwordController.text,
    ).sendSignalToRust();
    _userEmailAddr = _emailAddrController.text;

    final loginResult = (await _rustResultListener.first).message;
    if (loginResult.result) {
      _showSnackBar('🤗登录成功', green, const Duration(seconds: 1));
      return true;
    }
    _showSnackBar('❌登录失败：${loginResult.info}', red, const Duration(seconds: 3));
    return false;
  }

  Future<bool> logout() async {
    pb.Action(action: 1).sendSignalToRust();
    final logoutResult = (await _rustResultListener.first).message;
    if (logoutResult.result) {
      _showSnackBar('😶‍🌫️已退出登录', green, const Duration(seconds: 1));
      return true;
    }
    return false;
  }

  void _showColorPickerDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: ColorPicker(
            pickerColor: _pickerColor,
            onColorChanged: (color) {
              if (widget.onColorChanged != null) {
                widget.onColorChanged!(seedColor: color);
              }
              setState(() {
                _pickerColor = color;
              });
            },
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

  void _logoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final localContext = context;
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('确定要退出登录吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (await logout()) {
                  setState(() {
                    _isLoggedIn = false;
                  });
                  if (widget.onLoginStatusChanged != null) {
                    widget.onLoginStatusChanged!(isLoggedIn: false);
                  }
                }
                if (!localContext.mounted) {
                  return;
                }
                Navigator.of(localContext).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color, Duration duration) {
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

    const sizedBoxBig = SizedBox(height: 20);
    const sizedBoxSmall = SizedBox(height: 12);

    const textStyle = TextStyle(
      fontSize: 18,
    );

    final logControlButton = IconButton(
      onPressed: !_isLogging ? _triggerLoginOrLogout : null,
      tooltip: _isLoggedIn ? '退出登录' : '登录',
      icon: Icon(!_isLoggedIn ? Icons.login_outlined : Icons.logout_outlined),
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
                : Icons.nightlight_round_outlined,
          ),
        ),
        IconButton(
          onPressed: _showColorPickerDialog,
          tooltip: '颜色',
          splashRadius: 20,
          icon: const Icon(Icons.color_lens_outlined),
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
            'v0.4.4',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Consolas',
            ),
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
        height: 50,
      ),
    );

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _isLoggedIn
                ? Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.zero,
                          child:
                              Text('欢迎 👋 $_userEmailAddr', style: textStyle),
                        ),
                        sizedBoxSmall,
                        logControlButton,
                        sizedBoxBig,
                        customizations,
                        sizedBoxSmall,
                        info,
                        sizedBoxSmall,
                        githubImage,
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
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
                              FocusScope.of(context)
                                  .requestFocus(_passwordFocusNode);
                            },
                          ),
                        ),
                        sizedBoxSmall,
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
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
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
                        sizedBoxSmall,
                        logControlButton,
                        sizedBoxBig,
                        customizations,
                        sizedBoxSmall,
                        info,
                        sizedBoxSmall,
                        githubImage,
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class ColorChangeNotifier extends ChangeNotifier {
  late Color seedColor;

  void updateColor({required Color seedColor}) {
    this.seedColor = seedColor;
    notifyListeners();
  }
}
