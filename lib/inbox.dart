//! 收取附件: 对常见类型予以显示，对所有类型可选保存.
//! 不重复下载已经下载的邮件

import 'package:eua_ui/main.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _mailboxesFetchListener = MailboxesFetch.rustSignalStream;

  int _selectedMailbox = 0;

  bool _isFetchingMailboxes = false;
  bool _isMailboxesFetched = false;
  bool _isNetease = false;

  List<String> _mailboxes = [];

  @override
  void initState() {
    super.initState();
    Provider.of<LoginStatusNotifier>(context, listen: false)
        .addListener(_handleLoginStatusChange);
  }

  void _handleLoginStatusChange() {
    final loginStatusNotifier =
        Provider.of<LoginStatusNotifier>(context, listen: false);
    setState(() {
      _isNetease = SettingsPage.userEmailAddr.endsWith('163.com') ||
          SettingsPage.userEmailAddr.endsWith('126.com');
    });
    if (!loginStatusNotifier.isLoggedIn) {
      _reset();
    }
  }

  void _reset() {
    _selectedMailbox = 0;
    _mailboxes = [];
    setState(() {
      _isMailboxesFetched = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedMailbox = index;
    });
  }

  Future<void> _fetchMailboxes() async {
    setState(() {
      _isFetchingMailboxes = true;
    });
    pb.Action(action: 3).sendSignalToRust();
    final mailboxes = (await _mailboxesFetchListener.first).message;
    _mailboxes = mailboxes.mailboxes;
    setState(() {
      _isFetchingMailboxes = false;
      _isMailboxesFetched = true;
    });
  }

  List<IconData> _getMailboxIcon(String mailbox) {
    final mailboxLowered = mailbox.toLowerCase();
    if (mailboxLowered.contains('draft')) {
      return [Icons.drafts_outlined, Icons.drafts];
    }
    if (mailboxLowered.contains('delete')) {
      return [Icons.delete_outline, Icons.delete];
    }
    if (mailboxLowered.contains('junk')) {
      return [Icons.close_outlined, Icons.close];
    }
    if (mailboxLowered.contains('send') || mailboxLowered.contains('sent')) {
      return [Icons.send_outlined, Icons.send];
    }
    return [Icons.inbox_outlined, Icons.inbox];
  }

  @override
  Widget build(BuildContext context) {
    const neteaseInfo = Center(
      child: Text(
        '😵由于网易邮箱服务器的限制，\n未经认证的第三方用户代理无法收取邮件',
        style: TextStyle(
          fontSize: 20,
        ),
      ),
    );

    return Scaffold(
      floatingActionButton:
          _isNetease || _isFetchingMailboxes || _isMailboxesFetched
              ? null
              : FloatingActionButton(
                  onPressed: _fetchMailboxes,
                  heroTag: 'inboxPageFloatingActionButton',
                  tooltip: '获取收件箱',
                  child: const Icon(Icons.move_to_inbox_outlined),
                ),
      body: _isNetease
          ? neteaseInfo
          : _isMailboxesFetched
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedMailbox,
                      onDestinationSelected: _onItemTapped,
                      labelType: NavigationRailLabelType.all,
                      destinations: _mailboxes.map((mailbox) {
                        return NavigationRailDestination(
                          icon: Icon(_getMailboxIcon(mailbox)[0]),
                          selectedIcon: Icon(_getMailboxIcon(mailbox)[1]),
                          label: Text(mailbox),
                        );
                      }).toList(),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedMailbox,
                        children: _mailboxes.map((mailbox) {
                          return Center(
                            child: MailboxPage(mailbox: mailbox),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    _isFetchingMailboxes ? '获取中...' : '请手动获取收件箱',
                    style: const TextStyle(
                      fontSize: 20,
                    ),
                  ),
                ),
    );
  }
}

class MailboxPage extends StatefulWidget {
  const MailboxPage({required this.mailbox, super.key});
  final String mailbox;

  @override
  State<MailboxPage> createState() => _MailboxPageState();
}

class _MailboxPageState extends State<MailboxPage> {
  final _messagesFetchListener = MessagesFetch.rustSignalStream;
  final _rustResultListener = RustResult.rustSignalStream;
  late String mailbox;

  bool _triedFetching = false;
  bool _existsMessage = false;
  bool _isFetching = false;
  bool _isReadingDetail = false;
  Email? _selectedEmail;

  List<Email> messages = [];

  final _red = const Color.fromRGBO(233, 95, 89, 0.8);

  final _style = const TextStyle(
    fontSize: 20,
  );

  @override
  void initState() {
    super.initState();
    mailbox = widget.mailbox;
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isFetching = true;
    });
    pb.Action(action: 4).sendSignalToRust();
    MailboxSelection(mailbox: mailbox).sendSignalToRust();
    final fetchMessagesResult = (await _rustResultListener.first).message;
    if (fetchMessagesResult.result) {
      final messagesFetch = (await _messagesFetchListener.first).message;
      messages = messagesFetch.emails;
    } else {
      _showSnackBar(fetchMessagesResult.info, _red, const Duration(seconds: 3));
    }
    setState(() {
      _isFetching = false;
      _triedFetching = true;
      _existsMessage = messages.isNotEmpty;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('收件箱：$mailbox'),
      ),
      floatingActionButton: _isFetching || _isReadingDetail
          ? null
          : FloatingActionButton(
              autofocus: true,
              onPressed: _fetchMessages,
              tooltip: _triedFetching ? '刷新' : '下载邮件',
              child: Icon(_triedFetching ? Icons.refresh : Icons.download),
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _isReadingDetail
              ? [
                  Expanded(
                    child: EmailDetailScreen(
                      email: _selectedEmail ?? Email(),
                      onBack: () {
                        setState(() {
                          _isReadingDetail = false;
                        });
                      },
                    ),
                  ),
                ]
              : [
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 350, maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _isFetching
                          ? [
                              Text('下载中...', style: _style),
                            ]
                          : _triedFetching
                              ? _existsMessage
                                  ? [
                                      Text('邮件列表', style: _style),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: messages.length,
                                            itemBuilder: (context, index) {
                                              final email = messages[index];
                                              return ListTile(
                                                title: Text(email.subject),
                                                subtitle: Text(
                                                  'From: ${email.from}\nTo: ${email.to}\nDate: ${email.date}',
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
                                    ]
                                  : [
                                      Text('无邮件，可刷新重试', style: _style),
                                    ]
                              : [
                                  Text('请手动下载邮件', style: _style),
                                ],
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

class EmailDetailScreen extends StatelessWidget {
  const EmailDetailScreen({
    super.key,
    required this.email,
    required this.onBack,
  });
  final Email email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('主题: ${email.subject}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发件人: ${email.from}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '收件人: ${email.to}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '时间: ${email.date}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text.rich(
              TextSpan(
                text: '附件: \n',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                children: email.attachments.map((attachment) {
                  return TextSpan(
                    text: '$attachment\n',
                    style: const TextStyle(fontSize: 16),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              email.body,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
