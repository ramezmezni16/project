
import 'dart:async';

import 'package:flutter/material.dart';
import 'services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final ApiService apiService;
  final String partnerUsername;

  const ChatScreen({
    super.key,
    required this.apiService,
    required this.partnerUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  List<dynamic> messages = [];

  bool loading = true;
  bool sending = false;
  bool fetching = false;

  String? error;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();

    loadMessages();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (mounted && !loading && !sending) {
          loadMessages();
        }
      },
    );
  }

  Future<void> loadMessages({
    bool scrollToLatest = false,
  }) async {
    if (fetching) return;

    fetching = true;

    try {
      final result = await widget.apiService.get(
        '/api/auth/chat/messages/?with_user=${Uri.encodeComponent(widget.partnerUsername)}',
      );

      if (!mounted || result is! List) return;

      final wasNearBottom = !scrollController.hasClients ||
          scrollController.position.maxScrollExtent -
                  scrollController.position.pixels <
              120;

      final hadNoMessages = messages.isEmpty;

      final oldLastId = messages.isNotEmpty
          ? messages.last['id']
          : null;

      final newLastId = result.isNotEmpty
          ? result.last['id']
          : null;

      final hasNewMessages = oldLastId != newLastId;

      setState(() {
        messages = result;
        loading = false;
        error = null;
      });

      if (scrollToLatest ||
          hadNoMessages ||
          (hasNewMessages && wasNearBottom)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;

        if (messages.isEmpty) {
          error = e.toString();
        }
      });
    } finally {
      fetching = false;
    }
  }

  Future<void> sendMessage() async {
    final text = controller.text.trim();

    if (text.isEmpty || sending) return;

    setState(() {
      sending = true;
    });

    try {
      await widget.apiService.post(
        '/api/auth/chat/messages/',
        {
          'recipient': widget.partnerUsername,
          'message': text,
        },
      );

      controller.clear();

      await loadMessages(scrollToLatest: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(error!),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                loading = true;
                                error = null;
                              });

                              loadMessages();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: loadMessages,
                      child: ListView.builder(
                        controller: scrollController,
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final item = messages[index];

                          final isMine =
                              item['sender'] != widget.partnerUsername;

                          final date = DateTime.tryParse(
                            item['created_at'].toString(),
                          )?.toLocal();

                          return Align(
                            alignment: isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width *
                                        0.75,
                              ),
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFF3867D6)
                                    : const Color(0xFFE8EDF4),
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item['message']?.toString() ?? '',
                                    style: TextStyle(
                                      color: isMine
                                          ? Colors.white
                                          : const Color(0xFF17243A),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    date == null
                                        ? ''
                                        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMine
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 5000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write a message...',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : sendMessage,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
