import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String get chatId => "${widget.studentId}_${widget.supervisorId}";

  // 🎯 دالة تنسيق الوقت
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'م' : 'ص';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  Future<void> _sendNotificationToSupervisor(String messageText) async {
    try {
      final supDoc = await FirebaseFirestore.instance.collection('supervisors').doc(widget.supervisorId).get();
      if (!supDoc.exists || supDoc.data() == null) return;
      
      final token = supDoc.data()!['fcmToken'];
      if (token == null || token.toString().isEmpty) return;

      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('general').get();
      if (!settingsDoc.exists || settingsDoc.data() == null) return;

      final serverKey = settingsDoc.data()!['fcm_server_key'];
      if (serverKey == null || serverKey.toString().isEmpty) return;

      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': '💬 رسالة من ولي أمر (${widget.studentName})',
            'body': messageText,
            'sound': 'default',
          },
          'data': {
            'type': 'chat',
            'studentId': widget.studentId,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          }
        }),
      );
    } catch (e) {
      print("خطأ في إرسال إشعار المحادثة: $e");
    }
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

    _sendNotificationToSupervisor(text);
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

  @override
  Widget build(BuildContext context) {
    if (widget.supervisorId.isEmpty) {
      return Center(
        child: Text("عذراً، لم يتم تعيين مشرف لهذا الطالب بعد.", 
          style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: widget.isDarkMode ? Colors.white60 : Colors.black54)),
      );
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      children: [
        // 💬 رسالة ترحيبية زجاجية
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.isDarkMode ? Colors.white12 : Colors.white),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: goldColor.withOpacity(0.2),
                      child: Icon(Icons.support_agent_rounded, color: goldColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("أنت تتحدث مع:", style: TextStyle(fontSize: 10, fontFamily: 'Cairo', color: widget.isDarkMode ? Colors.white54 : Colors.grey.shade700)),
                          Text("المشرف ${widget.supervisorName}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: widget.isDarkMode ? Colors.white : primaryColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 📝 منطقة عرض الرسائل (بلمسة زجاجية فخمة)
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
                  child: Text("لا توجد رسائل سابقة. ابدأ المحادثة الآن!", 
                    style: TextStyle(fontFamily: 'Cairo', color: widget.isDarkMode ? Colors.white54 : Colors.black54)),
                );
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index].data() as Map<String, dynamic>;
                  final isMe = msg['senderType'] == 'parent';
                  final String timeString = _formatTime(msg['timestamp'] as Timestamp?);

                  return Align(
                    alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      // 🚀 تأثير الزجاج للرسائل تماماً مثل المشرف
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 0 : 20),
                          bottomRight: Radius.circular(isMe ? 20 : 0),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe 
                                  ? primaryColor.withOpacity(0.75) 
                                  : (widget.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7)),
                              border: Border.all(
                                color: isMe 
                                    ? Colors.white.withOpacity(0.2) 
                                    : (widget.isDarkMode ? Colors.white24 : Colors.white.withOpacity(0.8)),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Text(
                                  msg['text'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: isMe ? Colors.white : (widget.isDarkMode ? Colors.white : Colors.black87),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  timeString,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10,
                                    color: isMe ? Colors.white60 : (widget.isDarkMode ? Colors.white54 : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ⌨️ كبسولة إدخال النص العائمة (Floating Pill)
        Container(
          margin: EdgeInsets.only(
            left: 15, 
            right: 15, 
            top: 5, 
            bottom: isKeyboardOpen ? 15 : 100, 
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xff1e293b).withOpacity(0.8) : Colors.white.withOpacity(0.85),
                  border: Border.all(color: widget.isDarkMode ? Colors.white24 : Colors.white, width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black, fontFamily: 'Cairo', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "اكتب رسالتك للمشرف...",
                          hintStyle: TextStyle(color: widget.isDarkMode ? Colors.white54 : Colors.grey.shade500, fontFamily: 'Cairo', fontSize: 13),
                          filled: true,
                          fillColor: Colors.transparent, 
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: goldColor, 
                          shape: BoxShape.circle, 
                          boxShadow: [BoxShadow(color: goldColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]
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
}