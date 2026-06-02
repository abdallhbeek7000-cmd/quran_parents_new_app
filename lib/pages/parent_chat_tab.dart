import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  String get chatId => "${widget.studentId}_${widget.supervisorId}";

  @override
  void initState() {
    super.initState();
    _clearUnreadBadge();
  }

  // 🎯 تصفير العداد بمجرد أن يفتح الأهل المحادثة
  void _clearUnreadBadge() async {
    if (widget.supervisorId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadByParent': 0,
      }).catchError((e) => print("لم يتم العثور على محادثة سابقة لتصفير العداد."));
    }
  }

  // 🎯 دالة تنسيق الوقت
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

    // 1. حفظ الرسالة في قاعدة البيانات مع حقل التفاعلات
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': widget.studentId,
      'senderType': 'parent',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {}, // 🚀 تجهيز حقل التفاعلات
    });

    // 2. تحديث بيانات المحادثة الأساسية (وزيادة عداد المشرف)
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

    // 3. إرسال الإشعار للمشرف
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

  // 🚀 دالة إظهار قائمة التفاعلات (الإيموجي) الزجاجية للأهل عند الضغط المطول
  void _showReactionMenu(BuildContext context, String messageId) {
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.only(bottom: 30, left: 20, right: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xff1e293b).withOpacity(0.8) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: widget.isDarkMode ? Colors.white24 : Colors.white, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        // 🚀 حفظ تفاعل الأهل باسمهم
                        FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .collection('messages')
                            .doc(messageId)
                            .set({
                          'reactions': {
                            widget.studentId: emoji 
                          }
                        }, SetOptions(merge: true));
                        Navigator.pop(context);
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      }
    );
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
        // 💬 رسالة ترحيبية زجاجية بالعلوي
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

        // 📝 منطقة عرض الرسائل
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
                      final msgDoc = messages[index];
                      final msg = msgDoc.data() as Map<String, dynamic>;
                      final isMe = msg['senderType'] == 'parent';
                      final String timeString = _formatTime(msg['timestamp'] as Timestamp?);

                      // 🚀 قراءة التفاعلات إن وجدت
                      final Map<String, dynamic> reactions = msg['reactions'] ?? {};
                      final List<String> displayEmojis = reactions.values.map((e) => e.toString()).toSet().toList();

                      return Align(
                        alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 22), // مسافة إضافية لتتسع للتفاعل
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 🚀 فقاعة الرسالة (مع GestureDetector للضغطة المطولة)
                              GestureDetector(
                                onLongPress: () => _showReactionMenu(context, msgDoc.id),
                                child: Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(widget.isDarkMode ? 0.2 : 0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(22),
                                      topRight: const Radius.circular(22),
                                      bottomLeft: Radius.circular(isMe ? 5 : 22),
                                      bottomRight: Radius.circular(isMe ? 22 : 5),
                                    ),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isMe 
                                                ? [primaryColor.withOpacity(0.85), primaryColor.withOpacity(0.7)] 
                                                : (widget.isDarkMode ? [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)] : [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)]),
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(
                                            color: isMe 
                                                ? Colors.white.withOpacity(0.25) 
                                                : (widget.isDarkMode ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.8)),
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
                                                fontSize: 14.5,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  timeString,
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isMe ? Colors.white70 : (widget.isDarkMode ? Colors.white54 : Colors.black54),
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 5),
                                                  Icon(
                                                    Icons.done_all_rounded,
                                                    size: 15,
                                                    color: isReadBySupervisor ? (widget.isDarkMode ? goldColor : Colors.lightBlueAccent) : Colors.white38,
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
                              
                              // 🚀 شارة التفاعل (تظهر فقط إذا كان هناك تفاعل)
                              if (displayEmojis.isNotEmpty)
                                Positioned(
                                  bottom: -14,
                                  left: isMe ? 15 : null,
                                  right: isMe ? null : 15,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: widget.isDarkMode ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: widget.isDarkMode ? Colors.white24 : Colors.grey.shade300, width: 1.2),
                                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                        ),
                                        child: Text(
                                          displayEmojis.join(' '), 
                                          style: const TextStyle(fontSize: 14),
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
            }
          ),
        ),

        // ⌨️ كبسولة إدخال النص العائمة
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