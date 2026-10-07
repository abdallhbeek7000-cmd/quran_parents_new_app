import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/notification_service.dart';

class ParentChatTab extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String supervisorId;
  final String supervisorName;
  final bool isDarkMode;

  const ParentChatTab({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
    required this.isDarkMode,
  });

  @override
  State<ParentChatTab> createState() => _ParentChatTabState();
}

class _ParentChatTabState extends State<ParentChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);
  final Color parentBubbleColor = const Color(0xff3b82f6);

  String get chatId => "${widget.studentId}_${widget.supervisorId}";

  @override
  void initState() {
    super.initState();
    _clearUnreadBadge();
  }

  void _clearUnreadBadge() async {
    if (widget.supervisorId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadByParent': 0,
      }).catchError((e) => print("لم يتم العثور على محادثة سابقة لتصفير العداد."));
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'م' : 'ص';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.supervisorId.isEmpty) return;

    _messageController.clear();
    _scrollToBottom();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': widget.studentId,
      'senderType': 'parent',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'studentId': widget.studentId,
      'studentName': widget.studentName,
      'supervisorId': widget.supervisorId,
      'supervisorName': widget.supervisorName,
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderType': 'parent',
      'unreadBySupervisor': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (mounted) {
      await NotificationService.sendAndSaveNotification(
        studentId: widget.supervisorId,
        title: "💬 رسالة من ولي أمر (${widget.studentName})",
        body: text,
        type: "chat",
        context: context,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showReactionMenu(BuildContext context, String messageId) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 30, left: 25, right: 25),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xff1e293b).withOpacity(0.85)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: widget.isDarkMode ? Colors.white24 : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 25,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .collection('messages')
                            .doc(messageId)
                            .set({
                          'reactions': {widget.studentId: emoji}
                        }, SetOptions(merge: true));
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.supervisorId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 60, color: widget.isDarkMode ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              "عذراً، لم يتم تعيين مشرف لهذا الطالب بعد.",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      children: [
        // 🌟 1. ترويسة معلومات المشرف المصممة مع الصورة الشخصية (بدون شارة متصل)
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(widget.supervisorId).get(),
          builder: (context, supervisorSnap) {
            String imageUrl = '';
            if (supervisorSnap.hasData && supervisorSnap.data!.exists) {
              var supData = supervisorSnap.data!.data() as Map<String, dynamic>;
              imageUrl = supData['imageUrl'] ?? supData['photoUrl'] ?? supData['image'] ?? '';
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.isDarkMode
                            ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)]
                            : [Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: widget.isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.8),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        // 📸 عرض صورة المشرف الشخصية مع لمسة زجاجية وإطار ذهبي
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: goldColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: goldColor.withOpacity(0.25),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23),
                            child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (c, u) => const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
                                    errorWidget: (c, u, e) => _buildFallbackAvatar(widget.supervisorName),
                                  )
                                : _buildFallbackAvatar(widget.supervisorName),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "المشرف المتابع",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode ? goldColor : primaryColor.withOpacity(0.8),
                                ),
                              ),
                              Text(
                                widget.supervisorName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Cairo',
                                  color: widget.isDarkMode ? Colors.white : primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // 💬 2. منطقة عرض الشات
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
            builder: (context, chatSnapshot) {
              bool isReadBySupervisor = false;
              if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                isReadBySupervisor = (chatData['unreadBySupervisor'] ?? 0) == 0;
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 50, color: widget.isDarkMode ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 10),
                          Text(
                            "لا توجد رسائل سابقة.\nابدأ التواصل مع المشرف الآن!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msgDoc = messages[index];
                      final msg = msgDoc.data() as Map<String, dynamic>;
                      final isMe = msg['senderType'] == 'parent';
                      final String timeString = _formatTime(msg['timestamp'] as Timestamp?);

                      final Map<String, dynamic> reactions = msg['reactions'] ?? {};
                      final List<String> displayEmojis = reactions.values.map((e) => e.toString()).toSet().toList();

                      return Align(
                        alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onLongPress: () => _showReactionMenu(context, msgDoc.id),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(22),
                                      topRight: const Radius.circular(22),
                                      bottomLeft: Radius.circular(isMe ? 6 : 22),
                                      bottomRight: Radius.circular(isMe ? 22 : 6),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isMe 
                                            ? parentBubbleColor.withOpacity(0.25)
                                            : Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(22),
                                      topRight: const Radius.circular(22),
                                      bottomLeft: Radius.circular(isMe ? 6 : 22),
                                      bottomRight: Radius.circular(isMe ? 22 : 6),
                                    ),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                                        decoration: BoxDecoration(
                                          gradient: isMe
                                              ? LinearGradient(
                                                  colors: [
                                                    parentBubbleColor,
                                                    const Color(0xff2563eb),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : LinearGradient(
                                                  colors: widget.isDarkMode
                                                      ? [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)]
                                                      : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.75)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                          border: Border.all(
                                            color: isMe
                                                ? Colors.white.withOpacity(0.3)
                                                : (widget.isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.8)),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              msg['text'] ?? '',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                color: isMe ? Colors.white : (widget.isDarkMode ? Colors.white : Colors.black87),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  timeString,
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isMe
                                                        ? Colors.white70
                                                        : (widget.isDarkMode ? Colors.white54 : Colors.black45),
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.done_all_rounded,
                                                    size: 14,
                                                    color: isReadBySupervisor
                                                        ? goldColor
                                                        : Colors.white38,
                                                  ),
                                                ]
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              if (displayEmojis.isNotEmpty)
                                Positioned(
                                  bottom: -12,
                                  left: isMe ? 12 : null,
                                  right: isMe ? null : 12,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: widget.isDarkMode
                                              ? const Color(0xff1e293b).withOpacity(0.9)
                                              : Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(
                                            color: widget.isDarkMode ? Colors.white24 : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                                          ],
                                        ),
                                        child: Text(
                                          displayEmojis.join(' '),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // ⌨️ 3. كبسولة الإدخال العائمة
        Container(
          margin: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 4,
            bottom: isKeyboardOpen ? 12 : 95,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xff1e293b).withOpacity(0.8)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: widget.isDarkMode ? Colors.white24 : Colors.white,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          color: widget.isDarkMode ? Colors.white : Colors.black87,
                          fontFamily: 'Cairo',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: "اكتب رسالتك للمشرف...",
                          hintStyle: TextStyle(
                            color: widget.isDarkMode ? Colors.white54 : Colors.grey.shade500,
                            fontFamily: 'Cairo',
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [goldColor, const Color(0xffb89628)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: goldColor.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return Container(
      color: primaryColor.withOpacity(0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1) : '?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? goldColor : primaryColor,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}