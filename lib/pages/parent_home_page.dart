import 'dart:io';
import 'dart:ui'; // 🎯 ضرورية لتأثير الزجاج (Blur)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:provider/provider.dart'; // 🎯 لقراءة المظهر
import '../services/theme_provider.dart'; // 🎯 استدعاء الـ ThemeProvider
import 'login_page.dart';
import 'update_checker.dart'; 
import 'notifications_page.dart'; 

class ParentHomePage extends StatefulWidget {
  final DocumentSnapshot student;

  const ParentHomePage({super.key, required this.student});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);
  final Color accentGold = const Color(0xffd4af37); 

  int _currentTabIndex = 0; 
  
  // 🎯 متغيرات سحب الفقاعة الزجاجية السائلة
  double? _dragPosition;
  bool _isDragging = false;

  List<Map<String, dynamic>> allWinners = [];
  Map<String, String> studentImagesCache = {};
  bool _isHonorLoading = true;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _loadHonorBoardAndImages();
    _saveDeviceToken(); 
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
  }

  void _saveDeviceToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(widget.student.id)
            .update({'fcmToken': token});
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      extendBody: true, 
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, 
        title: Text(
          _getAppBarTitle(_currentTabIndex, studentName), 
          style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 16, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: isDarkMode ? goldColor : primaryColor),
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
            icon: Icon(Icons.logout_rounded, color: isDarkMode ? Colors.redAccent : Colors.red),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutDialog(isDarkMode),
          ),
        ],
      ),
      
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية مع الدوائر العائمة
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
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12)),
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
            bottom: false,
            child: StreamBuilder<QuerySnapshot>(
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
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileCard(data, isDarkMode),
                            _buildQuranProgressSection(sessionSnapshot, isDarkMode),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Text("📊 لوحة الأداء والإحصائيات الحية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                            ),
                            _buildParentStatsDashboard(
                              total: totalSessions,
                              present: presentCount,
                              absent: absentCount,
                              excellent: excellentCount,
                              good: goodCount,
                              bad: badCount,
                              isDarkMode: isDarkMode,
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
                            ? Center(child: _buildGlassContainer(isDarkMode: isDarkMode, padding: const EdgeInsets.all(20), child: Text("لا يوجد جلسات مسجلة بعد لهذا الطالب", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[600], fontFamily: 'Cairo', fontSize: 14))))
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(top: 10, bottom: 120),
                                itemCount: sortedDocs.length,
                                itemBuilder: (context, index) {
                                  var session = sortedDocs[index].data() as Map<String, dynamic>;
                                  return _buildSessionItem(session, isCompletedStudent, isDarkMode);
                                },
                              );
                              
                  case 2: 
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text("🏆 لوحة أوسمة الشرف للمعهد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
                          ),
                          _buildHonorBoardSection(serialStr, isDarkMode),
                          const SizedBox(height: 25),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 80, color: goldColor.withOpacity(0.3)),
                                const SizedBox(height: 10),
                                Text(
                                  "منظومة تحفيز الطلاب الذكية",
                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : primaryColor),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
                                  child: Text(
                                    "يتم تحديث قائمة النجوم بشكل دوري من إدارة الحلقة لتكريم الطلاب الأكثر انضباطاً وتميزاً.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.grey.shade500, height: 1.4),
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
          ),

          // 🚀 3. شريط التنقل الزجاجي التفاعلي القابل للسحب (Drag-to-Snap Liquid Glass)
          _buildDraggableLiquidNavBar(isDarkMode),
        ],
      ),
    );
  }

  // 🧊 دالة بناء الشريط الزجاجي التفاعلي بالسحب
  Widget _buildDraggableLiquidNavBar(bool isDarkMode) {
    return Positioned(
      bottom: 25,
      left: 20,
      right: 20,
      height: 70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // تضبيب خفيف للشريط نفسه
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 3;
                
                // حساب المركز الأقرب ليتم تلوين الأيقونة بذكاء أثناء السحب
                int closestIndex = _currentTabIndex;
                if (_isDragging && _dragPosition != null) {
                  closestIndex = ((_dragPosition! + (itemWidth / 2)) / itemWidth).round().clamp(0, 2);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    setState(() => _isDragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    bool isRtl = Directionality.of(context) == TextDirection.rtl;
                    setState(() {
                      if (isRtl) {
                        _dragPosition = constraints.maxWidth - details.localPosition.dx - (itemWidth / 2);
                      } else {
                        _dragPosition = details.localPosition.dx - (itemWidth / 2);
                      }
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      _isDragging = false;
                      if (_dragPosition != null) {
                        int newIndex = ((_dragPosition! + (itemWidth / 2)) / itemWidth).round().clamp(0, 2);
                        _currentTabIndex = newIndex;
                      }
                      _dragPosition = null;
                    });
                  },
                  onTapUp: (details) {
                    bool isRtl = Directionality.of(context) == TextDirection.rtl;
                    double tapPos = isRtl ? constraints.maxWidth - details.localPosition.dx : details.localPosition.dx;
                    int newIndex = (tapPos / itemWidth).floor().clamp(0, 2);
                    setState(() {
                      _currentTabIndex = newIndex;
                    });
                  },
                  child: Stack(
                    children: [
                      // 💧 الفقاعة الزجاجية السائلة المكثفة (Heavy Glass Bubble)
                      AnimatedPositionedDirectional(
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
                        curve: _isDragging ? Curves.linear : Curves.easeOutBack, // سائلة عند الفلتان
                        start: _isDragging && _dragPosition != null 
                            ? _dragPosition!.clamp(0.0, constraints.maxWidth - itemWidth)
                            : _currentTabIndex * itemWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: itemWidth,
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), // 🎯 تضبيب مضاعف جداً للفقاعة
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode ? Colors.white.withOpacity(0.15) : primaryColor.withOpacity(0.6),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.9), 
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDarkMode ? accentGold : primaryColor).withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                    )
                                  ]
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // 🧩 الأيقونات (مرتفعة فوق الزجاج لتظل واضحة وتتفاعل مع السحب)
                      Row(
                        children: [
                          _buildNavItem(0, Icons.analytics_outlined, Icons.analytics_rounded, 'الخلاصة', itemWidth, isDarkMode, closestIndex),
                          _buildNavItem(1, Icons.history_edu_outlined, Icons.history_edu_rounded, 'السجل', itemWidth, isDarkMode, closestIndex),
                          _buildNavItem(2, Icons.stars_outlined, Icons.stars_rounded, 'التميز', itemWidth, isDarkMode, closestIndex),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // 🧩 بناء أيقونات التنقل وتغيير اللون بذكاء حسب قرب الفقاعة منها
  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label, double width, bool isDarkMode, int closestIndex) {
    final isHovered = closestIndex == index;
    return SizedBox(
      width: width,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: isHovered
            ? Icon(
                filledIcon,
                key: ValueKey('icon_selected_$index'),
                color: Colors.white, // الأيقونة بتصير بيضاء وواضحة جداً لما تمرق الفقاعة فوقها
                size: 28,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                key: ValueKey('icon_unselected_$index'),
                children: [
                  Icon(outlineIcon, color: isDarkMode ? Colors.white54 : primaryColor.withOpacity(0.5), size: 24),
                  const SizedBox(height: 2),
                  Text(
                    label, 
                    style: TextStyle(color: isDarkMode ? Colors.white54 : primaryColor.withOpacity(0.7), fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
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

  void _showLogoutDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : Colors.black87)),
          content: Text('هل أنت متأكد من رغبتك في تسجيل الخروج من بوابة المتابعة؟', style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('خروج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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

  Widget _buildGlassContainer({required Widget child, required bool isDarkMode, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(25),
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

  Widget _buildProfileCard(Map<String, dynamic> data, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 10),
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _buildStudentAvatar(data['imageUrl'] ?? '', data['name'] ?? '?', isDarkMode),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? '', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                  const SizedBox(height: 4),
                  Text('الرقم التسلسلي: ${data['serial']}', style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                  Text('المرحلة الدراسية: ${data['schoolGrade'] ?? ''}', style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey[700], fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
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
    required bool isDarkMode,
  }) {
    double attendanceRate = total > 0 ? (present / total) : 0.0;
    double excellentRate = present > 0 ? (excellent / present) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(16),
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
                              backgroundColor: isDarkMode ? Colors.green.withOpacity(0.1) : Colors.green.shade50,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          Text("${(attendanceRate * 100).toStringAsFixed(0)}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : Colors.black87)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("نسبة الالتزام", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : Colors.black87)),
                            Text("$present من أصل $total جلسة", style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(16),
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
                              backgroundColor: isDarkMode ? goldColor.withOpacity(0.1) : const Color(0xfffef9e7),
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
                            Text("التميز والاتقان", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : Colors.black87)),
                            Text("$excellent مرات متميزة", style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.grey.shade600, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
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
          
          Row(
            children: [
              Expanded(
                child: _buildModernStatMiniCard(
                  title: "المستوى المتميز",
                  value: "$excellent",
                  icon: Icons.auto_awesome_rounded,
                  baseColor: goldColor,
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernStatMiniCard(
                  title: "المستوى المستقر",
                  value: "$good",
                  icon: Icons.thumb_up_alt_rounded,
                  baseColor: Colors.blue.shade500,
                  isDarkMode: isDarkMode,
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
                  isDarkMode: isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildModernStatMiniCard(
                  title: "جلسات الغياب",
                  value: "$absent",
                  icon: Icons.cancel_presentation_rounded,
                  baseColor: absent >= 3 ? Colors.redAccent : Colors.grey.shade500,
                  badgeText: absent >= 3 ? "تنبيه غياب! ⚠️" : null,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color baseColor,
    required bool isDarkMode,
    String? badgeText,
  }) {
    return _buildGlassContainer(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(15),
      customColor: baseColor.withOpacity(isDarkMode ? 0.1 : 0.05),
      customBorderColor: baseColor.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: baseColor.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: baseColor, size: 18),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
                  child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 8, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', height: 1)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildQuranProgressSection(AsyncSnapshot<QuerySnapshot> sessionSnapshot, bool isDarkMode) {
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
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        padding: const EdgeInsets.all(18),
        customBorderColor: Colors.teal.withOpacity(0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: isDarkMode ? Colors.tealAccent : Colors.teal, size: 18),
                const SizedBox(width: 8),
                Text(
                  "مستوى تقدم الطالب في الختمة 👑",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "تم تمكين $savedPages من أصل 604 صفحة",
                  style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "${(progressPercentage * 100).toStringAsFixed(1)}%",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.tealAccent : Colors.teal.shade900, fontFamily: 'Cairo'),
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
                backgroundColor: isDarkMode ? Colors.white12 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(isDarkMode ? Colors.tealAccent : Colors.teal.shade500),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.tealAccent.withOpacity(0.05) : Colors.teal.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.1)),
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
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, height: 1.4, fontFamily: 'Cairo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHonorBoardSection(String currentStudentSerial, bool isDarkMode) {
    if (_isHonorLoading) {
      return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
    }
    if (allWinners.isEmpty) {
      return SizedBox(height: 140, child: Center(child: Text("سيتم إعلان النجوم قريباً", style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white54 : Colors.grey, fontFamily: 'Cairo'))));
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
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
            child: _buildGlassContainer(
              isDarkMode: isDarkMode,
              padding: const EdgeInsets.all(8),
              customColor: isCurrent ? goldColor.withOpacity(0.15) : (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4)),
              customBorderColor: isCurrent ? goldColor.withOpacity(0.8) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: goldColor.withOpacity(0.6), width: 2),
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
                                child: Text(winnerName.isNotEmpty ? winnerName.substring(0, 1) : '?', style: TextStyle(fontSize: 18, color: isDarkMode ? goldColor : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              ),
                            )
                          : Center(
                              child: Text(winnerName.isNotEmpty ? winnerName.substring(0, 1) : '?', style: TextStyle(fontSize: 18, color: isDarkMode ? goldColor : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    winnerName, 
                    textAlign: TextAlign.center, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white : primaryColor, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600, fontFamily: 'Cairo'),
                  ),
                  Text(
                    isCurrent ? "👑 ابنكم متميز" : "🏆 متميز", 
                    style: TextStyle(fontSize: 10, color: isCurrent ? goldColor : Colors.orangeAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session, bool isCompletedStudent, bool isDarkMode) {
    final String sessionDate = session['date']?.toString() ?? 'بدون تاريخ';
    final bool isAbsent = session['absent'] ?? false;
    final bool isExam = session['isExam'] ?? false; 
    final String supervisorName = session['supervisorName'] ?? 'غير محدد';

    if (isAbsent) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: _buildGlassContainer(
          isDarkMode: isDarkMode,
          customBorderColor: Colors.redAccent.withOpacity(0.4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(isDarkMode ? 0.2 : 0.1),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sessionDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.redAccent.shade100 : Colors.red.shade900, fontFamily: 'Cairo', fontSize: 13)),
                    _buildCustomBadge("غائب ❌", isDarkMode ? Colors.white : Colors.red.shade700, Colors.redAccent.withOpacity(isDarkMode ? 0.4 : 0.2)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMinimalistDetailRow(Icons.person_outline_rounded, "المشرف المسجِّل", supervisorName, isDarkMode, isBold: true),
                    const SizedBox(height: 10),
                    _buildMinimalistDetailRow(Icons.warning_amber_rounded, "نوع الغياب", session['absenceType'] == "" ? "بدون عذر" : (session['absenceType'] ?? 'بدون عذر'), isDarkMode),
                    if (session['absenceReason'] != null && session['absenceReason'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildMinimalistDetailRow(Icons.info_outline_rounded, "سبب الغياب", session['absenceReason'], isDarkMode),
                    ],
                    if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : Colors.black12)),
                      Text("📝 ملاحظة المشرف: ${session['notes']}", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.orangeAccent : Colors.orange.shade900, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isExam) {
      int score = int.tryParse(session['examScore']?.toString() ?? '0') ?? 0;
      Color examColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: _buildGlassContainer(
          isDarkMode: isDarkMode,
          customBorderColor: examColor.withOpacity(0.4),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: examColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sessionDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? examColor.withOpacity(0.8) : examColor, fontFamily: 'Cairo', fontSize: 13)),
                    _buildCustomBadge("جلسة اختبار 📝", isDarkMode ? Colors.white : examColor, examColor.withOpacity(isDarkMode ? 0.4 : 0.2)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMinimalistDetailRow(Icons.person_outline_rounded, "المشرف المسجِّل", supervisorName, isDarkMode, isBold: true),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: examColor.withOpacity(isDarkMode ? 0.1 : 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: examColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: examColor, size: 26),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("النتيجة الرسمية لاختبار الطالب", style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                              Text("$score / 100", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: examColor, fontFamily: 'Cairo')),
                            ],
                          )
                        ],
                      ),
                    ),
                    if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : Colors.black12)),
                      Text("📝 ملاحظة المشرف: ${session['notes']}", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.orangeAccent : Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    String memRating = session['memorizationRating'] ?? session['rating'] ?? "جيد";
    String revRating = session['reviewRating'] ?? session['rating'] ?? "جيد";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: _buildGlassContainer(
        isDarkMode: isDarkMode,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sessionDate, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', fontSize: 13)),
                  Row(
                    children: [
                      if (isCompletedStudent)
                        _buildCustomBadge("مراجعة الختمة: $revRating", isDarkMode ? Colors.white : _getRatingColor(revRating), _getRatingColor(revRating).withOpacity(isDarkMode ? 0.4 : 0.2))
                      else ...[
                        _buildCustomBadge("حفظ: $memRating", isDarkMode ? Colors.white : _getRatingColor(memRating), _getRatingColor(memRating).withOpacity(isDarkMode ? 0.4 : 0.2)),
                        const SizedBox(width: 5),
                        _buildCustomBadge("مراجعة: $revRating", isDarkMode ? Colors.white : _getRatingColor(revRating), _getRatingColor(revRating).withOpacity(isDarkMode ? 0.4 : 0.2)),
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
                  _buildMinimalistDetailRow(Icons.person_pin_rounded, "مشرف الجلسة", supervisorName, isDarkMode, isBold: true),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : const Color(0xfff1f5f9))),
                  
                  if (isCompletedStudent)
                    _buildGridInfoBox(
                      Icons.verified_user_rounded, 
                      "المقدار المسموع من مراجعة الختمة الشاملة", 
                      session['farReview'] ?? session['review'] ?? '---', 
                      isDarkMode ? Colors.tealAccent : Colors.teal,
                      isDarkMode
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(child: _buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", session['newMemorization'] ?? '---', Colors.amber, isDarkMode)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", session['nearReview'] ?? '---', isDarkMode ? Colors.tealAccent : Colors.teal, isDarkMode)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", session['farReview'] ?? '---', Colors.blueGrey, isDarkMode)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", session['readingBySight'] ?? '---', Colors.indigoAccent, isDarkMode)),
                      ],
                    ),
                  ],
                  
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : const Color(0xfff1f5f9))),
                  
                  _buildMinimalistDetailRow(Icons.edit_note_rounded, isCompletedStudent ? "المقدار المطلوب للمرة القادمة" : "الواجب المعطى لليوم القادم", session['homework'] ?? '---', isDarkMode),
                  const SizedBox(height: 8),
                  _buildMinimalistDetailRow(Icons.emoji_emotions_outlined, "حالة سلوك الطالب بالحلقة", session['studentStatus'] ?? 'مهذب', isDarkMode),
                  const SizedBox(height: 8),
                  _buildMinimalistDetailRow(Icons.mosque_outlined, "الأنشطة والدروس الدينية بالمسجد", session['religiousActivities'] ?? '---', isDarkMode),
                  
                  if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : Colors.black12)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(isDarkMode ? 0.1 : 0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withOpacity(isDarkMode ? 0.3 : 0.15))),
                      child: Text("📝 ملاحظة المشرف للأهل: ${session['notes']}", style: TextStyle(fontSize: 12.5, color: isDarkMode ? Colors.orangeAccent : Colors.orange.shade800, fontWeight: FontWeight.bold, fontFamily: 'Cairo', height: 1.4)),
                    ),
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val, Color iconColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : const Color(0xfff8fafc).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white12 : const Color(0xffe2e8f0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            val.trim().isEmpty ? '---' : val,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
          )
        ],
      ),
    );
  }

  Widget _buildMinimalistDetailRow(IconData icon, String label, String value, bool isDarkMode, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 17, color: isDarkMode ? accentGold : primaryColor.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '---' : value,
            style: TextStyle(
              fontSize: 12.5, 
              color: isBold ? (isDarkMode ? Colors.white : primaryColor) : (isDarkMode ? Colors.white70 : Colors.black87), 
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600, 
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

  Widget _buildStudentAvatar(String url, String name, bool isDarkMode) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? Colors.white12 : primaryColor.withOpacity(0.1)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url, 
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: TextStyle(fontSize: 22, color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
              )
            : Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: TextStyle(fontSize: 22, color: isDarkMode ? accentGold : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
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