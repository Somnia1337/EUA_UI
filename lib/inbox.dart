import 'package:flutter/material.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Text('敬请期待',
            style: TextStyle(
              fontSize: 20,
              fontFamily: 'Consolas',
            )),
      ),
    );
  }
}
