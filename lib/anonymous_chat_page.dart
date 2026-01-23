import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:messmaker_fresh/moderation/bad_words.dart';

class AnonymousChatPage extends StatefulWidget {
  final String roomId;
  final String alias;

  const AnonymousChatPage({
    super.key,
    required this.roomId,
    required this.alias,
  });

  @override
  State<AnonymousChatPage> createState() => _AnonymousChatPageState();
}

class _AnonymousChatPageState extends State<AnonymousChatPage> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  /// ✅ Keeps track of messages THIS user has already reported
  final Set<String> _reportedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anonymous Room'),
      ),
      body: Column(
        children: [
          // =========================
          // MESSAGES
          // =========================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('sentAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isMe = data['alias'] == widget.alias;

                    /// ✅ HIDE MESSAGE ONLY IF REPORTS >= 5
                    if ((data['reports'] ?? 0) >= 5) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Message hidden due to multiple reports',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['alias'],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(data['text']),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.flag,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    /// 🚫 Prevent reporting same message twice
                                    if (_reportedMessageIds.contains(doc.id)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'You have already reported this message',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    /// ✅ FIREBASE REPORTING LOGIC (UNCHANGED)
                                    await FirebaseFirestore.instance
                                        .collection('chat_rooms')
                                        .doc(widget.roomId)
                                        .collection('messages')
                                        .doc(doc.id)
                                        .update({
                                      'reports': FieldValue.increment(1),
                                      'flagged': true,
                                    });

                                    /// ✅ Mark as reported locally
                                    _reportedMessageIds.add(doc.id);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // =========================
          // MESSAGE INPUT
          // =========================
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;

                    /// 🚫 BLOCK BAD WORDS
                    if (BadWords.containsBadWords(text)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Message contains inappropriate language',
                          ),
                        ),
                      );
                      return;
                    }

                    /// ✅ FIREBASE SEND LOGIC (UNCHANGED)
                    await FirebaseFirestore.instance
                        .collection('chat_rooms')
                        .doc(widget.roomId)
                        .collection('messages')
                        .add({
                      'text': text,
                      'alias': widget.alias,
                      'sentAt': Timestamp.now(),
                      'flagged': false,
                      'reports': 0,
                    });

                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}