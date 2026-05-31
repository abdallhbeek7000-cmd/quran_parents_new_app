import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SummaryTab extends StatelessWidget {
  final Map<String, dynamic> studentData;
  final AsyncSnapshot<QuerySnapshot> sessionSnapshot;
  final int total;
  final int present;
  final int absent;
  final int excellent;
  final int good;
  final int bad;
  final bool isDarkMode;

  const SummaryTab({
    super.key,
    required this.studentData,
    required this.sessionSnapshot,
    required this.total,
    required this.present,
    required this.absent,
    required this.excellent,
    required this.good,
    required this.bad,
    required this.isDarkMode,
  });

  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 120, top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✨ 0. إشراقة اليوم
          _buildDailyInspiration(),

          // 💳 1. الهوية الرقمية الزجاجية (مع النبض المباشر)
          _buildDigitalGlassID(studentData),
          
          // 📖 2. مستوى تقدم الختمة
          _buildQuranProgressSection(),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text("📊 لوحة الأداء والإحصائيات الحية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
          ),
          
          // 📊 3. الإحصائيات الحية
          _buildParentStatsDashboard(),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDailyInspiration() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('general').snapshots(),
      builder: (context, settingsSnapshot) {
        bool isActive = true;
        if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
          isActive = (settingsSnapshot.data!.data() as Map<String, dynamic>)['is_inspiration_active'] ?? true;
        }

        if (!isActive) return const SizedBox.shrink(); 

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('inspirations').orderBy('createdAt').get(),
          builder: (context, inspirationSnapshot) {
            if (!inspirationSnapshot.hasData || inspirationSnapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final docs = inspirationSnapshot.data!.docs;
            final now = DateTime.now();
            int dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
            int selectedIndex = (dayOfYear + now.year) % docs.length; 
            
            var data = docs[selectedIndex].data() as Map<String, dynamic>;
            String text = data['text'] ?? '';
            String source = data['source'] ?? '';

            return Container(
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
              child: _buildGlassContainer(
                customColor: isDarkMode ? goldColor.withOpacity(0.08) : goldColor.withOpacity(0.12),
                customBorderColor: goldColor.withOpacity(0.4),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wb_sunny_rounded, color: isDarkMode ? goldColor : Colors.orange.shade600, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("إشراقة اليوم ✨", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
                          const SizedBox(height: 6),
                          Text(
                            text,
                            style: TextStyle(fontSize: 12.5, color: isDarkMode ? Colors.white70 : Colors.grey.shade800, height: 1.5, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                          ),
                          if (source.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: goldColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text(source, style: TextStyle(fontSize: 9, color: isDarkMode ? goldColor : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            )
                          ]
                        ],
                      ),
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

  // 💳 دالة بناء الهوية الرقمية الزجاجية للطالب
  Widget _buildDigitalGlassID(Map<String, dynamic> data) {
    String studentName = data['name'] ?? 'اسم الطالب';
    var exactSerial = data['serial']; // 🎯 أخذ القيمة تماماً كما هي في فايربيز بدون تحويل
    String serialNumStr = exactSerial?.toString() ?? '---';
    String grade = data['schoolGrade'] ?? 'غير محدد';
    String supervisor = data['supervisorName'] ?? 'غير محدد'; 
    String phone = data['phone'] ?? '---';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode 
                    ? [goldColor.withOpacity(0.15), primaryColor.withOpacity(0.3)] 
                    : [Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDarkMode ? goldColor.withOpacity(0.3) : Colors.white.withOpacity(0.8), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: isDarkMode ? goldColor : primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text("معهد الشيخ سعيد العبدالله", style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.grey.shade700)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: (isDarkMode ? goldColor : primaryColor).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text("هوية رقمية", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDarkMode ? goldColor : primaryColor, fontFamily: 'Cairo')),
                    )
                  ],
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Divider(height: 1, color: isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05)),
                ),

                Row(
                  children: [
                    Container(
                      width: 75, height: 75,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isDarkMode ? goldColor : primaryColor.withOpacity(0.5), width: 2.5),
                        boxShadow: [BoxShadow(color: (isDarkMode ? goldColor : primaryColor).withOpacity(0.2), blurRadius: 15)]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                            ? CachedNetworkImage(imageUrl: data['imageUrl'], fit: BoxFit.cover, placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), errorWidget: (c, u, e) => _buildAvatarPlaceholder(studentName))
                            : _buildAvatarPlaceholder(studentName),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        // 🎯 تم إصلاح استعلام الفايربيز هنا
                        stream: FirebaseFirestore.instance.collection('students').where('serial', isEqualTo: exactSerial).limit(1).snapshots(),
                        builder: (context, snapshot) {
                          String pulse = 'none';
                          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                            pulse = (snapshot.data!.docs.first.data() as Map<String, dynamic>)['livePulse'] ?? 'none';
                          }

                          Color dotColor = Colors.transparent;
                          String pulseLabel = "";
                          if (pulse == 'green') { dotColor = Colors.greenAccent.shade400; pulseLabel = "يُسمِّع"; }
                          else if (pulse == 'yellow') { dotColor = Colors.amber; pulseLabel = "يراجع"; }
                          else if (pulse == 'blue') { dotColor = Colors.lightBlueAccent; pulseLabel = "أتم التسميع"; }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      studentName, 
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo', height: 1.2),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (pulse != 'none') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: dotColor.withOpacity(isDarkMode ? 0.15 : 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: dotColor.withOpacity(0.4)),
                                      ),
                                      child: LivePulseDot(color: dotColor, label: pulseLabel),
                                    ),
                                  ]
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: isDarkMode ? Colors.black26 : Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pin_rounded, size: 14, color: isDarkMode ? Colors.white70 : Colors.grey.shade700),
                                    const SizedBox(width: 6),
                                    Text("الرقم التسلسلي: $serialNumStr", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: isDarkMode ? Colors.white70 : Colors.grey.shade800, letterSpacing: 0.5)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(child: _buildInfoChip(Icons.school_rounded, "المرحلة", grade)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInfoChip(Icons.person_pin_rounded, "المشرف", supervisor)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInfoChip(Icons.phone_android_rounded, "الهاتف", phone)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: isDarkMode ? primaryColor : primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1) : '?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: isDarkMode ? goldColor : primaryColor.withOpacity(0.8)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, color: isDarkMode ? Colors.white54 : Colors.grey.shade600, fontFamily: 'Cairo')),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildParentStatsDashboard() {
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 55, height: 55,
                            child: CircularProgressIndicator(value: attendanceRate, strokeWidth: 5, backgroundColor: isDarkMode ? Colors.green.withOpacity(0.1) : Colors.green.shade50, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)),
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 55, height: 55,
                            child: CircularProgressIndicator(value: excellentRate, strokeWidth: 5, backgroundColor: isDarkMode ? goldColor.withOpacity(0.1) : const Color(0xfffef9e7), valueColor: AlwaysStoppedAnimation<Color>(goldColor)),
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
              Expanded(child: _buildModernStatMiniCard(title: "المستوى المتميز", value: "$excellent", icon: Icons.auto_awesome_rounded, baseColor: goldColor)),
              const SizedBox(width: 10),
              Expanded(child: _buildModernStatMiniCard(title: "المستوى المستقر", value: "$good", icon: Icons.thumb_up_alt_rounded, baseColor: Colors.blue.shade500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildModernStatMiniCard(title: "يحتاج متابعة وتكرار", value: "$bad", icon: Icons.trending_down_rounded, baseColor: Colors.redAccent.shade400)),
              const SizedBox(width: 10),
              Expanded(child: _buildModernStatMiniCard(title: "جلسات الغياب", value: "$absent", icon: Icons.cancel_presentation_rounded, baseColor: absent >= 3 ? Colors.redAccent : Colors.grey.shade500, badgeText: absent >= 3 ? "تنبيه غياب! ⚠️" : null)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatMiniCard({required String title, required String value, required IconData icon, required Color baseColor, String? badgeText}) {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(15),
      customColor: baseColor.withOpacity(isDarkMode ? 0.1 : 0.05),
      customBorderColor: baseColor.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: baseColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: baseColor, size: 18)),
              if (badgeText != null)
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)), child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 8, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
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

  Widget _buildQuranProgressSection() {
    double savedPages = 0.0;
    if (sessionSnapshot.hasData && sessionSnapshot.data!.docs.isNotEmpty) {
      var sessionDocs = sessionSnapshot.data!.docs;
      List<QueryDocumentSnapshot> sortedSessions = List.from(sessionDocs)..retainWhere((doc) => ((doc.data() as Map)['absent'] == false && (doc.data() as Map)['isExam'] == false));
      sortedSessions.sort((a, b) => ((b.data() as Map)['date']?.toString() ?? '').compareTo((a.data() as Map)['date']?.toString() ?? ''));
      for (var doc in sortedSessions) {
        if ((doc.data() as Map).containsKey('total_memorized_pages') && (doc.data() as Map)['total_memorized_pages'] != null) {
          savedPages = ((doc.data() as Map)['total_memorized_pages'] as num).toDouble();
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
        padding: const EdgeInsets.all(18),
        customBorderColor: Colors.teal.withOpacity(0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: isDarkMode ? Colors.tealAccent : Colors.teal, size: 18),
                const SizedBox(width: 8),
                Text("مستوى تقدم الطالب في الختمة 👑", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("تم تمكين $savedPages من أصل 604 صفحة", style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text("${(progressPercentage * 100).toStringAsFixed(1)}%", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDarkMode ? Colors.tealAccent : Colors.teal.shade900, fontFamily: 'Cairo'))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progressPercentage, minHeight: 8, backgroundColor: isDarkMode ? Colors.white12 : Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(isDarkMode ? Colors.tealAccent : Colors.teal.shade500))),
            const SizedBox(height: 12),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDarkMode ? Colors.tealAccent.withOpacity(0.05) : Colors.teal.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.1))),
              child: Row(
                children: [
                  Icon(Icons.favorite_rounded, color: Colors.red.shade400, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(remainingPages == 0 ? "مبارك! للطالب ختم كتاب الله كاملاً، هنيئاً لك 🎉👑" : "متبقي للطالب [ ${remainingPages.toStringAsFixed(0)} صفحة ] ويختم كتاب الله كاملاً ✨", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor, height: 1.4, fontFamily: 'Cairo'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }
}

// 🔴 أنيميشن النبض الحي 
class LivePulseDot extends StatefulWidget {
  final Color color;
  final String label;

  const LivePulseDot({super.key, required this.color, required this.label});

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4 + (_controller.value * 0.4)),
                    blurRadius: 4 + (_controller.value * 6),
                    spreadRadius: 1 + (_controller.value * 2),
                  )
                ]
              ),
            );
          }
        ),
        const SizedBox(width: 8),
        Text(widget.label, style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Cairo')),
      ],
    );
  }
}