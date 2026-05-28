import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatelessWidget {
  final String studentId;

  const NotificationsPage({super.key, required this.studentId});

  final Color primaryColor = const Color(0xff425c75);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text(
          "مركز التنبيهات والإشعارات",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب الإشعارات الخاصة بالطالب مرتبة من الأحدث للأقدم
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notification_important_outlined, size: 70, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    "صندوق التنبيهات فارغ حالياً",
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notify = notifications[index].data() as Map<String, dynamic>;
              final String title = notify['title'] ?? 'تنبيه جديد';
              final String body = notify['body'] ?? '';
              final String type = notify['type'] ?? 'regular';
              
              // تحويل التايم-ستامب لوقت مقروء
              final Timestamp? ts = notify['timestamp'] as Timestamp?;
              final String timeStr = ts != null 
                  ? "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')} - ${ts.toDate().day}/${ts.toDate().month}"
                  : "";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getNotifyColor(type).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getNotifyIcon(type), color: _getNotifyColor(type), size: 22),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.black87, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeStr,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // دالة ذكية لتحديد لون الأيقونة حسب نوع الإشعار
  Color _getNotifyColor(String type) {
    switch (type) {
      case 'absent': return Colors.red;
      case 'exam': return Colors.teal;
      case 'honor': return const Color(0xffD4AF37);
      default: return primaryColor;
    }
  }

  // دالة ذكية لتحديد شكل الأيقونة حسب نوع الإشعار
  IconData _getNotifyIcon(String type) {
    switch (type) {
      case 'absent': return Icons.cancel_rounded;
      case 'exam': return Icons.workspace_premium_rounded;
      case 'honor': return Icons.military_tech_rounded;
      default: return Icons.star_rounded;
    }
  }
}