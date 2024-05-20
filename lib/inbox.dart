import 'package:eua_ui/main.dart';
import 'package:eua_ui/messages/user.pb.dart' as pb;
import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:eua_ui/settings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _red = const Color.fromRGBO(233, 95, 89, 0.8);

  final _mailboxesFetchListener = MailboxesFetch.rustSignalStream;

  int _selectedMailbox = 0;
  bool _isFetchingMailboxes = false;
  bool _isMailboxesFetched = false;
  bool _isNetease = false;

  String? _folderPath;

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
      _resetState();
    }
  }

  void _resetState() {
    _mailboxes.clear();
    setState(() {
      _selectedMailbox = 0;
      _isFetchingMailboxes = false;
      _isMailboxesFetched = false;
      _isNetease = false;
      _folderPath = null;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedMailbox = index;
    });
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

  Future<bool> _pickFolder() async {
    final selectedFolder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择附件保存的位置',
      lockParentWindow: true,
    );

    if (selectedFolder != null) {
      setState(() {
        _folderPath = selectedFolder;
      });
      return true;
    }
    return false;
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
      onPressed: () async {
        if (await _pickFolder()) {
          _showSnackBar(
            '已选择位置: $_folderPath',
            null,
            const Duration(seconds: 2),
          );
          await _fetchMailboxes();
        } else {
          _showSnackBar(
            '❗必须选择附件保存位置才能下载邮件',
            _red,
            const Duration(seconds: 2),
          );
        }
      },
      heroTag: 'inboxPageFloatingActionButton',
      tooltip: '选择位置',
      child: const Icon(Icons.folder),
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
        _isFetchingMailboxes ? '正在获取收件箱...' : '请选择附件保存位置',
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
                            child: MailboxPage(
                              mailbox: mailbox,
                              folderPath: _folderPath ?? '',
                            ),
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
  const MailboxPage({
    required this.mailbox,
    required this.folderPath,
    super.key,
  });

  final String mailbox;
  final String folderPath;

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
  late String _folderPath;
  final _red = const Color.fromRGBO(233, 95, 89, 0.8);
  final _style = const TextStyle(
    fontSize: 20,
  );

  late String _mailbox;
  EmailMetadata? _selectedEmail;
  EmailDetailFetch? _emailDetail;
  List<EmailMetadata> emailMetadatas = [];

  @override
  void initState() {
    super.initState();

    _mailbox = widget.mailbox;
    _folderPath = widget.folderPath;
  }

  Future<void> _fetchEmailMetadatas() async {
    // Send signals
    pb.Action(action: 4).sendSignalToRust();
    MailboxRequest(mailbox: _mailbox).sendSignalToRust();

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
      appBar: _isReadingDetail
          ? null
          : AppBar(
              title: Text('收件箱: $_mailbox'),
            ),
      floatingActionButton:
          _isFetchingMetadata || _isReadingDetail || _isFetchingDetail
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
                      folderPath: _folderPath,
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
                                  Text('正在下载正文和附件...', style: _style),
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
                                                      if (await _fetchEmailDetail(
                                                        email,
                                                        _folderPath,
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

class EmailDetailPage extends StatefulWidget {
  const EmailDetailPage({
    super.key,
    required this.emailMetadata,
    required this.emailDetail,
    required this.onBack,
    required this.folderPath,
  });

  final EmailMetadata emailMetadata;
  final EmailDetailFetch emailDetail;
  final VoidCallback onBack;
  final String folderPath;

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage> {
  final _red = const Color.fromRGBO(233, 95, 89, 0.8);
  final _style = const TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  late String folderPath = widget.folderPath;

  Future<void> _openFolder(String folderPath) async {
    final folderUri = Uri.file(folderPath);
    if (await canLaunchUrl(folderUri)) {
      await launchUrl(folderUri);
    } else {
      _showSnackBar('❌无法打开 $folderPath', _red, const Duration(seconds: 3));
    }
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
    const sizedBox = SizedBox(height: 4);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.emailMetadata.subject),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发件人: ${widget.emailMetadata.from}',
              style: _style,
            ),
            sizedBox,
            Text(
              '收件人: ${widget.emailMetadata.to}',
              style: _style,
            ),
            sizedBox,
            Text(
              '时间: ${widget.emailMetadata.date}',
              style: _style,
            ),
            sizedBox,
            widget.emailDetail.attachments.isNotEmpty
                ? Row(
                    children: [
                      Row(
                        children: [
                          Text(
                            '附件:',
                            style: _style,
                          ),
                          IconButton(
                            onPressed: () => _openFolder(folderPath),
                            icon: const Icon(Icons.folder_outlined),
                            tooltip: '打开附件位置',
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      Text.rich(
                        TextSpan(
                          text: '\n',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          children:
                              widget.emailDetail.attachments.map((attachment) {
                            return TextSpan(
                              text: '$attachment\n',
                              style: const TextStyle(fontSize: 16),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  )
                : Text(
                    '[无附件]',
                    style: _style,
                  ),
            const SizedBox(height: 20),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 550, maxWidth: 550),
                child: SingleChildScrollView(
                  child: widget.emailDetail.body.isNotEmpty
                      ? Text(
                          widget.emailDetail.body,
                          style: const TextStyle(fontSize: 16),
                        )
                      : const Text(
                          '[无正文]',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
