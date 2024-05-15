import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:flutter/material.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _isComposing = false;
  bool _emailSent = false;

  String _recipient = "";

  final _rustResultStream = RustResult.rustSignalStream;

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _clearContent() {
    _recipientController.clear();
    _subjectController.clear();
    _bodyController.clear();
  }

  void send() async {
    pb.Action(action: 2).sendSignalToRust();
    EmailProto(
            recipient: _recipientController.text,
            subject: _subjectController.text,
            body: _bodyController.text)
        .sendSignalToRust();
    final sendResult = (await _rustResultStream.first).message;
    if (sendResult.result) {
      _recipient = _recipientController.text;
      setState(() {
        _isComposing = false;
        _emailSent = true;
      });
      _clearContent();
    } else {
      _showSnackBar('❌邮件发送失败：${sendResult.info}', const Duration(seconds: 5));
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

  void _draftSavingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("提示"),
          content: const Text("要保存草稿吗？"),
          actions: [
            TextButton(
              onPressed: () {
                _clearContent();
                Navigator.of(context).pop();
                setState(() {
                  _isComposing = false;
                });
              },
              child: const Text("丢弃"),
            ),
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isComposing = false;
                  });
                },
                child: const Text("保存")),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Wrap(
        direction: Axis.vertical,
        verticalDirection: VerticalDirection.up,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: FloatingActionButton(
              tooltip: _isComposing ? '取消' : '新邮件',
              onPressed: () {
                if (_isComposing &&
                    (_recipientController.text != "" ||
                        _subjectController.text != "" ||
                        _bodyController.text != "")) {
                  _draftSavingDialog(context);
                } else {
                  setState(() {
                    _isComposing = !_isComposing;
                  });
                }
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return RotationTransition(
                    turns: animation,
                    child: child,
                  );
                },
                child: Icon(
                  _isComposing ? Icons.close : Icons.add,
                  key: ValueKey<bool>(_isComposing),
                ),
              ),
            ),
          ),
          Container(
            child: _isComposing
                ? FloatingActionButton(
                    tooltip: '发送',
                    onPressed: () {
                      send();
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return RotationTransition(
                          turns: animation,
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.send,
                        key: ValueKey<bool>(_isComposing),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _isComposing
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 16.0),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextFormField(
                        controller: _recipientController,
                        decoration: const InputDecoration(
                          labelText: '收件人',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: '主题',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Expanded(
                      child: TextFormField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          labelText: '正文',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        expands: true,
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                key: ValueKey<bool>(!_isComposing),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  child: Text(_emailSent ? '邮件已发送至 $_recipient' : '你还未发送过邮件',
                      style: const TextStyle(
                        fontSize: 20,
                        fontFamily: 'Consolas',
                      )),
                ),
              ),
      ),
    );
  }
}
