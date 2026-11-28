import 'package:flutter/material.dart';
import '../services/auth_session.dart';

/// Header action reused across upload, list, edit, delete and image update.
class UserSessionAction extends StatelessWidget {
  const UserSessionAction({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    return PopupMenuButton<String>(
      tooltip: 'Logged in as ${session.userId ?? ''}',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (action) async {
        if (action != 'logout') return;
        await session.logout();
        if (context.mounted && session.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(session.error!)));
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(enabled: false,
          child: Text('Signed in: ${session.userId ?? ''}')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'logout', child: Row(children: [
          Icon(Icons.logout, size: 18), SizedBox(width: 10), Text('Logout'),
        ])),
      ],
    );
  }
}
