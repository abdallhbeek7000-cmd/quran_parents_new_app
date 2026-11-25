import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج البلوري (Blur)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider
import 'parent_chat_tab.dart'; // 🎯 تأكد من مطابقة اسم ملف ParentChatTab لديك

class NotificationsPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String supervisorId;
  final String supervisorName;

  /// اختياري: إذا كانت صفحتك الرئيسية تملك تبويبات، مرّر هذه الدالة لتبديل التبويب إلى الرسائل
  final void Function({
    String? chatId,
    String? targetId,
    bool? isSupervisor,
  })? onOpenChatTab;

  NotificationsPage({
    super.key,
    required this.studentId,
    this.studentName = '',
    this.supervisorId = '',
    this.supervisorName = 'المشرف',
    this.onOpenChatTab,
  });

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  bool _isChatNotification(Map<String, dynamic> notify) {
    final type = (notify['type'] ?? '').toString().toLowerCase();
    final tab = (notify['tab'] ?? '').toString().toLowerCase();
    return type == 'chat' ||
        type == 'message' ||
        tab == 'chat' ||
        (notify['chatId']?.toString().isNotEmpty ?? false);
  }

  String _buildPeerChatId(String otherId) {
    final ids = [studentId, otherId]..sort();
    return 'peer_${ids[0]}_${ids[1]}';
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> notify,
    bool isDarkMode,
  ) async {
    if (!_isChatNotification(notify)) return;

    final String rawChatId = (notify['chatId'] ?? '').toString().trim();
    final String senderId = (notify['senderId'] ??
            notify['fromId'] ??
            notify['targetId'] ??
            '')
        .toString()
        .trim();
    final String senderName =
        (notify['senderName'] ?? notify['fromName'] ?? '').toString().trim();
    final String senderType =
        (notify['senderType'] ?? '').toString().toLowerCase();

    final bool isSupervisor = notify['isSupervisor'] == true ||
        notify['isSupervisor'].toString() == 'true' ||
        senderType == 'supervisor' ||
        (supervisorId.isNotEmpty && senderId == supervisorId);

    String resolvedChatId = rawChatId;
    if (resolvedChatId.isEmpty) {
      if (isSupervisor && supervisorId.isNotEmpty) {
        resolvedChatId = '${studentId}_$supervisorId';
      } else if (senderId.isNotEmpty) {
        resolvedChatId = _buildPeerChatId(senderId);
      }
    }

    if (onOpenChatTab != null) {
      Navigator.pop(context);
      onOpenChatTab!(
        chatId: resolvedChatId.isNotEmpty ? resolvedChatId : null,
        targetId: senderId.isNotEmpty ? senderId : null,
        isSupervisor: isSupervisor,
      );
      return;
    }

    // جلب بيانات الطالب/المشرف إذا لم تكن ممررة بالكامل
    String resolvedStudentName = studentName;
    String resolvedSupervisorId = supervisorId;
    String resolvedSupervisorName = supervisorName;

    if (resolvedStudentName.isEmpty || resolvedSupervisorId.isEmpty) {
      try {
        final stuDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get();
        if (stuDoc.exists) {
          final sData = stuDoc.data() as Map<String, dynamic>;
          if (resolvedStudentName.isEmpty) {
            resolvedStudentName = (sData['name'] ?? '').toString();
          }
          if (resolvedSupervisorId.isEmpty) {
            resolvedSupervisorId = (sData['supervisorId'] ?? '').toString();
          }
          if ((sData['supervisorName'] ?? '').toString().isNotEmpty) {
            resolvedSupervisorName = sData['supervisorName'].toString();
          }
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DirectChatHostPage(
          studentId: studentId,
          studentName: resolvedStudentName,
          supervisorId: resolvedSupervisorId,
          supervisorName: resolvedSupervisorName,
          isDarkMode: isDarkMode,
          initialChatId: resolvedChatId.isNotEmpty ? resolvedChatId : null,
          initialTargetId: senderId.isNotEmpty
              ? senderId
              : (isSupervisor ? resolvedSupervisorId : null),
          initialTargetName: senderName.isNotEmpty ? senderName : null,
          initialIsSupervisor: isSupervisor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "مركز التنبيهات والإشعارات",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : primaryColor,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        iconTheme:
            IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        const Color(0xff0f172a),
                        const Color(0xff1e293b),
                        const Color(0xff0f172a)
                      ]
                    : [
                        const Color(0xffe2e8f0),
                        const Color(0xffcfdef3),
                        const Color(0xffe0eafc)
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -20,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? accentGold.withOpacity(0.08)
                    : accentGold.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? primaryColor.withOpacity(0.15)
                    : primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .doc(studentId)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: _buildGlassContainer(
                      isDarkMode: isDarkMode,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 50),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notification_important_outlined,
                            size: 70,
                            color: isDarkMode
                                ? accentGold.withOpacity(0.6)
                                : primaryColor.withOpacity(0.4),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "صندوق التنبيهات فارغ حالياً",
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final notify = doc.data() as Map<String, dynamic>;
                    final String title = notify['title'] ?? 'تنبيه جديد';
                    final String body = notify['body'] ?? '';
                    final String type = notify['type'] ?? 'regular';
                    final bool isChat = _isChatNotification(notify);

                    final Timestamp? ts = notify['timestamp'] as Timestamp?;
                    final String timeStr = ts != null
                        ? "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')} - ${ts.toDate().day}/${ts.toDate().month}"
                        : "";

                    Color notifyColor = _getNotifyColor(type, isDarkMode);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: GestureDetector(
                        onTap: () async {
                          // تعليم الإشعار كمقروء عند الضغط عليه
                          doc.reference
                              .set({'isRead': true}, SetOptions(merge: true))
                              .catchError((_) {});
                          await _handleNotificationTap(
                              context, notify, isDarkMode);
                        },
                        child: _buildGlassContainer(
                          isDarkMode: isDarkMode,
                          customBorderColor: notifyColor
                              .withOpacity(isDarkMode ? 0.35 : 0.45),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: notifyColor
                                    .withOpacity(isDarkMode ? 0.2 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getNotifyIcon(type),
                                  color: notifyColor, size: 24),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDarkMode
                                          ? Colors.white
                                          : primaryColor,
                                    ),
                                  ),
                                ),
                                if (isChat)
                                  Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 14,
                                    color: isDarkMode
                                        ? accentGold
                                        : primaryColor.withOpacity(0.7),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  body,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        color: isDarkMode
                                            ? Colors.white38
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isChat)
                                      Text(
                                        "اضغط لفتح المحادثة",
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? accentGold
                                              : primaryColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
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
        ],
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    required bool isDarkMode,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Color? customColor,
    Color? customBorderColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ??
                (isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: customBorderColor ??
                  (isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.6)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Color _getNotifyColor(String type, bool isDarkMode) {
    switch (type) {
      case 'chat':
      case 'message':
        return accentGold;
      case 'absent':
        return Colors.redAccent;
      case 'exam':
        return isDarkMode ? Colors.tealAccent : Colors.teal;
      case 'honor':
        return accentGold;
      default:
        return isDarkMode ? Colors.lightBlueAccent : Colors.blue;
    }
  }

  IconData _getNotifyIcon(String type) {
    switch (type) {
      case 'chat':
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'exam':
        return Icons.workspace_premium_rounded;
      case 'honor':
        return Icons.military_tech_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

/// صفحة مضيفة لفتح تبويب المحادثات والدخول مباشرةً إلى المحادثة المرسلة منها الرسالة
class _DirectChatHostPage extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String supervisorId;
  final String supervisorName;
  final bool isDarkMode;
  final String? initialChatId;
  final String? initialTargetId;
  final String? initialTargetName;
  final bool? initialIsSupervisor;

  const _DirectChatHostPage({
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
    required this.isDarkMode,
    this.initialChatId,
    this.initialTargetId,
    this.initialTargetName,
    this.initialIsSupervisor,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xff425c75);
    final Color accentGold = const Color(0xffcdb375);

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xff0f172a) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          initialTargetName ?? "المحادثات",
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 15.5,
            color: isDarkMode ? Colors.white : primaryColor,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDarkMode ? accentGold : primaryColor,
        ),
      ),
      body: SafeArea(
        child: ParentChatTab(
          studentId: studentId,
          studentName: studentName,
          supervisorId: supervisorId,
          supervisorName: supervisorName,
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }
}