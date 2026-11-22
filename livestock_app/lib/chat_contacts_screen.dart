
import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'chat_screen.dart';

class ChatContactsScreen extends StatefulWidget {
  final ApiService apiService;

  const ChatContactsScreen({
    super.key,
    required this.apiService,
  });

  @override
  State<ChatContactsScreen> createState() =>
      _ChatContactsScreenState();
}

class _ChatContactsScreenState extends State<ChatContactsScreen> {
  List<dynamic> contacts = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    try {
      final result = await widget.apiService.get(
        '/api/auth/chat/contacts/',
      );

      if (!mounted) return;

      setState(() {
        contacts = result is List ? result : [];
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void openChat(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(username),
          ),
          body: ChatScreen(
            apiService: widget.apiService,
            partnerUsername: username,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadContacts,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text(error!)),
                    TextButton(
                      onPressed: loadContacts,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : contacts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: Text('No contacts available yet.'),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final contact =
                            Map<String, dynamic>.from(contacts[index]);

                        final username =
                            contact['username']?.toString() ?? '';

                        final role =
                            contact['role']?.toString() ?? '';

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(role),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: username.isEmpty
                              ? null
                              : () => openChat(username),
                        );
                      },
                    ),
    );
  }
}
