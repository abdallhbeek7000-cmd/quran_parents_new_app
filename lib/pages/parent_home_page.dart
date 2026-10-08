import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:provider/provider.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import '../services/theme_provider.dart'; 
import '../services/notification_service.dart'; 
import 'login_page.dart';
import 'update_checker.dart'; 
import 'notifications_page.dart'; 
import 'parent_activities_page.dart'; 

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
  late PageController _pageController;

  double? _dragPosition;
  bool _isDragging = false;

  List<Map<String, dynamic>> allWinners = [];
  Map<String, String> studentImagesCache = {};
  bool _isHonorLoading = true;

  List<DocumentSnapshot> siblings = [];
  String _activeCycleId = '';
  bool _isLoading = true;
  DocumentSnapshot? _activeStudentDoc;

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentTabIndex);

    FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));

    _loadActiveData();
    _loadHonorBoardAndImages();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  // 🚀 جلب الدورة النشطة وطالب الدورة النشطة بشكل نهائي
  Future<void> _loadActiveData() async {
    try {
      var cycleQuery = await FirebaseFirestore.instance
          .collection('cycles')
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (cycleQuery.docs.isNotEmpty) {
        _activeCycleId = cycleQuery.docs.first.id;
      } else {
        var isCurrentSnap = await FirebaseFirestore.instance
            .collection('cycles')
            .where('isCurrent', isEqualTo: true)
            .limit(1)
            .get();
        if (isCurrentSnap.docs.isNotEmpty) {
          _activeCycleId = isCurrentSnap.docs.first.id;
        }
      }

      final initialData = widget.student.data() as Map<String, dynamic>? ?? {};
      final String serial = initialData['serial']?.toString().trim() ?? '';

      if (serial.isNotEmpty && _activeCycleId.isNotEmpty) {
        var studentQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('serial', isEqualTo: int.tryParse(serial) ?? serial)
            .where('cycleId', isEqualTo: _activeCycleId)
            .get();

        if (studentQuery.docs.isNotEmpty) {
          _activeStudentDoc = studentQuery.docs.first;
        }
      }

      if (_activeStudentDoc == null && serial.isNotEmpty) {
        var fallbackQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('serial', isEqualTo: int.tryParse(serial) ?? serial)
            .get();

        for (var doc in fallbackQuery.docs) {
          var d = doc.data();
          if (d['cycleId']?.toString().trim() != 'rRDaBmGjfo6RMOXcF5fm') {
            _activeStudentDoc = doc;
            break;
          }
        }
      }

      _activeStudentDoc ??= widget.student;

      _saveDeviceToken();
      _fetchActiveSiblings();

    } catch (e) {
      debugPrint("خطأ تحميل البيانات النشطة: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _fetchActiveSiblings() async {
    try {
      final currentData = _activeStudentDoc?.data() as Map<String, dynamic>?;
      if (currentData == null) return;

      final String phone = currentData['phone']?.toString().trim() ?? '';
      final String currentSerial = currentData['serial']?.toString().trim() ?? '';

      if (phone.isNotEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('phone', isEqualTo: phone)
            .get();

        if (mounted) {
          setState(() {
            siblings = querySnapshot.docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String docSerial = data['serial']?.toString().trim() ?? '';
              return docSerial != currentSerial;
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching siblings: $e");
    }
  }

  void _saveDeviceToken() async {
    try {
      if (_activeStudentDoc == null) return;
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('students').doc(_activeStudentDoc!.id).update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }

  void _loadHonorBoardAndImages() async {
    try {
      final honorSnapshot = await FirebaseFirestore.instance.collection('honor_board').get();
      List<Map<String, dynamic>> winners = [];
      
      for (var doc in honorSnapshot.docs) {
        var data = doc.data();
        List<dynamic> knights = data.containsKey('knights') ? data['knights'] : [];
        
        if (knights.isNotEmpty) {
          for (var k in knights) {
            if (k != null && k['name'] != "لم يحدد") {
              winners.add(Map<String, dynamic>.from(k));
            }
          }
        } else {
          if (data.containsKey('first') && data['first'] != null && data['first']['name'] != "لم يحدد") winners.add(Map<String, dynamic>.from(data['first']));
          if (data.containsKey('second') && data['second'] != null && data['second']['name'] != "لم يحدد") winners.add(Map<String, dynamic>.from(data['second']));
          if (data.containsKey('third') && data['third'] != null && data['third']['name'] != "لم يحدد") winners.add(Map<String, dynamic>.from(data['third']));
        }
      }
      
      if (mounted) {
        setState(() { 
          allWinners = winners; 
          _isHonorLoading = false; 
        });
      }
    } catch (e) {
      debugPrint("Error loading honor board: $e");
      if (mounted) setState(() { _isHonorLoading = false; });
    }
  }

  void _onTabTapped(int index) {
    if (_currentTabIndex == index) return;
    setState(() => _currentTabIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 📝 نافذة طلب إذن الغياب بتصميم مطابِق للصورة ومنع التكرار بنفس اليوم
  void _showLeaveRequestDialog(bool isDarkMode) {
    DateTime selectedDate = DateTime.now();
    String selectedReason = 'مرض'; // الخيار الافتراضي
    bool isSubmitting = false;

    // الخيارات المطابقة تماماً للصورة
    final List<String> reasonsOptions = [
      'دراسة',
      'سفر',
      'مرض',
      'زيارة',
      'عمل',
      'حالة وفاة',
      'لم يحضر الطالب',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String dateFormatted = "${selectedDate.day}-${selectedDate.month}-${selectedDate.year}";

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xff1e293b).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.8), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // أيقونة رأس النافذة
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xffeab308).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.event_busy_rounded, color: Color(0xffeab308), size: 34),
                        ),
                        const SizedBox(height: 12),

                        // العنوان الرئيسي
                        Text(
                          'طلب إذن غياب',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: isDarkMode ? Colors.white : primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // اختيار تاريخ الغياب
                        GestureDetector(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "تاريخ الغياب: $dateFormatted",
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.white : primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.calendar_month_rounded, color: goldColor, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // عنوان اختيار سبب الغياب
                        Text(
                          'حدد سبب الغياب:',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // شبكة أزرار خيارات الأسباب المطابقة للصورة تماماً
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: reasonsOptions.map((reason) {
                            bool isSelected = selectedReason == reason;
                            // الزر الأخير يأخذ عرضاً عريضاً
                            bool isFullWidth = reason == 'لم يحضر الطالب';

                            return SizedBox(
                              width: isFullWidth ? 180 : 85,
                              height: 42,
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() => selectedReason = reason);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xffeab308)
                                        : (isDarkMode ? Colors.transparent : Colors.white),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xffeab308) : Colors.black87,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        reason,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDarkMode ? Colors.white : Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // زر إرسال الطلب الذهبي العريض
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xffeab308),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: isSubmitting ? null : () async {
                              setDialogState(() => isSubmitting = true);

                              try {
                                final studentId = _activeStudentDoc!.id;
                                final String dateForFirestore = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

                                // 🛑 الشرط الحاسم: فحص الفايربيس لمنع تكرار إرسال طلب لنفس اليوم
                                var existingRequestSnap = await FirebaseFirestore.instance
                                    .collection('leave_requests')
                                    .where('studentId', isEqualTo: studentId)
                                    .where('date', isEqualTo: dateForFirestore)
                                    .get();

                                if (existingRequestSnap.docs.isNotEmpty) {
                                  setDialogState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.deepOrange,
                                        content: Text('⚠️ تم تقديم طلب استئذان لهذا اليوم مسبقاً، يرجى انتظار رد المشرف.', style: TextStyle(fontFamily: 'Cairo')),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final sData = _activeStudentDoc!.data() as Map<String, dynamic>? ?? {};

                                // حفظ الطلب الجديد في Firestore
                                await FirebaseFirestore.instance.collection('leave_requests').add({
                                  'studentId': studentId,
                                  'studentName': sData['name'] ?? 'طالب',
                                  'supervisorId': sData['supervisorId'] ?? '',
                                  'supervisorName': sData['supervisorName'] ?? 'المشرف',
                                  'cycleId': _activeCycleId,
                                  'date': dateForFirestore,
                                  'reason': selectedReason,
                                  'status': 'pending',
                                  'requestTime': "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                // إرسال الإشعار للمدراء والمشرف
                                var managersSnap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'manager').get();
                                for (var mDoc in managersSnap.docs) {
                                  await NotificationService.sendAndSaveNotification(
                                    studentId: mDoc.id,
                                    title: "طلب استئذان جديد 📝",
                                    body: "قدم الطالب (${sData['name']}) طلب استئذان ليوم ($dateForFirestore) - السبب: $selectedReason",
                                    type: "leave_request",
                                  );
                                }

                                if ((sData['supervisorId'] ?? '').toString().isNotEmpty) {
                                  await NotificationService.sendAndSaveNotification(
                                    studentId: sData['supervisorId'],
                                    title: "طلب استئذان جديد 📝",
                                    body: "قدم الطالب (${sData['name']}) طلب استئذان ليوم ($dateForFirestore) - السبب: $selectedReason",
                                    type: "leave_request",
                                  );
                                }

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.green,
                                      content: Text('تم إرسال طلب الاستئذان بنجاح 🎉', style: TextStyle(fontFamily: 'Cairo')),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
                              }
                            },
                            child: isSubmitting
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text(
                                    'إرسال الطلب',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    if (_isLoading || _activeStudentDoc == null) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final Map<String, dynamic> data = _activeStudentDoc!.data() as Map<String, dynamic>? ?? {};

    final String studentId = _activeStudentDoc!.id;
    final String studentName = data['name'] ?? 'الطالب';
    final String serialStr = data['serial']?.toString() ?? '';
    final bool isCompletedStudent = data['studentType'] == 'completed';
    final String supervisorId = data['supervisorId'] ?? '';
    final String supervisorName = data['supervisorName'] ?? 'المشرف';

    Query sessionsQuery = FirebaseFirestore.instance
        .collection('sessions')
        .where('studentId', isEqualTo: studentId)
        .where('cycleId', isEqualTo: _activeCycleId);

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
          // 📝 زر إرسال طلب استئذان غياب
          IconButton(
            icon: Icon(Icons.event_note_rounded, color: isDarkMode ? goldColor : primaryColor),
            tooltip: 'طلب استئذان غياب',
            onPressed: () => _showLeaveRequestDialog(isDarkMode),
          ),
          if (siblings.isNotEmpty)
            IconButton(
              icon: Icon(Icons.people_alt_rounded, color: isDarkMode ? goldColor : primaryColor),
              tooltip: 'تبديل الأبناء',
              onPressed: () => _showLiquidSiblingSwitcher(isDarkMode),
            ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDarkMode ? goldColor : primaryColor),
            tooltip: isDarkMode ? 'تفعيل الوضع النهاري' : 'تفعيل الوضع الليلي',
            onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
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
                    top: -20 + _bgAnimation.value, left: -50 - (_bgAnimation.value / 2),
                    child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12))),
                  ),
                  Positioned(
                    bottom: 100 - _bgAnimation.value, right: -60 + _bgAnimation.value,
                    child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.2))),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            bottom: false,
            child: StreamBuilder<QuerySnapshot>(
              stream: sessionsQuery.snapshots(),
              builder: (context, sessionSnapshot) {
                int totalSessions = 0;
                int absentCount = 0;
                int excellentCount = 0;
                int goodCount = 0;
                int badCount = 0;
                List<QueryDocumentSnapshot> sortedDocs = [];

                if (sessionSnapshot.hasData && sessionSnapshot.data!.docs.isNotEmpty) {
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

                int totalMemorizedPages = int.tryParse(data['memorizedPages']?.toString() ?? '') ??
                                          int.tryParse(data['end_page']?.toString() ?? '') ??
                                          int.tryParse(data['lastPage']?.toString() ?? '') ?? 0;

                if (totalMemorizedPages == 0 && sortedDocs.isNotEmpty) {
                  var latestSessionData = sortedDocs.first.data() as Map<String, dynamic>?;
                  if (latestSessionData != null) {
                    totalMemorizedPages = int.tryParse(latestSessionData['memorizedPages']?.toString() ?? '') ??
                                          int.tryParse(latestSessionData['totalMemorizedPages']?.toString() ?? '') ?? 0;
                  }
                }

                return PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    if (_currentTabIndex != index) {
                      setState(() => _currentTabIndex = index);
                    }
                  },
                  children: [
                    SummaryTab(
                      studentData: {
                        ...data,
                        'customLastPage': totalMemorizedPages,
                      }, 
                      sessionSnapshot: sessionSnapshot, 
                      total: totalSessions, 
                      present: presentCount, 
                      absent: absentCount, 
                      excellent: excellentCount, 
                      good: goodCount, 
                      bad: badCount, 
                      isDarkMode: isDarkMode
                    ),
                    DailyLogTab(sortedDocs: sortedDocs, isCompletedStudent: isCompletedStudent, isDarkMode: isDarkMode),
                    ParentActivitiesPage(studentId: studentId, studentName: studentName),
                    HonorBoardTab(allWinners: allWinners, studentImagesCache: studentImagesCache, isHonorLoading: _isHonorLoading, currentStudentSerial: serialStr, isDarkMode: isDarkMode),
                    ParentChatTab(studentId: studentId, studentName: studentName, supervisorId: supervisorId, supervisorName: supervisorName, isDarkMode: isDarkMode),
                  ],
                );
              },
            ),
          ),
          _buildDraggableLiquidNavBar(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildDraggableLiquidNavBar(bool isDarkMode) {
    return Positioned(
      bottom: 25, left: 15, right: 15, height: 70,
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
                final itemWidth = constraints.maxWidth / 5;
                int closestIndex = _currentTabIndex;

                if (_isDragging && _dragPosition != null) {
                  closestIndex = ((_dragPosition! + (itemWidth / 2)) / itemWidth).round().clamp(0, 4);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    setState(() {
                      _isDragging = true;
                      _dragPosition = details.localPosition.dx - (itemWidth / 2);
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    bool isRtl = Directionality.of(context) == TextDirection.rtl;
                    setState(() {
                      _dragPosition = isRtl 
                          ? constraints.maxWidth - details.localPosition.dx - (itemWidth / 2) 
                          : details.localPosition.dx - (itemWidth / 2);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      _isDragging = false;
                      if (_dragPosition != null) {
                        int targetIndex = ((_dragPosition! + (itemWidth / 2)) / itemWidth).round().clamp(0, 4);
                        _onTabTapped(targetIndex);
                      }
                      _dragPosition = null;
                    });
                  },
                  onTapUp: (details) {
                    bool isRtl = Directionality.of(context) == TextDirection.rtl;
                    double tapPos = isRtl ? constraints.maxWidth - details.localPosition.dx : details.localPosition.dx;
                    int newIndex = (tapPos / itemWidth).floor().clamp(0, 4);
                    _onTabTapped(newIndex);
                  },
                  child: Stack(
                    children: [
                      AnimatedPositionedDirectional(
                        duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
                        curve: _isDragging ? Curves.linear : Curves.easeOutCubic,
                        start: _isDragging && _dragPosition != null 
                            ? _dragPosition!.clamp(0.0, constraints.maxWidth - itemWidth) 
                            : _currentTabIndex * itemWidth,
                        top: 0, bottom: 0,
                        child: Container(
                          width: itemWidth, alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                              child: Container(
                                width: 50, height: 50,
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
                          _buildNavItem(2, Icons.directions_bus_outlined, Icons.directions_bus_filled_rounded, 'الأنشطة', itemWidth, isDarkMode, closestIndex),
                          _buildNavItem(3, Icons.stars_outlined, Icons.stars_rounded, 'التميز', itemWidth, isDarkMode, closestIndex),
                          _buildNavItem(4, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'تواصل', itemWidth, isDarkMode, closestIndex), 
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
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: isHovered
            ? Icon(filledIcon, key: ValueKey('icon_selected_$index'), color: Colors.white, size: 26)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center, key: ValueKey('icon_unselected_$index'),
                children: [
                  Icon(outlineIcon, color: isDarkMode ? Colors.white54 : primaryColor.withOpacity(0.5), size: 22),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(color: isDarkMode ? Colors.white54 : primaryColor.withOpacity(0.7), fontSize: 9, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }

  String _getAppBarTitle(int index, String studentName) {
    switch (index) {
      case 0: return 'ملخص أداء: $studentName';
      case 1: return 'السجل اليومي للحفظ والمراجعة';
      case 2: return 'دعوات الرحلات والأنشطة 🚌';
      case 3: return 'لوحة الشرف والتميز';
      case 4: return 'التواصل مع المشرف'; 
      default: return 'متابعة الطالب';
    }
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
                              transitionDuration: const Duration(milliseconds: 300),
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