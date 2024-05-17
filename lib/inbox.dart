import 'package:flutter/material.dart';
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/main.dart';
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

  List<String> _mailboxes = [];

  @override
  void initState() {
    super.initState();
    final loginStatusNotifier =
        Provider.of<LoginStatusNotifier>(context, listen: false);
    loginStatusNotifier.addListener(_handleLoginStatusChange);
  }

  void _handleLoginStatusChange() {
    final loginStatusNotifier =
        Provider.of<LoginStatusNotifier>(context, listen: false);
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

  void _fetchMailboxes() async {
    setState(() {
      _isFetchingMailboxes = true;
    });
    pb.Action(action: 3).sendSignalToRust();
    MailboxesFetch mailboxes = (await _mailboxesFetchListener.first).message;
    _mailboxes = mailboxes.mailboxes;
    setState(() {
      _isFetchingMailboxes = false;
      _isMailboxesFetched = true;
    });
  }

  List<IconData> _getMailboxIcon(String mailbox) {
    mailbox = mailbox.toLowerCase();
    if (mailbox.contains("draft")) {
      return [Icons.drafts_outlined, Icons.drafts];
    }
    if (mailbox.contains("delete")) {
      return [Icons.delete_outline, Icons.delete];
    }
    if (mailbox.contains("junk")) {
      return [Icons.close_outlined, Icons.close];
    }
    if (mailbox.contains("send") || mailbox.contains("sent")) {
      return [Icons.send_outlined, Icons.send];
    }
    return [Icons.inbox_outlined, Icons.inbox];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isFetchingMailboxes || _isMailboxesFetched
          ? null
          : FloatingActionButton(
              onPressed: _fetchMailboxes,
              heroTag: 'inboxPageFloatingActionButton',
              tooltip: '收取收件箱',
              child: const Icon(Icons.move_to_inbox_outlined),
            ),
      body: _isMailboxesFetched
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
              child: Text(_isFetchingMailboxes ? '收取中...' : '请手动收取收件箱',
                  style: const TextStyle(
                    fontSize: 20,
                  )),
            ),
    );
  }
}

class MailboxPage extends StatefulWidget {
  final String mailbox;

  const MailboxPage({required this.mailbox, super.key});

  @override
  State<MailboxPage> createState() => _MailboxPageState();
}

class _MailboxPageState extends State<MailboxPage> {
  final _messagesFetchListener = MessagesFetch.rustSignalStream;
  late String mailbox;

  bool _triedFetching = false;
  bool _existsMessage = false;
  bool _isFetching = false;
  bool _isReadingDetail = false;
  late EmailFetch _selectedEmail;

  List<EmailFetch> messages = [];

  final _style = const TextStyle(
    fontSize: 20,
  );

  @override
  void initState() {
    super.initState();
    mailbox = widget.mailbox;
  }

  void _fetchMessages() async {
    setState(() {
      _isFetching = true;
    });
    pb.Action(action: 4).sendSignalToRust();
    MailboxSelection(mailbox: mailbox).sendSignalToRust();
    MessagesFetch messagesFetch = (await _messagesFetchListener.first).message;
    messages = messagesFetch.emails;
    setState(() {
      _isFetching = false;
      _triedFetching = true;
      _existsMessage = messages.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('收件箱：$mailbox'),
        backgroundColor: Color.fromRGBO(MyApp.seedColor.red,
            MyApp.seedColor.green, MyApp.seedColor.blue, 0.8),
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
                      email: _selectedEmail,
                      onBack: () {
                        setState(() {
                          _isReadingDetail = false;
                        });
                      },
                    ),
                  )
                ]
              : [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300, maxWidth: 800),
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
                                                      "From: ${email.from}\nTo: ${email.to}\nDate: ${email.date}"),
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
                                  ]),
                  )
                ],
        ),
      ),
    );
  }
}

class EmailDetailScreen extends StatelessWidget {
  final EmailFetch email;
  final VoidCallback onBack;

  const EmailDetailScreen(
      {super.key, required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(email.subject),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "From: ${email.from}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "To: ${email.to}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              "Date: ${email.date}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
