import 'package:flutter/material.dart';
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _mailboxesFetchListener = MailboxesFetch.rustSignalStream;

  int _selectedMailbox = 0;

  bool _isMailboxesFetched = false;

  List<String> _mailboxes = [];

  @override
  void initState() {
    super.initState();
    _fetchMailboxes();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedMailbox = index;
    });
  }

  void _fetchMailboxes() async {
    pb.Action(action: 3).sendSignalToRust();
    MailboxesFetch mailboxes = (await _mailboxesFetchListener.first).message;
    _mailboxes = mailboxes.mailboxes;
    setState(() {
      _isMailboxesFetched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: !_isMailboxesFetched
          ? FloatingActionButton(
              onPressed: _fetchMailboxes,
              heroTag: 'inboxPageFloatingActionButton',
              tooltip: '收取收件箱',
              child: const Icon(Icons.move_to_inbox_outlined),
            )
          : null,
      body: _isMailboxesFetched
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedMailbox,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  destinations: _mailboxes.map((mailbox) {
                    return NavigationRailDestination(
                      icon: const Icon(Icons.inbox_outlined),
                      selectedIcon: const Icon(Icons.inbox),
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
          : const Center(
              child: Text('请手动收取收件箱',
                  style: TextStyle(
                    fontSize: 18,
                  )),
            ),
    );
  }
}

class MailboxPage extends StatefulWidget {
  final String mailbox;

  const MailboxPage({required this.mailbox, super.key});

  @override
  State<MailboxPage> createState() => _MailboxPageState(mailbox: mailbox);
}

class _MailboxPageState extends State<MailboxPage> {
  _MailboxPageState({required this.mailbox});

  final _messagesFetchListener = MessagesFetch.rustSignalStream;
  final String mailbox;

  bool _triedFetching = false;
  bool _existsMessage = false;

  List<EmailFetch> messages = [];

  void _fetchMessages() async {
    pb.Action(action: 4).sendSignalToRust();
    MailboxSelection(mailbox: mailbox).sendSignalToRust();
    MessagesFetch messagesFetch = (await _messagesFetchListener.first).message;
    messages = messagesFetch.emails;
    setState(() {
      _triedFetching = true;
      _existsMessage = messages.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('收件箱：$mailbox'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchMessages,
        tooltip: _triedFetching ? '刷新' : '下载',
        child: Icon(_triedFetching ? Icons.refresh : Icons.download),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _triedFetching
                      ? _existsMessage
                          ? [
                              const Text('收到邮件',
                                  style: TextStyle(
                                    fontSize: 20,
                                  )),
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
                                              "${email.sender} ${email.date}"),
                                        );
                                      },
                                    )),
                              ),
                            ]
                          : [
                              const Text('无邮件，可刷新重试',
                                  style: TextStyle(
                                    fontSize: 20,
                                  )),
                            ]
                      : [
                          const Text('请手动收取邮件',
                              style: TextStyle(
                                fontSize: 20,
                              )),
                        ]),
            )
          ],
        ),
      ),
    );
  }
}
