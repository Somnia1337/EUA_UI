import 'package:eua_ui/messages/user.pbserver.dart';
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

  final _rustResultStream = RustResult.rustSignalStream;

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<bool> sendEmail() async {
    EmailProto(
            recipient: _recipientController.text,
            subject: _subjectController.text,
            body: _bodyController.text)
        .sendSignalToRust();
    final rustSignal = await _rustResultStream.first;
    RustResult loginResult = rustSignal.message;
    return loginResult.result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
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
        onPressed: () {
          sendEmail();
          // Future<String> confimation = receiveUser();

          setState(() {
            _isComposing = !_isComposing;
          });
        },
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
                        expands: false,
                      ),
                    ),
                  ],
                ),
              )
            : Center(
                key: ValueKey<bool>(!_isComposing),
                child: const Text('Compose Page'),
              ),
      ),
    );
  }
}
