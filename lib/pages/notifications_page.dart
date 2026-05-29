import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج البلوري (Blur)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider

class NotificationsPage extends StatelessWidget {
  final String studentId;

  const NotificationsPage({super.key, required this.studentId});

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  Widget build(BuildContext context) {
    // قراءة المظهر الحالي للتطبيق
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🎯 تمديد الخلفية خلف الـ AppBar لجمالية الزجاج
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, // AppBar شفاف بالكامل
        title: Text(
          "مركز التنبيهات والإشعارات",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 16),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة (Blobs)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? accentGold.withOpacity(0.08) : accentGold.withOpacity(0.12)),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2)),
            ),
          ),

          // 🏢 2. المحتوى الأساسي للواجهة
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
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
                    child: _buildGlassContainer(
                      isDarkMode: isDarkMode,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notification_important_outlined, size: 70, color: isDarkMode ? accentGold.withOpacity(0.6) : primaryColor.withOpacity(0.4)),
                          const SizedBox(height: 15),
                          Text(
                            "صندوق التنبيهات فارغ حالياً",
                            style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final notifications = snapshot.data!.docs;

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

                    Color notifyColor = _getNotifyColor(type, isDarkMode);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: _buildGlassContainer(
                        isDarkMode: isDarkMode,
                        customBorderColor: notifyColor.withOpacity(isDarkMode ? 0.3 : 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: notifyColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_getNotifyIcon(type), color: notifyColor, size: 24),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: isDarkMode ? Colors.white : primaryColor),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(
                                body,
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDarkMode ? Colors.white70 : Colors.black87, height: 1.4, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                timeStr,
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDarkMode ? Colors.white38 : Colors.grey.shade600, fontWeight: FontWeight.bold),
                              ),
                            ],
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

  // 🧊 أداة مساعدة لتغليف العناصر وتأثير الزجاج (Glassmorphism)
  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)),
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

  // دالة ذكية لتحديد لون الأيقونة والإطار حسب نوع الإشعار
  Color _getNotifyColor(String type, bool isDarkMode) {
    switch (type) {
      case 'absent': return Colors.redAccent;
      case 'exam': return isDarkMode ? Colors.tealAccent : Colors.teal;
      case 'honor': return accentGold;
      default: return isDarkMode ? Colors.lightBlueAccent : Colors.blue;
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