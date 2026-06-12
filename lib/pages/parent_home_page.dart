import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:provider/provider.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import '../services/theme_provider.dart'; 
import 'login_page.dart';
import 'update_checker.dart'; 
import 'notifications_page.dart'; 

// 🎯 استدعاء التبويبات المفصولة
import 'summary_tab.dart';
import 'daily_log_tab.dart';
import 'honor_board_tab.dart';
import 'parent_chat_tab.dart'; 

class ParentHomePage extends StatefulWidget {
  final DocumentSnapshot student;

  const ParentHomePage({super.key, required this.student});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);
  final Color accentGold = const Color(0xffd4af37); 

  int _currentTabIndex = 0; 
  
  double? _dragPosition;
  bool _isDragging = false;

  List<Map<String, dynamic>> allWinners = [];
  Map<String, String> studentImagesCache = {};
  bool _isHonorLoading = true;

  List<DocumentSnapshot> siblings = [];

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));

    _loadHonorBoardAndImages();
    _saveDeviceToken(); 
    _fetchSiblings(); 
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _fetchSiblings() async {
    try {
      final currentData = widget.student.data() as Map<String, dynamic>;
      final String phone = currentData['phone']?.toString().trim() ?? '';

      if (phone.isNotEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('phone', isEqualTo: phone)
            .get();

        if (mounted) {
          setState(() {
            siblings = querySnapshot.docs.where((doc) => doc.id != widget.student.id).toList();
          });
        }
      }
    } catch (e) {
      print("Error fetching siblings: $e");
    }
  }

  void _saveDeviceToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('students').doc(widget.student.id).update({'fcmToken': token});
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
        String winnerSerialStr = rawSerial?.toString() ?? '';
        final studentQuery = await FirebaseFirestore.instance.collection('students').where('serial', isEqualTo: int.tryParse(winnerSerialStr) ?? winnerSerialStr).limit(1).get();
        if (studentQuery.docs.isNotEmpty) {
          tempCache[winnerSerialStr] = studentQuery.docs.first.data()['imageUrl']?.toString() ?? '';
        }
      }
      if (mounted) setState(() { allWinners = winners; studentImagesCache = tempCache; _isHonorLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isHonorLoading = false; });
    }
  }

  // 🚀 نافذة طلب إذن الغياب المدمجة
  void _showLeaveRequestDialog(BuildContext context, bool isDarkMode, String studentId, String studentName, String supervisorId) {
    final TextEditingController reasonController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xff1e293b).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                      border: Border.all(color: isDarkMode ? Colors.white24 : Colors.white, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_busy_rounded, size: 50, color: Colors.orangeAccent),
                        const SizedBox(height: 10),
                        Text("طلب إذن غياب", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                        const SizedBox(height: 15),
                        
                        // اختيار التاريخ
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          tileColor: isDarkMode ? Colors.black26 : Colors.grey.shade100,
                          leading: Icon(Icons.calendar_month_rounded, color: accentGold),
                          title: Text("تاريخ الغياب: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87)),
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(primary: accentGold, onPrimary: Colors.white, onSurface: isDarkMode ? Colors.white : primaryColor),
                                    dialogBackgroundColor: isDarkMode ? const Color(0xff1e293b) : Colors.white,
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) setDialogState(() => selectedDate = picked);
                          },
                        ),
                        const SizedBox(height: 15),

                        // حقل السبب
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "اكتب سبب الغياب هنا...",
                            hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontFamily: 'Cairo', fontSize: 13),
                            filled: true,
                            fillColor: isDarkMode ? Colors.black26 : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // زر الإرسال
                        SizedBox(
                          width: double.infinity, height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentGold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            onPressed: () async {
                              if (reasonController.text.trim().isEmpty) return;
                              
                              Navigator.pop(context); // إغلاق النافذة
                              
                              // حفظ الطلب في الداتا بيز
                              await FirebaseFirestore.instance.collection('leave_requests').add({
                                'studentId': studentId,
                                'studentName': studentName,
                                'supervisorId': supervisorId,
                                'reason': reasonController.text.trim(),
                                'date': "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}",
                                'status': 'pending', 
                                'timestamp': FieldValue.serverTimestamp(),
                              });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(backgroundColor: Colors.green, content: Text("✅ تم إرسال طلب الغياب للمشرف بانتظار الموافقة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
                                );
                              }
                            },
                            child: const Text("إرسال الطلب", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.student.data() as Map<String, dynamic>;
    final String studentId = widget.student.id;
    final String studentName = data['name'] ?? 'الطالب';
    final String serialStr = data['serial']?.toString() ?? '';
    final bool isCompletedStudent = data['studentType'] == 'completed';
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final String supervisorId = data['supervisorId'] ?? '';
    final String supervisorName = data['supervisorName'] ?? 'المشرف';

    return Scaffold(
      extendBodyBehindAppBar: true, 
      extendBody: true, 
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent, 
        title: Text(_getAppBarTitle(_currentTabIndex, studentName), style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 16, fontFamily: 'Cairo')),
        centerTitle: true,
        actions: [
          if (siblings.isNotEmpty)
            IconButton(
              icon: Icon(Icons.people_alt_rounded, color: isDarkMode ? goldColor : primaryColor),
              tooltip: 'تبديل الأبناء',
              onPressed: () => _showLiquidSiblingSwitcher(isDarkMode),
            ),
            
          // 🚀 زر طلب الاستئذان المضاف للأهل
          IconButton(
            icon: Icon(Icons.event_busy_rounded, color: Colors.orangeAccent),
            tooltip: 'طلب إذن غياب',
            onPressed: () => _showLeaveRequestDialog(context, isDarkMode, studentId, studentName, supervisorId),
          ),
          
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDarkMode ? goldColor : primaryColor),
            tooltip: isDarkMode ? 'تفعيل الوضع النهاري' : 'تفعيل الوضع الليلي',
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),

          IconButton(icon: Icon(Icons.notifications_none_rounded, color: isDarkMode ? goldColor : primaryColor), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsPage(studentId: studentId)))),
          IconButton(icon: Icon(Icons.logout_rounded, color: isDarkMode ? Colors.redAccent : Colors.red), onPressed: () => _showLogoutDialog(isDarkMode)),
        ],
      ),
      
      body: Stack(
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -20 + _bgAnimation.value,
                    left: -50 - (_bgAnimation.value / 2),
                    child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12))),
                  ),
                  Positioned(
                    bottom: 100 - _bgAnimation.value,
                    right: -60 + _bgAnimation.value,
                    child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            bottom: false,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('sessions').where('studentId', isEqualTo: studentId).snapshots(),
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
                    if (sData['absent'] == true) {
                      absentCount++;
                    } else {
                      String memRating = sData['memorizationRating']?.toString() ?? sData['rating']?.toString() ?? '';
                      String revRating = sData['reviewRating']?.toString() ?? sData['rating']?.toString() ?? '';
                      if (memRating == 'ممتاز' || memRating == 'جيد جداً' || revRating == 'ممتاز' || revRating == 'جيد جداً') {
                        excellentCount++;
                      } else if (memRating == 'سيء' || memRating == 'ضعيف' || revRating == 'سيء' || revRating == 'ضعيف') {
                        badCount++;
                      } else {
                        goodCount++;
                      }
                    }
                  }
                  sortedDocs = List.from(docs)..sort((a, b) => ((b.data() as Map)['date']?.toString() ?? '').compareTo((a.data() as Map)['date']?.toString() ?? ''));
                }

                int presentCount = totalSessions - absentCount;

                switch (_currentTabIndex) {
                  case 0: 
                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: SummaryTab(studentData: data, sessionSnapshot: sessionSnapshot, total: totalSessions, present: presentCount, absent: absentCount, excellent: excellentCount, good: goodCount, bad: badCount, isDarkMode: isDarkMode),
                    );
                  case 1: 
                    if (sessionSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    return DailyLogTab(sortedDocs: sortedDocs, isCompletedStudent: isCompletedStudent, isDarkMode: isDarkMode);
                  case 2: 
                    return HonorBoardTab(allWinners: allWinners, studentImagesCache: studentImagesCache, isHonorLoading: _isHonorLoading, currentStudentSerial: serialStr, isDarkMode: isDarkMode);
                  case 3: 
                    return ParentChatTab(studentId: studentId, studentName: studentName, supervisorId: supervisorId, supervisorName: supervisorName, isDarkMode: isDarkMode);
                  default:
                    return const SizedBox();
                }
              },
            ),
          ),
          _buildDraggableLiquidNavBar(isDarkMode),
        ],
      ),
    );
  }

  void _showLiquidSiblingSwitcher(bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.9),
                border: Border(top: BorderSide(color: isDarkMode ? Colors.white12 : Colors.white, width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: isDarkMode ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  Text("تبديل سجل المتابعة", style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                  const SizedBox(height: 5),
                  Text("اختر أحد أبنائك للانتقال إلى ملفه مباشرة", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey.shade600)),
                  const SizedBox(height: 25),
                  ...siblings.map((siblingDoc) {
                    var data = siblingDoc.data() as Map<String, dynamic>;
                    String name = data['name'] ?? 'اسم الطالب';
                    String img = data['imageUrl']?.toString() ?? '';
                    String grade = data['schoolGrade'] ?? 'غير محدد';
                    String serial = data['serial']?.toString() ?? '';

                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context); 
                        final SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setString('saved_student_serial', serial);

                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => ParentHomePage(student: siblingDoc),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 500),
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDarkMode ? Colors.white12 : primaryColor.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: goldColor, width: 2)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: img.isNotEmpty 
                                    ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (c, u, e) => _buildFallbackAvatar(name, isDarkMode))
                                    : _buildFallbackAvatar(name, isDarkMode),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                                  Text(grade, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isDarkMode ? Colors.white54 : Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDarkMode ? goldColor : primaryColor.withOpacity(0.5)),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackAvatar(String name, bool isDarkMode) {
    return Container(
      color: isDarkMode ? primaryColor.withOpacity(0.5) : primaryColor.withOpacity(0.1),
      child: Center(child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor))),
    );
  }

  Widget _buildDraggableLiquidNavBar(bool isDarkMode) {
    return Positioned(
      bottom: 25, left: 20, right: 20, height: 70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.6), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 4; 
                int closestIndex = _currentTabIndex;
                if (_isDragging && _dragPosition != null) {
                  closestIndex = ((_dragPosition! + (itemWidth / 2)) / itemWidth).round().clamp(0, 3); 
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) => setState(() => _isDragging = true),
                  onHorizontalDragUpdate: (details) {
                    bool isRtl = Directionality.of(context) == TextDirection.rtl;
                    setState(() {
                      _dragPosition = isRtl ? constraints.maxWidth - details.localPosition.dx - (itemWidth / 2) : details.localPosition.dx - (itemWidth / 2);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      _isDragging = false;
                      if (_dragPosition != null) _currentTabIndex = ((_dragPosition! + (itemWidth / 2)) / itemWidth).round().clamp(0, 3);
                      _dragPosition = null;
                    });
                  },
                  onTapUp: (details) {
                    bool isRtl = Directionality.of(context) == TextDirection.rtl;
                    double tapPos = isRtl ? constraints.maxWidth - details.localPosition.dx : details.localPosition.dx;
                    setState(() => _currentTabIndex = (tapPos / itemWidth).floor().clamp(0, 3));
                  },
                  child: Stack(
                    children: [
                      AnimatedPositionedDirectional(
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 350),
                        curve: _isDragging ? Curves.linear : Curves.easeOutBack,
                        start: _isDragging && _dragPosition != null ? _dragPosition!.clamp(0.0, constraints.maxWidth - itemWidth) : _currentTabIndex * itemWidth,
                        top: 0, bottom: 0,
                        child: Container(
                          width: itemWidth, alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                              child: Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode ? Colors.white.withOpacity(0.15) : primaryColor.withOpacity(0.6),
                                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                                  boxShadow: [BoxShadow(color: (isDarkMode ? accentGold : primaryColor).withOpacity(0.4), blurRadius: 15, spreadRadius: 1)]
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildNavItem(0, Icons.analytics_outlined, Icons.analytics_rounded, 'الخلاصة', itemWidth, isDarkMode, closestIndex),
                          _buildNavItem(1, Icons.history_edu_outlined, Icons.history_edu_rounded, 'السجل', itemWidth, isDarkMode, closestIndex),
                          _buildNavItem(2, Icons.stars_outlined, Icons.stars_rounded, 'التميز', itemWidth, isDarkMode, closestIndex),
                          _buildNavItem(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'تواصل', itemWidth, isDarkMode, closestIndex), 
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

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label, double width, bool isDarkMode, int closestIndex) {
    final isHovered = closestIndex == index;
    return SizedBox(
      width: width,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: isHovered
            ? Icon(filledIcon, key: ValueKey('icon_selected_$index'), color: Colors.white, size: 28)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center, key: ValueKey('icon_unselected_$index'),
                children: [
                  Icon(outlineIcon, color: isDarkMode ? Colors.white54 : primaryColor.withOpacity(0.5), size: 24),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(color: isDarkMode ? Colors.white54 : primaryColor.withOpacity(0.7), fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  String _getAppBarTitle(int index, String studentName) {
    switch (index) {
      case 0: return 'ملخص أداء: $studentName';
      case 1: return 'السجل اليومي للحفظ والمراجعة';
      case 2: return 'لوحة الشرف والتميز';
      case 3: return 'التواصل مع المشرف'; 
      default: return 'متابعة الطالب';
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
            TextButton(child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)), onPressed: () => Navigator.of(context).pop()),
            TextButton(
              child: const Text('خروج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              onPressed: () async {
                Navigator.of(context).pop();
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.remove('saved_student_serial');
                if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
              },
            ),
          ],
        );
      },
    );
  }
}