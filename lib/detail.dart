import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('主题: ${widget.emailMetadata.subject}'),
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
            Text(
              '收件人: ${widget.emailMetadata.to}',
              style: _style,
            ),
            Text(
              '时间: ${widget.emailMetadata.date}',
              style: _style,
            ),
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
              child: SingleChildScrollView(
                child: widget.emailDetail.body.isNotEmpty
                    ? Text(
                        widget.emailDetail.body,
                        style: const TextStyle(fontSize: 16),
                      )
                    : const Text(
                        '无正文',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
