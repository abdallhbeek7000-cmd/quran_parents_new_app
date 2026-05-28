import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'login_page.dart';
import 'update_checker.dart'; 
import 'notifications_page.dart'; // 🎯 استيراد صفحة مركز التنبيهات الجديدة

class ParentHomePage extends StatefulWidget {
  final DocumentSnapshot student;

  const ParentHomePage({super.key, required this.student});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  int _currentTabIndex = 0; 

  List<Map<String, dynamic>> allWinners = [];
  Map<String, String> studentImagesCache = {};
  bool _isHonorLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHonorBoardAndImages();
    _saveDeviceToken(); 
    
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
    final bool isCompletedStudent = data['studentType'] == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc), 
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(
          _getAppBarTitle(_currentTabIndex, studentName), 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            tooltip: 'مركز التنبيهات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsPage(studentId: studentId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutDialog(),
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
              
              String memRating = sData['memorizationRating']?.toString() ?? sData['rating']?.toString() ?? '';
              String revRating = sData['reviewRating']?.toString() ?? sData['rating']?.toString() ?? '';

              if (isAbsent) {
                absentCount++;
              } else {
                if (memRating == 'ممتاز' || memRating == 'جيد جداً' || revRating == 'ممتاز' || revRating == 'جيد جداً') {
                  excellentCount++;
                } else if (memRating == 'جيد' || memRating == 'مقبول' || revRating == 'جيد' || revRating == 'مقبول') {
                  goodCount++;
                } else if (memRating == 'سيء' || memRating == 'ضعيف' || revRating == 'سيء' || revRating == 'ضعيف') {
                  badCount++;
                } else {
                  goodCount++;
                }
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

          switch (_currentTabIndex) {
            case 0: 
              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileCard(data),
                      _buildQuranProgressSection(sessionSnapshot),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Text("📊 لوحة الأداء والإحصائيات الحية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: primaryColor)),
                      ),
                      _buildParentStatsDashboard(
                        total: totalSessions,
                        present: presentCount,
                        absent: absentCount,
                        excellent: excellentCount,
                        good: goodCount,
                        bad: badCount,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
              
            case 1: 
              return sessionSnapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : sortedDocs.isEmpty
                      ? Center(child: Text("لا يوجد جلسات مسجلة بعد لهذا الطالب", style: TextStyle(color: Colors.grey[600], fontFamily: 'Cairo', fontSize: 14)))
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: sortedDocs.length,
                          itemBuilder: (context, index) {
                            var session = sortedDocs[index].data() as Map<String, dynamic>;
                            return _buildSessionItem(session, isCompletedStudent);
                          },
                        );
                        
            case 2: 
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text("🏆 لوحة أوسمة الشرف للمعهد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: primaryColor)),
                    ),
                    _buildHonorBoardSection(serialStr),
                    const SizedBox(height: 25),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 80, color: goldColor.withOpacity(0.3)),
                          const SizedBox(height: 10),
                          Text(
                            "منظومة تحفيز الطلاب الذكية",
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
                            child: Text(
                              "يتم تحديث قائمة النجوم بشكل دوري من إدارة الحلقة لتكريم الطلاب الأكثر انضباطاً وتميزاً.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            default:
              return const SizedBox();
          }
        },
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade400,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined, size: 22),
              activeIcon: Icon(Icons.analytics_rounded, size: 22),
              label: 'الخلاصة',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_edu_outlined, size: 22),
              activeIcon: Icon(Icons.history_edu_rounded, size: 22),
              label: 'السجل اليومي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.stars_outlined, size: 22),
              activeIcon: Icon(Icons.stars_rounded, size: 22),
              label: 'لوحة التميز',
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle(int index, String studentName) {
    switch (index) {
      case 0:
        return 'ملخص أداء: $studentName';
      case 1:
        return 'السجل اليومي للحفظ والمراجعة';
      case 2:
        return 'لوحة الشرف والتميز';
      default:
        return 'متابعة الطالب';
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من بوابة المتابعة؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('خروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          _buildStudentAvatar(data['imageUrl'] ?? '', data['name'] ?? '?'),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] ?? '', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                Text('الرقم التسلسلي: ${data['serial']}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
                Text('المرحلة الدراسية: ${data['schoolGrade'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 الدالة المحدثة كلياً بشكل ملوكي وبصري متطور للغاية
  Widget _buildParentStatsDashboard({
    required int total,
    required int present,
    required int absent,
    required int excellent,
    required int good,
    required int bad,
  }) {
    // حساب النسب المئوية أوتوماتيكياً للعرض الدائري الذكي
    double attendanceRate = total > 0 ? (present / total) : 0.0;
    double excellentRate = present > 0 ? (excellent / present) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 🥇 الصف الأول: الأقراص الدائرية لنسب الإنجاز الحية
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 55,
                            height: 55,
                            child: CircularProgressIndicator(
                              value: attendanceRate,
                              strokeWidth: 5,
                              backgroundColor: Colors.green.shade50,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          Text("${(attendanceRate * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("نسبة الالتزام", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87)),
                            Text("$present من أصل $total جلسة", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Cairo')),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 55,
                            height: 55,
                            child: CircularProgressIndicator(
                              value: excellentRate,
                              strokeWidth: 5,
                              backgroundColor: const Color(0xfffef9e7),
                              valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                            ),
                          ),
                          Icon(Icons.workspace_premium_rounded, size: 20, color: goldColor),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("التميز والاتقان", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87)),
                            Text("$excellent مرات متميزة", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Cairo')),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 🥈 الصف الثاني: شبكة تفصيلية ملوكية مبهجة للعين تفصل التقييمات والغياب
          Row(
            children: [
              Expanded(
                child: _buildModernStatMiniCard(
                  title: "المستوى المتميز",
                  value: "$excellent",
                  icon: Icons.auto_awesome_rounded,
                  baseColor: goldColor,
                  bgGradientColor: const Color(0xfffdfaf0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernStatMiniCard(
                  title: "المستوى المستقر",
                  value: "$good",
                  icon: Icons.thumb_up_alt_rounded,
                  baseColor: Colors.blue.shade600,
                  bgGradientColor: const Color(0xfff4f9ff),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: _buildModernStatMiniCard(
                  title: "يحتاج متابعة وتكرار",
                  value: "$bad",
                  icon: Icons.trending_down_rounded,
                  baseColor: Colors.redAccent.shade400,
                  bgGradientColor: const Color(0xfffff5f5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernStatMiniCard(
                  title: "جلسات الغياب",
                  value: "$absent",
                  icon: Icons.cancel_presentation_rounded,
                  baseColor: absent >= 3 ? Colors.red : Colors.grey.shade600,
                  bgGradientColor: absent >= 3 ? const Color(0xfffdf2f2) : const Color(0xfff8fafc),
                  badgeText: absent >= 3 ? "تنبيه غياب! ⚠️" : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🎨 دالة ذكية لبناء كروت الواجهة المحدثة بلمسات جمالية رقيقة
  Widget _buildModernStatMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color baseColor,
    required Color bgGradientColor,
    String? badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgGradientColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: baseColor.withOpacity(0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: baseColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: baseColor, size: 18),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 8, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryColor, fontFamily: 'Cairo', height: 1)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded, color: Colors.teal, size: 18),
              const SizedBox(width: 8),
              Text(
                "مستوى تقدم الطالب في الختمة 👑",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "تم تمكين $savedPages من أصل 604 صفحة",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontFamily: 'Cairo'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  "${(progressPercentage * 100).toStringAsFixed(1)}%",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade900, fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressPercentage,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: Colors.red.shade400, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remainingPages == 0 
                        ? "مبارك! للطالب ختم كتاب الله كاملاً، هنيئاً لك 🎉👑"
                        : "متبقي للطالب [ ${remainingPages.toStringAsFixed(0)} صفحة ] ويختم كتاب الله كاملاً ✨",
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: primaryColor, height: 1.4, fontFamily: 'Cairo'),
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
      return const SizedBox(height: 140, child: Center(child: Text("سيتم إعلان النجوم قريباً", style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo'))));
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 5)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: goldColor.withOpacity(0.5), width: 2),
                    color: primaryColor.withOpacity(0.1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(27),
                    child: finalImageUrl.isNotEmpty && finalImageUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: finalImageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
                            errorWidget: (context, url, error) => Center(
                              child: Text(winnerName.isNotEmpty ? winnerName.substring(0, 1) : '?', style: TextStyle(fontSize: 18, color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            ),
                          )
                        : Center(
                            child: Text(winnerName.isNotEmpty ? winnerName.substring(0, 1) : '?', style: TextStyle(fontSize: 18, color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  winnerName, 
                  textAlign: TextAlign.center, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis, 
                  style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo'),
                ),
                Text(
                  isCurrent ? "👑 ابنكم متميز" : "🏆 متميز", 
                  style: TextStyle(fontSize: 10, color: isCurrent ? goldColor : Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session, bool isCompletedStudent) {
    final String sessionDate = session['date']?.toString() ?? 'بدون تاريخ';
    final bool isAbsent = session['absent'] ?? false;
    final bool isExam = session['isExam'] ?? false; 
    final String supervisorName = session['supervisorName'] ?? 'غير محدد';

    if (isAbsent) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sessionDate, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontFamily: 'Cairo', fontSize: 13)),
                  _buildCustomBadge("غائب ❌", Colors.red.shade700, Colors.red.shade50),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMinimalistDetailRow(Icons.person_outline_rounded, "المشرف المسجِّل", supervisorName, isBold: true),
                  const SizedBox(height: 10),
                  _buildMinimalistDetailRow(Icons.warning_amber_rounded, "نوع الغياب", session['absenceType'] == "" ? "بدون عذر" : (session['absenceType'] ?? 'بدون عذر')),
                  if (session['absenceReason'] != null && session['absenceReason'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildMinimalistDetailRow(Icons.info_outline_rounded, "سبب الغياب", session['absenceReason']),
                  ],
                  if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                    Text("📝 ملاحظة المشرف: ${session['notes']}", style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ]
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isExam) {
      int score = int.tryParse(session['examScore']?.toString() ?? '0') ?? 0;
      Color examColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: examColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sessionDate, style: TextStyle(fontWeight: FontWeight.bold, color: examColor, fontFamily: 'Cairo', fontSize: 13)),
                  _buildCustomBadge("جلسة اختبار 📝", examColor, examColor.withOpacity(0.15)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMinimalistDetailRow(Icons.person_outline_rounded, "المشرف المسجِّل", supervisorName, isBold: true),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: examColor.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: examColor.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: examColor, size: 26),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("النتيجة الرسمية لاختبار الطالب", style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Cairo')),
                            Text("$score / 100", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: examColor, fontFamily: 'Cairo')),
                          ],
                        )
                      ],
                    ),
                  ),
                  if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                    Text("📝 ملاحظة المشرف: ${session['notes']}", style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ]
                ],
              ),
            ),
          ],
        ),
      );
    }

    String memRating = session['memorizationRating'] ?? session['rating'] ?? "جيد";
    String revRating = session['reviewRating'] ?? session['rating'] ?? "جيد";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(sessionDate, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Cairo', fontSize: 13)),
                Row(
                  children: [
                    if (isCompletedStudent)
                      _buildCustomBadge("مراجعة الختمة: $revRating", _getRatingColor(revRating), _getRatingColor(revRating).withOpacity(0.12))
                    else ...[
                      _buildCustomBadge("حفظ: $memRating", _getRatingColor(memRating), _getRatingColor(memRating).withOpacity(0.12)),
                      const SizedBox(width: 5),
                      _buildCustomBadge("مراجعة: $revRating", _getRatingColor(revRating), _getRatingColor(revRating).withOpacity(0.12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMinimalistDetailRow(Icons.person_pin_rounded, "مشرف الجلسة", supervisorName, isBold: true),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xfff1f5f9))),
                
                if (isCompletedStudent)
                  _buildGridInfoBox(
                    Icons.verified_user_rounded, 
                    "المقدار المسموع من مراجعة الختمة الشاملة", 
                    session['farReview'] ?? session['review'] ?? '---', 
                    Colors.teal
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(child: _buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", session['newMemorization'] ?? '---', Colors.amber)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", session['nearReview'] ?? '---', Colors.teal)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", session['farReview'] ?? '---', Colors.blueGrey)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", session['readingBySight'] ?? '---', Colors.indigo)),
                    ],
                  ),
                ],
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xfff1f5f9))),
                
                _buildMinimalistDetailRow(Icons.edit_note_rounded, isCompletedStudent ? "المقدار المطلوب للمرة القادمة" : "الواجب المعطى لليوم القادم", session['homework'] ?? '---'),
                const SizedBox(height: 8),
                _buildMinimalistDetailRow(Icons.emoji_emotions_outlined, "حالة سلوك الطالب بالحلقة", session['studentStatus'] ?? 'مهذب'),
                const SizedBox(height: 8),
                _buildMinimalistDetailRow(Icons.mosque_outlined, "الأنشطة والدروس الدينية بالمسجد", session['religiousActivities'] ?? '---'),
                
                if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.15))),
                    child: Text("📝 ملاحظة المشرف للأهل: ${session['notes']}", style: const TextStyle(fontSize: 12.5, color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Cairo', height: 1.4)),
                  ),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            val.trim().isEmpty ? '---' : val,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }

  Widget _buildMinimalistDetailRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 17, color: primaryColor.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '---' : value,
            style: TextStyle(
              fontSize: 12.5, 
              color: isBold ? primaryColor : Colors.black87, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500, 
              fontFamily: 'Cairo'
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Cairo')),
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
                errorWidget: (c, u, e) => Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: TextStyle(fontSize: 22, color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
              )
            : Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: TextStyle(fontSize: 22, color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case "ممتاز": return Colors.green;
      case "جيد جداً": return Colors.teal;
      case "جيد": return Colors.orange;
      case "مقبول": return Colors.blueGrey;
      case "ضعيف": return Colors.red;
      default: return primaryColor;
    }
  }
}