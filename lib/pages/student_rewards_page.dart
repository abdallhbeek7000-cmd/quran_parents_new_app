import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/notification_service.dart'; // 🚀 استيراد خدمة الإشعارات الخاصة بالتطبيق

class StudentRewardsPage extends StatefulWidget {
  final DocumentSnapshot studentDoc;

  const StudentRewardsPage({super.key, required this.studentDoc});

  @override
  State<StudentRewardsPage> createState() => _StudentRewardsPageState();
}

class _StudentRewardsPageState extends State<StudentRewardsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  // 🔮 🚀 المحرك السحري لإشعار السائل الزجاجي الذي ينزلق بفخامة من الأعلى بصفحة الطالب
  void _showTopPremiumToast({required String message, required IconData icon, required Color statusColor, required bool isDark}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 15, // النزول أسفل النوتش والكاميرا بالملي
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0), // انزلاق انسيابي من فوق
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Opacity(
                  opacity: (value + 100) / 100,
                  child: child,
                ),
              );
            },
            child: Directionality(
              textDirection: TextDirection.rtl, // دعم التوجيه العربي
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // بلور زجاجي نقي خلف التنبيه
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xff1e293b).withOpacity(0.85) : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.06), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(icon, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  // 🪙 دالة استبدال المكافأة مصلحة ومربوطة بالسالب والتنبيهات العلوية
  void _claimReward(BuildContext context, Map<String, dynamic> rewardData, String rewardId, int currentPoints, DocumentReference studentRef) async {
    int rewardCost = (rewardData['pointsRequired'] ?? 0).toInt(); 
    String rewardName = rewardData['name'] ?? 'جائزة مجهولة'; 
    String supervisorId = widget.studentDoc['supervisorId'] ?? ''; 
    String studentName = widget.studentDoc['name'] ?? 'طالب';
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentPoints < rewardCost) {
      // 🚀 إطلاق تنبيه علوي منزلق عند نقص النقاط
      _showTopPremiumToast(message: 'عذراً! رصيد نقاطك الحالي لا يكفي لشراء هذه الجائزة 🌟', icon: Icons.warning_amber_rounded, statusColor: Colors.orangeAccent, isDark: isDark);
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: goldColor.withOpacity(0.4), width: 1.5)),
        title: const Text('تأكيد استبدال الجائزة 🎁', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
        content: Text('هل أنت متأكد من رغبتك في استبدال $rewardCost نقطة مقابل [$rewardName]؟ سيتم خصم النقاط فوراً وإبلاغ الإدارة.', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: goldColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الاستبدال', style: TextStyle(fontFamily: 'Cairo', color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot freshStudentSnap = await transaction.get(studentRef);
        int freshPoints = (freshStudentSnap.data() as Map<String, dynamic>)['points'] ?? 0;

        if (freshPoints < rewardCost) return;

        transaction.update(studentRef, {'points': freshPoints - rewardCost});

        DocumentReference requestRef = FirebaseFirestore.instance.collection('reward_requests').doc();
        transaction.set(requestRef, {
          'requestId': requestRef.id,
          'studentName': widget.studentDoc['name'] ?? 'طالب',
          'studentSerial': widget.studentDoc['serial']?.toString() ?? '---',
          'studentId': widget.studentDoc.id,
          'rewardId': rewardId,
          'rewardTitle': rewardName,
          'cost': rewardCost,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        DocumentReference historyRef = FirebaseFirestore.instance.collection('points_history').doc();
        
        transaction.set(historyRef, {
          'studentId': widget.studentDoc.id,
          'pointsAdded': -rewardCost, 
          'reason': 'استبدال جائزة: $rewardName 🎁',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (supervisorId.isNotEmpty) {
        NotificationService.sendAndSaveNotification(
          studentId: supervisorId, 
          title: "🎁 طلب استبدال نقاط جديد",
          body: "قام الطالب $studentName باستبدال $rewardCost نقطة مقابل [$rewardName] بانتظار التسليم.",
          type: "reward_request_pending",
          context: context,
        ).catchError((error) {
          print("فشل إرسال إشعار المكافأة للمشرف: $error");
        });
      }

      // 🚀 السحر هنا: تم التبديل إلى التنبيه الزجاجي الانزلاقي من الأعلى بنجاح عند نجاح العملية الكلية
      _showTopPremiumToast(message: '🎉 تم إرسال طلبك بنجاح! متبقي لديك ${currentPoints - rewardCost} نقطة.', icon: Icons.check_circle_rounded, statusColor: Colors.green.shade600, isDark: isDark);
    } catch (e) {
      _showTopPremiumToast(message: 'حدث خطأ أثناء المعالجة: $e', icon: Icons.error_outline_rounded, statusColor: Colors.redAccent, isDark: isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('students').doc(widget.studentDoc.id).snapshots(),
      builder: (context, snapshot) {
        final Map<String, dynamic> data = snapshot.hasData && snapshot.data!.data() != null
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.studentDoc.data() as Map<String, dynamic>;

        int userPoints = data['points'] ?? 0;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode 
                  ? [const Color(0xff0d161d), const Color(0xff182530)] 
                  : [const Color(0xfff5f7f9), const Color(0xffe4ebf0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent, 
            extendBodyBehindAppBar: true, 
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: Text('لوحة الجوائز والمكافآت 🏆', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontSize: 15)),
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDarkMode ? Colors.white : primaryColor, size: 18), 
                onPressed: () => Navigator.pop(context),
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: goldColor,
                unselectedLabelColor: isDarkMode ? Colors.white70 : primaryColor.withOpacity(0.7),
                indicatorColor: goldColor,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: '🎁 متجر الهدايا', icon: Icon(Icons.shopping_bag_rounded, size: 18)),
                  Tab(text: '📊 سجل نقاطي', icon: Icon(Icons.history_edu_rounded, size: 18)),
                ],
              ),
            ),
            body: Stack(
              children: [
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
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildLiquidGlassContainer(
                          isDarkMode: isDarkMode,
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('رصيدك المتاح للاستبدال', style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : primaryColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(data['name'] ?? 'اسم الطالب', style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor, fontSize: 16, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('$userPoints', style: TextStyle(fontFamily: 'Cairo', color: goldColor, fontSize: 34, fontWeight: FontWeight.w900, shadows: [Shadow(color: goldColor.withOpacity(0.3), blurRadius: 8)])),
                                  const SizedBox(width: 6),
                                  Text('نقطة', style: TextStyle(fontFamily: 'Cairo', color: goldColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRewardsStoreTab(isDarkMode, userPoints, snapshot.data?.reference),
                            _buildPointsHistoryTab(isDarkMode),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardsStoreTab(bool isDarkMode, int currentPoints, DocumentReference? studentRef) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rewards').snapshots(), 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLiquidGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(16),
                  child: Icon(Icons.card_giftcard_rounded, size: 48, color: isDarkMode ? Colors.white38 : Colors.grey.shade400),
                ),
                const SizedBox(height: 14),
                Text('لا توجد جوائز متاحة بالمتجر حالياً 🗓️', style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white60 : primaryColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        var rewards = snapshot.data!.docs;

        double width = MediaQuery.of(context).size.width;
        int crossAxisCount = width > 700 ? 4 : 2; 
        double aspectRatio = width > 700 ? 1.05 : 0.82; 

        return GridView.builder(
          padding: const EdgeInsets.all(18),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: aspectRatio,
          ),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            var reward = rewards[index].data() as Map<String, dynamic>;
            int cost = (reward['pointsRequired'] ?? 0).toInt();
            bool isAvailable = currentPoints >= cost;
            String imgUrl = reward['imageUrl']?.toString() ?? '';

            return _buildLiquidGlassContainer(
              isDarkMode: isDarkMode,
              padding: EdgeInsets.zero,
              customColor: isAvailable 
                  ? (isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55))
                  : (isDarkMode ? Colors.white.withOpacity(0.005) : Colors.black.withOpacity(0.015)),
              customBorderColor: isAvailable ? goldColor.withOpacity(0.4) : Colors.white.withOpacity(0.15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (isAvailable ? goldColor : Colors.grey).withOpacity(0.12),
                            (isAvailable ? goldColor : Colors.grey).withOpacity(0.01)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                      ),
                      child: imgUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                              child: CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => Icon(Icons.card_giftcard_rounded, color: isAvailable ? goldColor : Colors.grey.shade500, size: 30)),
                            )
                          : Icon(Icons.card_giftcard_rounded, color: isAvailable ? goldColor : Colors.grey.shade500, size: 30),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reward['name'] ?? 'جائزة متميزة', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$cost ن', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w900, color: goldColor)),
                            InkWell(
                              onTap: () => _claimReward(context, reward, rewards[index].id, currentPoints, studentRef!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: isAvailable 
                                      ? LinearGradient(colors: [goldColor, goldColor.withOpacity(0.8)])
                                      : LinearGradient(colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)]),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isAvailable ? [BoxShadow(color: goldColor.withOpacity(0.15), blurRadius: 4)] : null,
                                ),
                                child: Text('استبدل', style: TextStyle(fontFamily: 'Cairo', fontSize: 9.5, fontWeight: FontWeight.bold, color: isAvailable ? Colors.black : Colors.grey.shade600)),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPointsHistoryTab(bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('points_history')
          .where('studentId', isEqualTo: widget.studentDoc.id)
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
                _buildLiquidGlassContainer(
                  isDarkMode: isDarkMode,
                  padding: const EdgeInsets.all(16),
                  child: Icon(Icons.history_toggle_off_rounded, size: 48, color: isDarkMode ? Colors.white38 : Colors.grey.shade400),
                ),
                const SizedBox(height: 14),
                Text('سجل النقاط فارغ، لا توجد عمليات حالياً 📋', style: TextStyle(fontFamily: 'Cairo', color: isDarkMode ? Colors.white60 : primaryColor.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        var historyDocs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
        historyDocs.sort((a, b) {
          var tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          var tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA); 
        });

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          physics: const BouncingScrollPhysics(),
          itemCount: historyDocs.length,
          itemBuilder: (context, index) {
            var log = historyDocs[index].data() as Map<String, dynamic>;
            int amount = (log['pointsAdded'] ?? 0).toInt();
            bool isAddition = amount > 0;
            Color statusColor = isAddition ? Colors.greenAccent.shade400 : Colors.redAccent;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: _buildLiquidGlassContainer(
                isDarkMode: isDarkMode,
                padding: const EdgeInsets.all(14),
                customColor: isAddition 
                    ? (isDarkMode ? Colors.green.withOpacity(0.01) : Colors.green.withOpacity(0.03))
                    : (isDarkMode ? Colors.red.withOpacity(0.01) : Colors.red.withOpacity(0.03)),
                customBorderColor: statusColor.withOpacity(0.18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isAddition ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                            color: statusColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log['reason'] ?? 'عملية غير مسماة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor)),
                            const SizedBox(height: 2),
                            Text(
                              isAddition ? 'مكافأة تميز من الإدارة 🎉' : 'استبدل مكافأة من المتجر',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: isDarkMode ? Colors.white60 : Colors.grey.shade600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      isAddition ? '+$amount' : '$amount', 
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: isAddition ? Colors.greenAccent.shade700 : Colors.redAccent),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiquidGlassContainer({required bool isDarkMode, required Widget child, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.45)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: customBorderColor ?? (isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.6)), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: child,
         ),
      ),
    );
  }
}