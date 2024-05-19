//! 展示已发送邮件的附件

import 'dart:io';

import 'package:eua_ui/inbox.dart';
import 'package:eua_ui/main.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/settings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key});

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  bool _isComposing = false;
  bool _isSending = false;
  bool _isReadingDetail = false;
  bool _isEmailSent = false;

  final _yellow = const Color.fromRGBO(211, 211, 80, 0.8);
  final _red = const Color.fromRGBO(233, 95, 89, 0.8);

  final List<File> _attachments = [];
  var _attachmentsLengthSum = 0.0;

  final List<Email> _sentEmails = [];
  Email? _selectedEmail;

  final _toInputController = TextEditingController();
  final _subjectInputController = TextEditingController();
  final _bodyInputController = TextEditingController();

  final _subjectInputFocusNode = FocusNode();
  final _bodyInputFocusNode = FocusNode();

  final _rustResultStream = RustResult.rustSignalStream;

  @override
  void initState() {
    super.initState();

    Provider.of<LoginStatusNotifier>(context, listen: false)
        .addListener(_onLoginStatusChange);
  }

  @override
  void dispose() {
    _toInputController.dispose();
    _subjectInputController.dispose();
    _bodyInputController.dispose();

    _subjectInputFocusNode.dispose();
    _bodyInputFocusNode.dispose();

    Provider.of<LoginStatusNotifier>(context, listen: false)
        .removeListener(_onLoginStatusChange);

    super.dispose();
  }

  void _onLoginStatusChange() {
    final loginStatusNotifier =
        Provider.of<LoginStatusNotifier>(context, listen: false);

    if (!loginStatusNotifier.isLoggedIn) {
      _resetState();
    }
  }

  void _resetState() {
    _clearComposingFields();
    _sentEmails.clear();
    setState(() {
      _isEmailSent = false;
    });
  }

  void _clearComposingFields() {
    _toInputController.clear();
    _subjectInputController.clear();
    _bodyInputController.clear();
    _attachments.clear();
    _attachmentsLengthSum = 0;
  }

  void _showSnackBar(String message, Color? color, Duration duration) {
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

  Future<void> _sendEmail() async {
    // Send signals
    pb.Action(action: 2).sendSignalToRust();
    final email = Email(
      from: SettingsPage.userEmailAddr,
      to: _toInputController.text,
      subject: _subjectInputController.text,
      date: DateTime.now().toString(),
      attachments: _attachments.map((file) => file.path),
      body: _bodyInputController.text,
    )..sendSignalToRust();

    // Wait for Rust result
    setState(() {
      _isSending = true;
    });
    final sendResult = (await _rustResultStream.first).message;
    setState(() {
      _isSending = false;
    });

    // Handle result
    if (sendResult.result) {
      _sentEmails.add(email);
      _clearComposingFields();
      setState(() {
        _isComposing = false;
        _isEmailSent = true;
      });
    } else {
      _showSnackBar(
        '😥邮件发送失败：${sendResult.info}',
        _red,
        const Duration(seconds: 5),
      );
    }
  }

  Future<void> _pickFile() async {
    final filePickerResult = await FilePicker.platform.pickFiles(
      dialogTitle: '选择附件',
      allowMultiple: true,
      lockParentWindow: true,
    );

    if (filePickerResult != null) {
      for (final pick in filePickerResult.files) {
        final file = File(pick.path!);
        if (!_attachments.any(
          (filePicked) => filePicked.path == file.path,
        )) {
          final length = file.lengthSync() / 1048576;
          if (_attachmentsLengthSum + length <= 50.0) {
            setState(() {
              _attachments.add(file);
              _attachmentsLengthSum += length;
            });
          } else {
            _showSnackBar(
              '😵‍💫附件的总大小不能超过 50MB！',
              _yellow,
              const Duration(seconds: 2),
            );
          }
        } else {
          _showSnackBar(
            '😵‍💫重复附件：${file.path}',
            _yellow,
            const Duration(seconds: 2),
          );
        }
      }
    } else {
      _showSnackBar(
        '取消选择附件',
        null,
        const Duration(seconds: 1),
      );
    }
  }

  void _showDraftSavingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('要保存草稿吗？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                _clearComposingFields();
                setState(() {
                  _isComposing = false;
                });
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
    final composeButton = FloatingActionButton(
      tooltip: _isComposing ? '取消' : '新邮件',
      onPressed: () {
        if (_isComposing &&
            (_toInputController.text.isNotEmpty ||
                _subjectInputController.text.isNotEmpty ||
                _attachments.isNotEmpty ||
                _bodyInputController.text.isNotEmpty)) {
          _showDraftSavingDialog(context);
        } else {
          setState(() {
            _isComposing = !_isComposing;
          });
        }
      },
      child: Icon(
        _isComposing ? Icons.close : Icons.add,
        key: ValueKey<bool>(_isComposing),
      ),
    );
    final sendButton = FloatingActionButton(
      tooltip: '发送',
      onPressed: _sendEmail,
      child: Icon(
        Icons.send,
        key: ValueKey<bool>(_isComposing),
      ),
    );

    const sendingText = Center(
      child: Text(
        '发送中...',
        style: TextStyle(fontSize: 20),
      ),
    );

    final emailDetail = EmailDetailScreen(
      email: _selectedEmail ?? Email(),
      onBack: () {
        setState(() {
          _isReadingDetail = false;
        });
      },
    );

    final toInputField = TextFormField(
      controller: _toInputController,
      decoration: const InputDecoration(
        labelText: '收件人',
        border: UnderlineInputBorder(),
      ),
      keyboardType: TextInputType.emailAddress,
      onFieldSubmitted: (value) {
        FocusScope.of(context).requestFocus(_subjectInputFocusNode);
      },
    );
    final subjectInputField = TextFormField(
      controller: _subjectInputController,
      focusNode: _subjectInputFocusNode,
      decoration: const InputDecoration(
        labelText: '主题',
        border: UnderlineInputBorder(),
      ),
      onFieldSubmitted: (value) {
        FocusScope.of(context).requestFocus(_bodyInputFocusNode);
      },
    );
    final bodyInputField = TextFormField(
      controller: _bodyInputController,
      focusNode: _bodyInputFocusNode,
      decoration: const InputDecoration(
        labelText: '正文',
        border: InputBorder.none,
      ),
      keyboardType: TextInputType.multiline,
      maxLines: null,
      expands: true,
    );

    final attachmentList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: 10,
          ),
          child: Text(
            '已选择 ${_attachmentsLengthSum.toStringAsFixed(1)}MB',
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _attachments.length,
            itemBuilder: (context, index) {
              final file = _attachments[index];
              return ListTile(
                minTileHeight: 15,
                title: Text(
                  file.path,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.left,
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 20,
                  ),
                  splashRadius: 15,
                  onPressed: () {
                    final len = _attachments[index].lengthSync() / 1048576;
                    _showSnackBar(
                      '已移除：${_attachments[index].path}',
                      null,
                      const Duration(
                        seconds: 2,
                      ),
                    );
                    setState(() {
                      _attachmentsLengthSum -= len;
                      _attachments.removeAt(
                        index,
                      );
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      floatingActionButton: _isSending || _isReadingDetail
          ? null
          : Wrap(
              direction: Axis.vertical,
              verticalDirection: VerticalDirection.up,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  child: composeButton,
                ),
                Container(
                  child: _isComposing ? sendButton : null,
                ),
              ],
            ),
      body: _isReadingDetail
          ? emailDetail
          : _isSending
              ? sendingText
              : _isComposing
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: toInputField,
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: subjectInputField,
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 550,
                              maxHeight: _attachments.length == 1
                                  ? 100
                                  : _attachments.length == 2
                                      ? 120
                                      : 140,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_link_outlined,
                                  ),
                                  tooltip: '添加附件',
                                  splashRadius: 20,
                                  onPressed: _pickFile,
                                  alignment: Alignment.topLeft,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: _attachments.isEmpty
                                        ? const Text(
                                            '由于服务器限制，附件的总大小不能超过 50MB',
                                            style: TextStyle(
                                              fontSize: 16,
                                            ),
                                          )
                                        : attachmentList,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: bodyInputField,
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: _isEmailSent
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 280,
                                maxWidth: 400,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
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
                                        itemCount: _sentEmails.length,
                                        itemBuilder: (context, index) {
                                          final email = _sentEmails[index];
                                          return ListTile(
                                            title: Text(
                                              email.subject.isNotEmpty
                                                  ? email.subject
                                                  : '[无主题]',
                                            ),
                                            subtitle: Text(
                                              '收件人: ${email.to}',
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
    );
  }
}
