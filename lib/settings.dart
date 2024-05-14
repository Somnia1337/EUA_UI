import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final void Function(bool)? onLoginStatusChanged;
  final void Function(bool)? onToggleDarkMode;

  const SettingsPage({
    super.key,
    this.onLoginStatusChanged,
    this.onToggleDarkMode,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _emailAddrController = TextEditingController();
  final _passwordController = TextEditingController();

  final _rustResultListener = RustResult.rustSignalStream;

  String _emailAddr = "";

  bool _isLoggedIn = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailAddrController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> login() async {
    if (_emailAddrController.text == "") {
      _showSnackBar('❗"邮箱"是必填字段！', const Duration(seconds: 2));
      return Future.value(false);
    }
    if (_passwordController.text == "") {
      _showSnackBar('❗"授权码"是必填字段！', const Duration(seconds: 2));
      return Future.value(false);
    }
    pb.Action(action: 0).sendSignalToRust();
    UserProto(
            emailAddr: _emailAddrController.text,
            password: _passwordController.text)
        .sendSignalToRust();
    _emailAddr = _emailAddrController.text;
    RustResult loginResult = (await _rustResultListener.first).message;
    if (loginResult.result) {
      _showSnackBar('✅登录成功', const Duration(seconds: 2));
      return true;
    }
    _showSnackBar('❌登录失败：${loginResult.info}', const Duration(seconds: 5));
    return false;
  }

  Future<bool> logout() async {
    pb.Action(action: 1).sendSignalToRust();
    if ((await _rustResultListener.first).message.result) {
      _showSnackBar('✅已退出登录', const Duration(seconds: 2));
      return true;
    } else {
      return false;
    }
  }

  void _showSnackBar(String message, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Brightness currentBrightness = Theme.of(context).brightness;

    const sizedBox = SizedBox(height: 16);

    const textStyle = TextStyle(
      fontSize: 18,
    );

    final toggleDarkModeButton = SizedBox(
      width: 300,
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
                fontFamily: 'Consolas',
              )),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Text('https://github.com/Somnia1337/EUA_UI',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Consolas',
              )),
        ),
        Padding(
          padding: EdgeInsets.all(0),
          child: Text('v0.1.0',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Consolas',
              )),
        ),
      ],
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: !_isLoggedIn
            ? () async {
                if (await login()) {
                  setState(() {
                    _isLoggedIn = true;
                  });
                  if (widget.onLoginStatusChanged != null) {
                    widget.onLoginStatusChanged!(true);
                  }
                }
              }
            : () async {
                logout();
                setState(() {
                  _isLoggedIn = false;
                });
                if (widget.onLoginStatusChanged != null) {
                  widget.onLoginStatusChanged!(false);
                }
              },
        tooltip: _isLoggedIn ? '退出登录' : '登录',
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return RotationTransition(
              turns: animation,
              child: child,
            );
          },
          child:
              Icon(!_isLoggedIn ? Icons.login_outlined : Icons.logout_outlined),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _isLoggedIn
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                          child: Text('欢迎 👋 你已登录到', style: textStyle),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(0),
                          child: Text(_emailAddr, style: textStyle),
                        ),
                        sizedBox,
                        toggleDarkModeButton,
                        sizedBox,
                        info,
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        sizedBox,
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: TextFormField(
                            controller: _emailAddrController,
                            decoration: const InputDecoration(
                              labelText: '邮箱',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        sizedBox,
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: '授权码 (不是邮箱密码!!)',
                              border: const OutlineInputBorder(),
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
                          ),
                        ),
                        sizedBox,
                        toggleDarkModeButton,
                        sizedBox,
                        info,
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
