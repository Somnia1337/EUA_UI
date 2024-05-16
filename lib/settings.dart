import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final void Function(bool)? onLoginStatusChanged;
  final void Function(bool)? onLoggingProcessChanged;
  final void Function(bool)? onToggleDarkMode;

  const SettingsPage({
    super.key,
    this.onLoginStatusChanged,
    this.onLoggingProcessChanged,
    this.onToggleDarkMode,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _emailAddrController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  final _rustResultListener = RustResult.rustSignalStream;

  String _userEmailAddr = "";

  bool _isLoggedIn = false;
  bool _isLoggingInOrOut = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailAddrController.dispose();
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _triggerLoginOrLogout() async {
    setState(() {
      _isLoggingInOrOut = true;
    });
    if (widget.onLoggingProcessChanged != null) {
      widget.onLoggingProcessChanged!(true);
    }
    if (!_isLoggedIn) {
      bool loginResult = await login();
      if (loginResult) {
        setState(() {
          _isLoggedIn = true;
        });
        if (widget.onLoginStatusChanged != null) {
          widget.onLoginStatusChanged!(true);
        }
        _passwordController.clear();
      } else {
        setState(() {
          _isLoggedIn = false;
        });
        if (widget.onLoginStatusChanged != null) {
          widget.onLoginStatusChanged!(false);
        }
      }
    } else {
      _logoutDialog(context);
    }
    setState(() {
      _isLoggingInOrOut = false;
    });
    if (widget.onLoggingProcessChanged != null) {
      widget.onLoggingProcessChanged!(false);
    }
  }

  Future<bool> login() async {
    if (_emailAddrController.text == "") {
      _showSnackBar('❗"邮箱"是必填字段！', Colors.red, const Duration(seconds: 2));
      return Future.value(false);
    }
    if (_passwordController.text == "") {
      _showSnackBar('❗"授权码"是必填字段！', Colors.red, const Duration(seconds: 2));
      return Future.value(false);
    }

    pb.Action(action: 0).sendSignalToRust();
    UserProto(
            emailAddr: _emailAddrController.text,
            password: _passwordController.text)
        .sendSignalToRust();
    _userEmailAddr = _emailAddrController.text;

    RustResult loginResult = (await _rustResultListener.first).message;
    if (loginResult.result) {
      _showSnackBar('🤗登录成功', Colors.green, const Duration(seconds: 2));
      return true;
    }
    _showSnackBar(
        '❌登录失败：${loginResult.info}', Colors.red, const Duration(seconds: 5));
    return false;
  }

  Future<bool> logout() async {
    pb.Action(action: 1).sendSignalToRust();
    RustResult logoutResult = (await _rustResultListener.first).message;
    if (logoutResult.result) {
      _showSnackBar('😶‍🌫️已退出登录', Colors.green, const Duration(seconds: 2));
      return true;
    }
    return false;
  }

  void _logoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("提示"),
          content: const Text("确定要退出登录吗？"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("取消"),
            ),
            TextButton(
                onPressed: () async {
                  if (await logout()) {
                    setState(() {
                      _isLoggedIn = false;
                    });
                    if (widget.onLoginStatusChanged != null) {
                      widget.onLoginStatusChanged!(false);
                    }
                  }
                  Navigator.of(context).pop();
                },
                child: const Text("确定")),
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
          style: TextStyle(color: color, fontSize: 16),
        ),
        duration: duration,
      ),
    );
  }

  void _launchUrl() async {
    final url = Uri.parse('https://github.com/Somnia1337/EUA_UI');
    await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    Brightness currentBrightness = Theme.of(context).brightness;

    const sizedBoxBig = SizedBox(height: 20);
    const sizedBoxSmall = SizedBox(height: 12);

    const textStyle = TextStyle(
      fontSize: 18,
    );

    final logControlButton = IconButton(
      onPressed: !_isLoggingInOrOut ? _triggerLoginOrLogout : null,
      tooltip: _isLoggedIn ? '退出登录' : '登录',
      icon: Icon(!_isLoggedIn ? Icons.login_outlined : Icons.logout_outlined),
    );

    final toggleDarkModeButton = SizedBox(
      width: 240,
      child: SwitchListTile(
        title: const Text('深色模式'),
        secondary: Icon(
          currentBrightness == Brightness.light
              ? Icons.wb_sunny_outlined
              : Icons.nightlight_round_outlined,
        ),
        value: (currentBrightness == Brightness.dark),
        onChanged: (value) {
          if (widget.onToggleDarkMode != null) {
            widget.onToggleDarkMode!(value);
          }
        },
      ),
    );

    const info = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Text('卢剑歌 2022141461145',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'DingTalk',
              )),
        ),
        Padding(
          padding: EdgeInsets.all(0),
          child: Text('v0.3.2',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Consolas',
              )),
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
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(0),
                          child:
                              Text('欢迎 👋 $_userEmailAddr', style: textStyle),
                        ),
                        sizedBoxSmall,
                        logControlButton,
                        sizedBoxBig,
                        toggleDarkModeButton,
                        sizedBoxSmall,
                        info,
                        sizedBoxSmall,
                        githubImage,
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: TextFormField(
                            controller: _emailAddrController,
                            decoration: const InputDecoration(
                              labelText: '邮箱',
                              border: UnderlineInputBorder(),
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
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              focusNode: _passwordFocusNode,
                              decoration: InputDecoration(
                                labelText: '授权码 (不是邮箱密码!!)',
                                border: const UnderlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                              onEditingComplete: () {
                                _triggerLoginOrLogout();
                              }),
                        ),
                        sizedBoxSmall,
                        logControlButton,
                        sizedBoxBig,
                        toggleDarkModeButton,
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
