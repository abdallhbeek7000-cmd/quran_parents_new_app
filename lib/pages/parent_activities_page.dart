import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';

class ParentActivitiesPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const ParentActivitiesPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ParentActivitiesPage> createState() => _ParentActivitiesPageState();
}

class _ParentActivitiesPageState extends State<ParentActivitiesPage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "دعوات الرحلات والأنشطة 🚌⚽",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 18),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)]
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('activities').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_bus_filled_rounded, size: 70, color: isDark ? accentGold.withOpacity(0.5) : primaryColor.withOpacity(0.4)),
                        const SizedBox(height: 15),
                        Text("لا توجد رحلات أو أنشطة مضافة حالياً 🎈", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : primaryColor, fontSize: 15)),
                      ],
                    ),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String targetType = data['targetType'] ?? 'all';
                  if (targetType == 'all') return true;
                  List<dynamic> targetIds = data['targetStudentIds'] ?? [];
                  return targetIds.contains(widget.studentId);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text("لا توجد دعوات نشاط خاصة بالطالب حالياً 📭", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : primaryColor, fontSize: 15)),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var data = filteredDocs[index].data() as Map<String, dynamic>;
                    String activityId = filteredDocs[index].id;

                    DateTime? deadline;
                    if (data['deadlineTimestamp'] != null) {
                      deadline = (data['deadlineTimestamp'] as Timestamp).toDate();
                    }
                    bool isExpired = deadline != null ? DateTime.now().isAfter(deadline) : false;

                    return _buildParentActivityCard(activityId, data, isExpired, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentActivityCard(String activityId, Map<String, dynamic> data, bool isExpired, bool isDark) {
    String title = data['title'] ?? 'نشاط ترفيهي';
    String details = data['details'] ?? '';
    String imageUrl = data['imageUrl'] ?? '';
    String eventDateTime = data['eventDateTime'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isExpired
                  ? (isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50.withOpacity(0.8))
                  : (isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isExpired ? Colors.redAccent.withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.75)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isExpired ? Colors.redAccent : (isDark ? Colors.white : primaryColor),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpired ? Colors.redAccent : Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isExpired ? "انتهاء المهلة 🔴" : "نشط 🟢",
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("موعد الانطلاق: $eventDateTime", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? accentGold : primaryColor)),
                      const SizedBox(height: 8),
                      Text(details, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
                      const SizedBox(height: 15),
                      Divider(color: isDark ? Colors.white12 : Colors.black12),

                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('activities').doc(activityId).collection('responses').doc(widget.studentId).snapshots(),
                        builder: (context, resSnap) {
                          String currentStatus = 'pending';
                          if (resSnap.hasData && resSnap.data!.exists) {
                            var rData = resSnap.data!.data() as Map<String, dynamic>?;
                            currentStatus = rData?['status'] ?? 'pending';
                          }

                          if (isExpired) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                currentStatus == 'approved'
                                    ? "تم تسجيل موافقتك مسبقاً ✅"
                                    : (currentStatus == 'rejected' ? "تم تسجيل الاعتذار مسبقاً ❌" : "انتهت مهلة تحديد الموقف للأسف ⏳"),
                                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : Colors.red.shade800, fontSize: 12),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              if (currentStatus != 'pending')
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    currentStatus == 'approved' ? "موقفك الحالي: تمت الموافقة ✅" : "موقفك الحالي: تم الاعتذار ❌",
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: currentStatus == 'approved' ? Colors.green : Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: currentStatus == 'approved' ? Colors.green : Colors.green.withOpacity(0.2),
                                        elevation: currentStatus == 'approved' ? 3 : 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _updateResponse(activityId, title, 'approved', isDark),
                                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      label: Text(
                                        "موافق ✅",
                                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: currentStatus == 'approved' ? Colors.white : Colors.green, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: currentStatus == 'rejected' ? Colors.redAccent : Colors.redAccent.withOpacity(0.2),
                                        elevation: currentStatus == 'rejected' ? 3 : 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _updateResponse(activityId, title, 'rejected', isDark),
                                      icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                                      label: Text(
                                        "اعتذار ❌",
                                        style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: currentStatus == 'rejected' ? Colors.white : Colors.redAccent, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
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
  }

  // 🔔 🚀 أداة إظهار التنبيه الزجاجي الانسيابي من أعلى الشاشة
  void _showTopBannerToast({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : primaryColor,
                                  ),
                                ),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black87,
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
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // إزالة التنبيه تلقائياً بعد 3 ثوانٍ
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  Future<void> _updateResponse(String activityId, String activityTitle, String status, bool isDark) async {
    try {
      await FirebaseFirestore.instance.collection('activities').doc(activityId).collection('responses').doc(widget.studentId).set({
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      try {
        final managerQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'manager')
            .get();

        String statusText = status == 'approved' ? "الموافقة على المشاركة ✅" : "الاعتذار عن المشاركة ❌";
        String notifyTitle = "🚌 رد جديد على نشاط: $activityTitle";
        String notifyBody = "أفاد ولي أمر الطالب (${widget.studentName}) بـ $statusText في النشاط/الرحلة.";

        for (var managerDoc in managerQuery.docs) {
          NotificationService.sendAndSaveNotification(
            studentId: managerDoc.id,
            title: notifyTitle,
            body: notifyBody,
            type: "activity_response_update",
            context: context,
          ).catchError((e) => print("فشل إرسال إشعار المدير: $e"));
        }
      } catch (e) {
        print("خطأ أثناء استعلام المدراء للإشعار: $e");
      }

      if (!mounted) return;

      // 🚀 إظهار الإشعار العلوي الأنيق
      _showTopBannerToast(
        context: context,
        title: status == 'approved' ? "تم القبول بنجاح! 🎉" : "تم تسليط الاعتذار 👍",
        message: status == 'approved'
            ? "تم تسجيل موافقتك على المشاركة وإرسال إشعار للإدارة."
            : "تم توثيق الاعتذار عن المشاركة وإشعار الإدارة.",
        icon: status == 'approved' ? Icons.check_circle_rounded : Icons.info_rounded,
        color: status == 'approved' ? Colors.green : Colors.orangeAccent,
        isDark: isDark,
      );

    } catch (e) {
      if (!mounted) return;
      _showTopBannerToast(
        context: context,
        title: "خطأ في الإرسال ⚠️",
        message: "تعذر تحديث الرد، حاول مجدداً: $e",
        icon: Icons.error_outline_rounded,
        color: Colors.redAccent,
        isDark: isDark,
      );
    }
  }
}