import 'dart:io';

import 'package:eua_ui/inbox.dart';
import 'package:eua_ui/main.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _subjectFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();

  final _green = const Color.fromRGBO(66, 184, 131, 0.8);
  final _red = const Color.fromRGBO(233, 95, 89, 0.8);

  bool _isComposing = false;
  bool _isSending = false;
  bool _isReadingDetail = false;
  bool _emailSent = false;
  List<String> _files = [];

  late Email _selectedEmail;

  final List<Email> _sent = [];

  final _rustResultStream = RustResult.rustSignalStream;

  @override
  void initState() {
    super.initState();
    Provider.of<LoginStatusNotifier>(context, listen: false)
        .addListener(_handleLoginStatusChange);
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _subjectFocusNode.dispose();
    _bodyFocusNode.dispose();
    Provider.of<LoginStatusNotifier>(context, listen: false)
        .removeListener(_handleLoginStatusChange);
    super.dispose();
  }

  void _handleLoginStatusChange() {
    final loginStatusNotifier =
        Provider.of<LoginStatusNotifier>(context, listen: false);
    if (!loginStatusNotifier.isLoggedIn) {
      _reset();
    }
  }

  void _clearContent() {
    _toController.clear();
    _subjectController.clear();
    _bodyController.clear();
    setState(() {
      _files = [];
    });
  }

  void _reset() {
    _clearContent();
    _sent.clear();
    setState(() {
      _emailSent = false;
      _files = [];
    });
  }

  Future<void> send() async {
    pb.Action(action: 2).sendSignalToRust();
    EmailSend(
      to: _toController.text,
      subject: _subjectController.text,
      filepath: _files,
      body: _bodyController.text,
    ).sendSignalToRust();

    setState(() {
      _isSending = true;
    });

    final sendResult = (await _rustResultStream.first).message;

    setState(() {
      _isSending = false;
    });

    if (sendResult.result) {
      setState(() {
        _isComposing = false;
        _emailSent = true;
      });
      _sent.add(
        Email(
          to: _toController.text,
          subject: _subjectController.text,
          date: DateTime.now().toString(),
          body: _bodyController.text,
        ),
      );
      _clearContent();
    } else {
      _showSnackBar(
        '❌邮件发送失败：${sendResult.info}',
        _red,
        const Duration(seconds: 5),
      );
    }
  }

  void _showSnackBar(String message, Color color, Duration duration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 16, color: color),
        ),
        duration: duration,
      ),
    );
  }

  Future<File?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      return File(result.files.single.path!);
    } else {
      return null;
    }
  }

  void _draftSavingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('要保存草稿吗？'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isComposing = false;
                });
                _clearContent();
                Navigator.of(context).pop();
              },
              child: const Text('丢弃'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isComposing = false;
                });
                Navigator.of(context).pop();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isReadingDetail
          ? null
          : Wrap(
              direction: Axis.vertical,
              verticalDirection: VerticalDirection.up,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                  child: FloatingActionButton(
                    tooltip: _isComposing ? '取消' : '新邮件',
                    onPressed: () {
                      if (_isComposing &&
                          (_toController.text.isNotEmpty ||
                              _subjectController.text.isNotEmpty ||
                              _files.isNotEmpty ||
                              _bodyController.text.isNotEmpty)) {
                        _draftSavingDialog(context);
                      } else {
                        setState(() {
                          _isComposing = !_isComposing;
                        });
                      }
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
                          onPressed: send,
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
        child: _isReadingDetail
            ? Expanded(
                child: EmailDetailScreen(
                  email: _selectedEmail,
                  onBack: () {
                    setState(() {
                      _isReadingDetail = false;
                    });
                  },
                ),
              )
            : _isSending
                ? const Center(child: Text('发送中...'))
                : _isComposing
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: TextFormField(
                                controller: _toController,
                                decoration: const InputDecoration(
                                  labelText: '收件人',
                                  border: UnderlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context)
                                      .requestFocus(_subjectFocusNode);
                                },
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 500),
                              child: TextFormField(
                                controller: _subjectController,
                                focusNode: _subjectFocusNode,
                                decoration: const InputDecoration(
                                  labelText: '主题',
                                  border: UnderlineInputBorder(),
                                ),
                                onFieldSubmitted: (value) {
                                  FocusScope.of(context)
                                      .requestFocus(_bodyFocusNode);
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 550,
                                maxHeight: 135,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon:
                                        const Icon(Icons.file_present_outlined),
                                    tooltip: '附件',
                                    splashRadius: 20,
                                    onPressed: () async {
                                      final file = await _pickFile();
                                      if (file != null) {
                                        if (!_files.contains(file.path)) {
                                          setState(() {
                                            _files.add(file.path);
                                          });
                                        } else {
                                          _showSnackBar(
                                            '❗重复附件：${file.path}',
                                            _red,
                                            const Duration(seconds: 3),
                                          );
                                        }
                                      } else {
                                        _showSnackBar(
                                          '取消选择附件',
                                          _green,
                                          const Duration(seconds: 1),
                                        );
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: _files.isEmpty
                                          ? const Text(
                                              '由于服务器限制，附件的总大小不能超过 50MB！',
                                            )
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: _files.length,
                                              itemBuilder: (context, index) {
                                                final filepath = _files[index];
                                                return ListTile(
                                                  title: Text(
                                                    filepath,
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 14,
                                                    ),
                                                    textAlign: TextAlign.left,
                                                  ),
                                                  trailing: IconButton(
                                                    icon: const Icon(
                                                      Icons.clear_rounded,
                                                    ),
                                                    splashRadius: 20,
                                                    onPressed: () {
                                                      _showSnackBar(
                                                        '已移除：${_files[index]}',
                                                        _green,
                                                        const Duration(
                                                          seconds: 2,
                                                        ),
                                                      );
                                                      setState(() {
                                                        _files.removeAt(index);
                                                      });
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _bodyController,
                                focusNode: _bodyFocusNode,
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
                        child: _emailSent
                            ? ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 260),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                                      child: Text(
                                        '已发送邮件',
                                        style: TextStyle(
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _sent.length,
                                          itemBuilder: (context, index) {
                                            final email = _sent[index];
                                            return ListTile(
                                              title: Text(
                                                email.subject.isNotEmpty
                                                    ? email.subject
                                                    : '[无主题]',
                                              ),
                                              subtitle: Text(
                                                'To ${email.to}',
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  _selectedEmail = email;
                                                  _isReadingDetail = true;
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Text(
                                  '还未发送过邮件',
                                  style: TextStyle(
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                      ),
      ),
    );
  }
}
