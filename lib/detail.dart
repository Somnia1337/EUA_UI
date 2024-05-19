import 'package:eua_ui/messages/user.pbserver.dart';
import 'package:flutter/material.dart';

class EmailDetailPage extends StatefulWidget {
  const EmailDetailPage({
    super.key,
    required this.emailMetadata,
    required this.emailDetail,
    required this.onBack,
  });

  final EmailMetadata emailMetadata;
  final EmailDetailFetch emailDetail;
  final VoidCallback onBack;

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage> {
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '收件人: ${widget.emailMetadata.to}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '时间: ${widget.emailMetadata.date}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text.rich(
              TextSpan(
                text: '附件:\n',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                children: widget.emailDetail.attachments.map((attachment) {
                  return TextSpan(
                    text: '$attachment\n',
                    style: const TextStyle(fontSize: 16),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.emailDetail.body,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
