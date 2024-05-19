// TODO(Somnia1337): 已保存过附件的邮件可以直接打开
// TODO(Somnia1337): 展示附件保存位置

import 'package:eua_ui/detail.dart';
import 'package:eua_ui/main.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/settings.dart';
import 'package:file_picker/file_picker.dart';
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
    setState(() {
      _selectedMailbox = 0;
      _mailboxes.clear();
      _isMailboxesFetched = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedMailbox = index;
    });
  }

  Future<void> _fetchMailboxes() async {
    // Send signal
    pb.Action(action: 3).sendSignalToRust();

    // Wait for Rust
    setState(() {
      _isFetchingMailboxes = true;
    });
    final mailboxesFetched = (await _mailboxesFetchListener.first).message;
    setState(() {
      _isFetchingMailboxes = false;
    });

    // Handle result
    _mailboxes = mailboxesFetched.mailboxes;
    setState(() {
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

    final fetchMailboxesButton = FloatingActionButton(
      onPressed: _fetchMailboxes,
      heroTag: 'inboxPageFloatingActionButton',
      tooltip: '获取收件箱',
      child: const Icon(Icons.move_to_inbox_outlined),
    );

    final mailboxDestinations = _mailboxes.map((mailbox) {
      return NavigationRailDestination(
        icon: Icon(_getMailboxIcon(mailbox)[0]),
        selectedIcon: Icon(_getMailboxIcon(mailbox)[1]),
        label: Text(mailbox),
      );
    }).toList();

    final fetchInfo = Center(
      child: Text(
        _isFetchingMailboxes ? '获取中...' : '请手动获取收件箱',
        style: const TextStyle(
          fontSize: 20,
        ),
      ),
    );

    return Scaffold(
      floatingActionButton:
          _isNetease || _isFetchingMailboxes || _isMailboxesFetched
              ? null
              : fetchMailboxesButton,
      body: _isNetease
          ? neteaseInfo
          : _isMailboxesFetched
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedMailbox,
                      onDestinationSelected: _onItemTapped,
                      labelType: NavigationRailLabelType.all,
                      destinations: mailboxDestinations,
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
              : fetchInfo,
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
  final _emailMetadataFetchListener = EmailMetadataFetch.rustSignalStream;
  final _emailDetailFetchListener = EmailDetailFetch.rustSignalStream;
  final _rustResultListener = RustResult.rustSignalStream;

  bool _triedFetching = false;
  bool _existsMessage = false;
  bool _isFetchingMetadata = false;
  bool _isFetchingDetail = false;
  bool _isReadingDetail = false;
  final _red = const Color.fromRGBO(233, 95, 89, 0.8);
  final _style = const TextStyle(
    fontSize: 20,
  );

  late String mailbox;
  EmailMetadata? _selectedEmail;
  EmailDetailFetch? _emailDetail;
  List<EmailMetadata> emailMetadatas = [];

  @override
  void initState() {
    super.initState();

    mailbox = widget.mailbox;
  }

  Future<void> _fetchEmailMetadatas() async {
    // Send signals
    pb.Action(action: 4).sendSignalToRust();
    MailboxRequest(mailbox: mailbox).sendSignalToRust();

    // Wait for Rust
    setState(() {
      _isFetchingMetadata = true;
    });
    final fetchMessagesResult = (await _rustResultListener.first).message;
    setState(() {
      _isFetchingMetadata = false;
    });

    // Handle result
    if (fetchMessagesResult.result) {
      final emailMetadataFetch =
          (await _emailMetadataFetchListener.first).message;
      emailMetadatas = emailMetadataFetch.emailMetadatas;
    } else {
      _showSnackBar(
        '下载失败: ${fetchMessagesResult.info}',
        _red,
        const Duration(seconds: 3),
      );
    }
    setState(() {
      _triedFetching = true;
      _existsMessage = emailMetadatas.isNotEmpty;
    });
  }

  Future<String?> _pickFolder() async {
    final selectedFolder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择附件保存的位置',
      lockParentWindow: true,
    );

    if (selectedFolder != null) {
      return selectedFolder;
    }
    _showSnackBar('取消选择附件保存位置', null, const Duration(seconds: 1));
    return null;
  }

  Future<bool> _fetchEmailDetail(
    EmailMetadata emailMetadata,
    String folderPath,
  ) async {
    // Send signals
    pb.Action(action: 5).sendSignalToRust();
    EmailDetailRequest(uid: emailMetadata.uid, folderPath: folderPath)
        .sendSignalToRust();

    // Wait for Rust
    setState(() {
      _isFetchingDetail = true;
    });
    final fetchMessagesResult = (await _rustResultListener.first).message;
    setState(() {
      _isFetchingDetail = false;
    });

    // Handle result
    if (fetchMessagesResult.result) {
      final emailDetailFetch = (await _emailDetailFetchListener.first).message;
      _emailDetail = emailDetailFetch;
      return true;
    }
    _showSnackBar(
      '下载失败: ${fetchMessagesResult.info}',
      _red,
      const Duration(seconds: 3),
    );
    return false;
  }

  void _showSnackBar(String message, Color? color, Duration duration) {
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
        title: Text('收件箱: $mailbox'),
      ),
      floatingActionButton: _isFetchingMetadata || _isReadingDetail
          ? null
          : FloatingActionButton(
              autofocus: true,
              onPressed: _fetchEmailMetadatas,
              tooltip: _triedFetching ? '刷新' : '下载邮件',
              child: Icon(_triedFetching ? Icons.refresh : Icons.download),
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _isReadingDetail
              ? [
                  Expanded(
                    child: EmailDetailPage(
                      emailMetadata: _selectedEmail ?? EmailMetadata(),
                      emailDetail: _emailDetail ?? EmailDetailFetch(),
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
                      children: _isFetchingMetadata
                          ? [
                              Text('正在下载邮件...', style: _style),
                            ]
                          : _isFetchingDetail
                              ? [
                                  Text('正在下载附件...', style: _style),
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
                                                itemCount:
                                                    emailMetadatas.length,
                                                itemBuilder: (context, index) {
                                                  final email =
                                                      emailMetadatas[index];
                                                  return ListTile(
                                                    title: Text(email.subject),
                                                    subtitle: Text(
                                                      'From: ${email.from}\nTo: ${email.to}\nDate: ${email.date}',
                                                    ),
                                                    onTap: () async {
                                                      final folderPath =
                                                          await _pickFolder();
                                                      if (folderPath != null &&
                                                          await _fetchEmailDetail(
                                                            email,
                                                            folderPath,
                                                          )) {
                                                        setState(() {
                                                          _selectedEmail =
                                                              email;
                                                          _isReadingDetail =
                                                              true;
                                                        });
                                                      }
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
