import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'login_page.dart';
import 'update_checker.dart'; // تأكد أن ملف الـ Checker بنفس المجلد

class ParentHomePage extends StatefulWidget {
  final DocumentSnapshot student;

  const ParentHomePage({super.key, required this.student});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  List<Map<String, dynamic>> allWinners = [];
  Map<String, String> studentImagesCache = {};
  bool _isHonorLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHonorBoardAndImages();
    _saveDeviceToken(); 
    
    // تشغيل فحص التحديث أوتوماتيكياً بأمان بعد بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
  }

  void _saveDeviceToken() async {
    try {
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await FirebaseMessaging.instance.getToken();
        
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('students')
              .doc(widget.student.id)
              .update({'fcmToken': token});
              
          print("FCM Token saved successfully: $token ✅");
        }
      }
    } catch (e) {
      print("Error saving FCM token: $e");
    }
  }

  void _loadHonorBoardAndImages() async {
    try {
      final honorSnapshot = await FirebaseFirestore.instance.collection('honor_board').get();
      List<Map<String, dynamic>> winners = [];
      
      for (var doc in honorSnapshot.docs) {
        var d = doc.data();
        if (d['first'] != null && d['first']['name'] != "لم يحدد") winners.add(d['first']);
        if (d['second'] != null && d['second']['name'] != "لم يحدد") winners.add(d['second']);
        if (d['third'] != null && d['third']['name'] != "لم يحدد") winners.add(d['third']);
      }

      Map<String, String> tempCache = {};
      for (var winner in winners) {
        var rawSerial = winner['serial'];
        int? serialAsInt = int.tryParse(rawSerial?.toString() ?? '');
        String winnerSerialStr = rawSerial?.toString() ?? '';

        final studentQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('serial', isEqualTo: serialAsInt ?? winnerSerialStr)
            .limit(1)
            .get();

        if (studentQuery.docs.isNotEmpty) {
          var studentData = studentQuery.docs.first.data();
          tempCache[winnerSerialStr] = studentData['imageUrl']?.toString() ?? '';
        }
      }

      if (mounted) {
        setState(() {
          allWinners = winners;
          studentImagesCache = tempCache;
          _isHonorLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isHonorLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.student.data() as Map<String, dynamic>;
    final String studentId = widget.student.id;
    final String studentName = data['name'] ?? 'الطالب';
    final String serialStr = data['serial']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(
          'متابعة الطالب: $studentName', 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من بوابة المتابعة؟'),
                    actions: [
                      TextButton(
                        child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: const Text('خروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          final SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.remove('saved_student_serial');

                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('studentId', isEqualTo: studentId)
            .snapshots(),
        builder: (context, sessionSnapshot) {
          int totalSessions = 0;
          int absentCount = 0;
          int excellentCount = 0;
          int goodCount = 0;
          int badCount = 0;
          List<QueryDocumentSnapshot> sortedDocs = [];

          if (sessionSnapshot.hasData) {
            var docs = sessionSnapshot.data!.docs;
            totalSessions = docs.length;
            
            for (var doc in docs) {
              var sData = doc.data() as Map<String, dynamic>;
              bool isAbsent = sData['absent'] ?? false;
              
              String rValue = sData['memorizationRating']?.toString() ?? sData['rating']?.toString() ?? '';

              if (isAbsent) {
                absentCount++;
              } else {
                if (rValue == 'ممتاز' || rValue == 'جيد جداً') excellentCount++;
                if (rValue == 'جيد' || rValue == 'مقبول') goodCount++;
                if (rValue == 'سيء' || rValue == 'ضعيف') badCount++;
              }
            }

            sortedDocs = List.from(docs);
            sortedDocs.sort((a, b) {
              String aDate = (a.data() as Map<String, dynamic>)['date']?.toString() ?? '';
              String bDate = (b.data() as Map<String, dynamic>)['date']?.toString() ?? '';
              return bDate.compareTo(aDate);
            });
          }

          int presentCount = totalSessions - absentCount;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildProfileCard(data)),
              
              SliverToBoxAdapter(child: _buildQuranProgressSection(sessionSnapshot)),
              
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text("📊 الملخص العام لأداء الطالب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildParentStatsDashboard(
                  total: totalSessions,
                  present: presentCount,
                  absent: absentCount,
                  excellent: excellentCount,
                  good: goodCount,
                  bad: badCount,
                ),
              ),
              
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text("🏆 لوحة الشرف والتميز", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              SliverToBoxAdapter(child: _buildHonorBoardSection(serialStr)),
              
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(right: 20, left: 20, top: 25, bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.blue),
                      SizedBox(width: 10),
                      Text("سجل الحفظ والمراجعة اليومي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              
              if (sessionSnapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())))
              else if (sortedDocs.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text("لا يوجد جلسات مسجلة بعد لهذا الطالب", style: TextStyle(color: Colors.grey[600])),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var session = sortedDocs[index].data() as Map<String, dynamic>;
                      return _buildSessionItem(session);
                    },
                    childCount: sortedDocs.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
      ),
      child: Row(
        children: [
          _buildStudentAvatar(data['imageUrl'] ?? '', data['name'] ?? '?'),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                Text('الرقم التسلسلي: ${data['serial']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text('المرحلة الدراسية: ${data['schoolGrade'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentStatsDashboard({
    required int total,
    required int present,
    required int absent,
    required int excellent,
    required int good,
    required int bad,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: "الحضور والالتزام",
                  value: "$present من أصل $total",
                  subtitle: "جلسة حلقة حية",
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  title: "أيام الغياب",
                  value: "$absent جلسات",
                  subtitle: absent >= 3 ? "تنبيه غياب متكرر! ⚠️" : "ضمن الحد الطبيعي",
                  icon: Icons.cancel_rounded,
                  color: absent >= 3 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: "مستوى ممتاز",
                  value: "$excellent مرات",
                  subtitle: "حفظ متقن ومميز 🌟",
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xffD4AF37),
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  title: "مستوى جيد",
                  value: "$good مرات",
                  subtitle: "أداء مستقر وثابت",
                  icon: Icons.thumb_up_rounded, 
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  title: "يحتاج متابعة",
                  value: "$bad مرات",
                  subtitle: "يتطلب تكرار وتثبيت",
                  icon: Icons.trending_down_rounded,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              Icon(icon, color: color.withOpacity(0.8), size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 9, color: color == Colors.red ? Colors.red : Colors.grey[500], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildQuranProgressSection(AsyncSnapshot<QuerySnapshot> sessionSnapshot) {
    double savedPages = 0.0;

    if (sessionSnapshot.hasData && sessionSnapshot.data!.docs.isNotEmpty) {
      var sessionDocs = sessionSnapshot.data!.docs;
      List<QueryDocumentSnapshot> sortedSessions = List.from(sessionDocs)
        ..retainWhere((doc) {
          var s = doc.data() as Map<String, dynamic>;
          return (s['absent'] == false && s['isExam'] == false);
        });
        
      sortedSessions.sort((a, b) {
        String aDate = (a.data() as Map<String, dynamic>)['date']?.toString() ?? '';
        String bDate = (b.data() as Map<String, dynamic>)['date']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      for (var doc in sortedSessions) {
        var sData = doc.data() as Map<String, dynamic>;
        if (sData.containsKey('total_memorized_pages') && sData['total_memorized_pages'] != null) {
          savedPages = (sData['total_memorized_pages'] as num).toDouble();
          break;
        }
      }
    }

    double totalQuranPages = 604.0;
    double remainingPages = (totalQuranPages - savedPages).clamp(0.0, totalQuranPages);
    double progressPercentage = (savedPages / totalQuranPages).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                "مستوى تقدم الطالب في الختمة 👑",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "تم تمكين $savedPages من أصل 604 صفحة",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "${(progressPercentage * 100).toStringAsFixed(1)}%",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressPercentage,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red.shade400, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remainingPages == 0 
                        ? "مبارك! ابنكم ختم كتاب الله كاملاً، هنيئاً لكم تاج الوقار 🎉👑"
                        : "متبقي للطالب [ ${remainingPages.toStringAsFixed(0)} صفحة ] ويختم كتاب الله كاملاً ✨",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHonorBoardSection(String currentStudentSerial) {
    if (_isHonorLoading) {
      return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
    }
    if (allWinners.isEmpty) {
      return const SizedBox(height: 140, child: Center(child: Text("سيتم إعلان النجوم قريباً", style: TextStyle(fontSize: 13, color: Colors.grey))));
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: allWinners.length,
        itemBuilder: (context, index) {
          var winner = allWinners[index];
          String winnerSerialStr = winner['serial']?.toString() ?? '';
          String winnerName = winner['name'] ?? '';
          bool isCurrent = (winnerSerialStr == currentStudentSerial && currentStudentSerial.isNotEmpty);
          String finalImageUrl = studentImagesCache[winnerSerialStr] ?? '';

          return Container(
            width: 110,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrent ? goldColor.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: isCurrent ? Border.all(color: goldColor, width: 1.5) : null,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: goldColor.withOpacity(0.5), width: 2),
                    color: primaryColor.withOpacity(0.1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: finalImageUrl.isNotEmpty && finalImageUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: finalImageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
                            errorWidget: (context, url, error) => Center(
                              child: Text(winnerName.isNotEmpty ? winnerName.substring(0, 1) : '?', style: TextStyle(fontSize: 20, color: primaryColor, fontWeight: FontWeight.bold)),
                            ),
                          )
                        : Center(
                            child: Text(winnerName.isNotEmpty ? winnerName.substring(0, 1) : '?', style: TextStyle(fontSize: 20, color: primaryColor, fontWeight: FontWeight.bold)),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  winnerName, 
                  textAlign: TextAlign.center, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis, 
                  style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                ),
                Text(
                  isCurrent ? "👑 ابنكم متميز" : "🏆 متميز", 
                  style: TextStyle(fontSize: 10, color: isCurrent ? goldColor : Colors.orange, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final String sessionDate = session['date']?.toString() ?? 'بدون تاريخ';
    final bool isAbsent = session['absent'] ?? false;
    final bool isExam = session['isExam'] ?? false; 

    if (isAbsent) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: const Border(right: BorderSide(color: Colors.red, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sessionDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                  child: const Text("غائب ❌", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildSessionDetail(Icons.warning_amber_rounded, "نوع الغياب:", session['absenceType'] == "" ? "بدون عذر" : (session['absenceType'] ?? 'بدون عذر')),
            if (session['absenceReason'] != null && session['absenceReason'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSessionDetail(Icons.info_outline, "سبب الغياب:", session['absenceReason']),
            ],
            if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
              const Divider(height: 20),
              Text("📝 ملاحظة المشرف: ${session['notes']}", style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      );
    }

    if (isExam) {
      int score = int.tryParse(session['examScore']?.toString() ?? '0') ?? 0;
      
      Color examMainColor = Colors.green; 
      Color bgColor = Colors.green.shade50;
      Color textColor = Colors.green.shade900; 

      if (score >= 0 && score <= 50) {
        examMainColor = Colors.red; 
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade900; 
      } else if (score >= 51 && score <= 79) {
        examMainColor = Colors.orange; 
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade900; 
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border(right: BorderSide(color: examMainColor, width: 4)), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sessionDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: examMainColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text("جلسة اختبار 📝", style: TextStyle(color: examMainColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
              decoration: BoxDecoration(
                color: bgColor, 
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: examMainColor.withOpacity(0.2), width: 1)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium, color: examMainColor, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "نتيجة اختبار ابنكم في هذه الجلسة",
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$score / 100",
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold, 
                          color: textColor 
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
              const Divider(height: 20),
              Text("📝 ملاحظة المشرف: ${session['notes']}", style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      );
    }

    String memRating = session['memorizationRating'] ?? session['rating'] ?? "جيد";
    if (memRating.isEmpty) memRating = "جيد";
    
    String revRating = session['reviewRating'] ?? session['rating'] ?? "جيد";
    if (revRating.isEmpty) revRating = "جيد";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(right: BorderSide(color: primaryColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sessionDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              Row(
                children: [
                  _buildGradeBadge("حفظ: $memRating", memRating),
                  const SizedBox(width: 4),
                  _buildGradeBadge("مراجعة: $revRating", revRating),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          _buildSessionDetail(Icons.star, "الحفظ الجديد:", session['newMemorization'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.menu_book, "مراجعة جديد:", session['nearReview'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.history_toggle_off, "مراجعة قديم:", session['farReview'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.chrome_reader_mode_outlined, "قراءة نظراً:", session['readingBySight'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.assignment_outlined, "الواجب المعطى:", session['homework'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.emoji_emotions_outlined, "حالة الطالب:", session['studentStatus'] ?? 'مهذب'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.brightness_auto_outlined, "الأنشطة الدينية بالمسجد:", session['religiousActivities'] ?? '---'),
          
          if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
            const Divider(height: 20),
            Text("📝 ملاحظة المشرف للأهل: ${session['notes']}", style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );
  }

  Widget _buildSessionDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        const SizedBox(width: 5),
        Expanded(child: Text(value.toString(), style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
      ],
    );
  }

  Widget _buildGradeBadge(String label, String ratingValue) {
    Color badgeColor = Colors.green;
    if (ratingValue == 'جيد جداً' || ratingValue == 'جيد') badgeColor = Colors.orange;
    if (ratingValue == 'مقبول' || ratingValue == 'ضعيف' || ratingValue == 'سيء') badgeColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildStudentAvatar(String url, String name) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withOpacity(0.1)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url, 
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: TextStyle(fontSize: 24, color: primaryColor, fontWeight: FontWeight.bold))),
              )
            : Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: TextStyle(fontSize: 24, color: primaryColor, fontWeight: FontWeight.bold))),
      ),
    );
  }
}