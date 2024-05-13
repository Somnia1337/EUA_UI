import 'package:eua_ui/messages/user.pbserver.dart';
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

  final _stream = RustResult.rustSignalStream;

  String _emailAddr = "";

  bool _isLoggedIn = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailAddrController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void sendUser(String emailAddr, String password) {
    UserProto(emailAddr: emailAddr, password: password).sendSignalToRust();
  }

  Future<bool> login() async {
    sendUser(_emailAddrController.text, _passwordController.text);
    _emailAddr = _emailAddrController.text;
    final rustSignal = await _stream.first;
    RustResult loginResult = rustSignal.message;
    return loginResult.result;
  }

  Future<bool> logout() async {
    return Future.value(true);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Brightness currentBrightness = Theme.of(context).brightness;

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
          padding: EdgeInsets.fromLTRB(0, 18, 0, 8),
          child: Text('卢剑歌 2022141461145',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Microsoft JhengHei UI',
              )),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Text('[项目地址]',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Microsoft JhengHei UI',
              )),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 18),
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
                } else {
                  _showSnackBar('登录失败，请重试');
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
                          child: Text('欢迎 👋 $_emailAddr',
                              style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Microsoft JhengHei UI',
                              )),
                        ),
                        toggleDarkModeButton,
                        info,
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
                        toggleDarkModeButton,
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
