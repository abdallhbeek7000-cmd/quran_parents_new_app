import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyLogTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> sortedDocs;
  final bool isCompletedStudent;
  final bool isDarkMode;

  const DailyLogTab({
    super.key,
    required this.sortedDocs,
    required this.isCompletedStudent,
    required this.isDarkMode,
  });

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffd4af37);

  @override
  Widget build(BuildContext context) {
    if (sortedDocs.isEmpty) {
      return Center(
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(20),
          child: Text(
            "لا يوجد جلسات مسجلة بعد لهذا الطالب",
            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[600], fontFamily: 'Cairo', fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 120), 
      itemCount: sortedDocs.length,
      itemBuilder: (context, index) {
        var session = sortedDocs[index].data() as Map<String, dynamic>;
        return _buildSessionItem(session);
      },
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final String sessionDate = session['date']?.toString() ?? 'بدون تاريخ';
    final bool isAbsent = session['absent'] ?? false;
    final bool isExam = session['isExam'] ?? false; 
    final String supervisorName = session['supervisorName'] ?? 'غير محدد';

    if (isAbsent) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: _buildGlassContainer(
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
                    _buildMinimalistDetailRow(Icons.person_outline_rounded, "المشرف المسجِّل", supervisorName, isBold: true),
                    const SizedBox(height: 10),
                    _buildMinimalistDetailRow(Icons.warning_amber_rounded, "نوع الغياب", session['absenceType'] == "" ? "بدون عذر" : (session['absenceType'] ?? 'بدون عذر')),
                    if (session['absenceReason'] != null && session['absenceReason'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildMinimalistDetailRow(Icons.info_outline_rounded, "سبب الغياب", session['absenceReason']),
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
                    _buildMinimalistDetailRow(Icons.person_outline_rounded, "المشرف المسجِّل", supervisorName, isBold: true),
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

    // 🚀 جلب التقييمات بذكاء للحلقات العادية
    String memRating = session['memorizationRating'] ?? "";
    String revRating = session['reviewRating'] ?? "";
    
    if (memRating.isEmpty && session['rating'] != null && session['rating'].toString().isNotEmpty && session['newMemorization'] != null && session['newMemorization'].toString().isNotEmpty) {
      memRating = session['rating'];
    }
    if (revRating.isEmpty && session['rating'] != null && session['rating'].toString().isNotEmpty && !isCompletedStudent && memRating.isEmpty) {
      revRating = session['rating'];
    } else if (revRating.isEmpty && session['rating'] != null && session['rating'].toString().isNotEmpty && isCompletedStudent) {
      revRating = session['rating']; 
    }

    // 🚀 جلب بيانات الإنجاز
    String nMemo = session['newMemorization']?.toString().trim() ?? '';
    String nRev = session['nearReview']?.toString().trim() ?? '';
    String fRev = session['farReview']?.toString().trim() ?? (isCompletedStudent ? (session['review']?.toString().trim() ?? '') : '');
    String sight = session['readingBySight']?.toString().trim() ?? '';

    // 🚀 جلب بيانات الواجب الثلاثية
    String nHw = session['newHomework']?.toString().trim() ?? '';
    String nRevHw = session['newReviewHomework']?.toString().trim() ?? '';
    String oRevHw = session['oldReviewHomework']?.toString().trim() ?? '';
    String oldHw = session['homework']?.toString().trim() ?? '';

    // 🚀 بناء مربعات الإنجاز بشكل ديناميكي
    List<Widget> activeBoxes = [];
    if (isCompletedStudent && fRev.isNotEmpty) {
      activeBoxes.add(_buildGridInfoBox(Icons.verified_user_rounded, "المقدار المسموع من مراجعة الختمة الشاملة", fRev, isDarkMode ? Colors.tealAccent : Colors.teal));
    } else {
      if (nMemo.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.star_rounded, "الحفظ الجديد", nMemo, Colors.amber));
      if (nRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.menu_book_rounded, "مراجعة جديد", nRev, isDarkMode ? Colors.tealAccent : Colors.teal));
      if (fRev.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.history_toggle_off_rounded, "مراجعة قديم", fRev, Colors.blueGrey));
    }
    if (sight.isNotEmpty) activeBoxes.add(_buildGridInfoBox(Icons.chrome_reader_mode_rounded, "قراءة نظراً", sight, Colors.indigoAccent));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: _buildGlassContainer(
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
                      if (isCompletedStudent && revRating.isNotEmpty)
                        _buildCustomBadge("مراجعة الختمة: $revRating", isDarkMode ? Colors.white : _getRatingColor(revRating), _getRatingColor(revRating).withOpacity(isDarkMode ? 0.4 : 0.2)),
                      if (!isCompletedStudent) ...[
                        if (memRating.isNotEmpty) ...[
                          _buildCustomBadge("حفظ: $memRating", isDarkMode ? Colors.white : _getRatingColor(memRating), _getRatingColor(memRating).withOpacity(isDarkMode ? 0.4 : 0.2)),
                          const SizedBox(width: 5),
                        ],
                        if (revRating.isNotEmpty)
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
                  _buildMinimalistDetailRow(Icons.person_pin_rounded, "مشرف الجلسة", supervisorName, isBold: true),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : const Color(0xfff1f5f9))),
                  
                  // 🚀 عرض المربعات الديناميكية للإنجاز 
                  if (activeBoxes.isNotEmpty) ...[
                    for (int i = 0; i < activeBoxes.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(child: activeBoxes[i]),
                            const SizedBox(width: 10),
                            if (i + 1 < activeBoxes.length)
                              Expanded(child: activeBoxes[i + 1])
                            else
                              Expanded(child: const SizedBox()), 
                          ],
                        ),
                      ),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : const Color(0xfff1f5f9))),
                  ],
                  
                  // 🚀 صندوق الواجب المستقل والأنيق لتطبيق الأهل
                  if (nHw.isNotEmpty || nRevHw.isNotEmpty || oRevHw.isNotEmpty || oldHw.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentGold.withOpacity(isDarkMode ? 0.05 : 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: accentGold.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book, size: 16, color: accentGold),
                              const SizedBox(width: 6),
                              Text(isCompletedStudent ? "المقدار المطلوب للمرة القادمة:" : "الواجب القادم:", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (nHw.isNotEmpty) _buildHomeworkRow("حفظ جديد", nHw),
                          if (nRevHw.isNotEmpty) _buildHomeworkRow("مراجعة جديد", nRevHw),
                          if (oRevHw.isNotEmpty) _buildHomeworkRow(isCompletedStudent ? "مراجعة الختمة" : "مراجعة قديم", oRevHw),
                          if (oldHw.isNotEmpty && nHw.isEmpty && nRevHw.isEmpty && oRevHw.isEmpty) _buildHomeworkRow("الواجب", oldHw),
                        ],
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: isDarkMode ? Colors.white24 : const Color(0xfff1f5f9))),
                  ],

                  const SizedBox(height: 8),
                  _buildMinimalistDetailRow(Icons.emoji_emotions_outlined, "حالة سلوك الطالب بالحلقة", session['studentStatus'] ?? 'مهذب'),
                  
                  if (session['religiousActivities'] != null && session['religiousActivities'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildMinimalistDetailRow(Icons.mosque_outlined, "الأنشطة والدروس الدينية", session['religiousActivities']),
                  ],
                  
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

  // 🚀 أداة فرعية لعرض سطور الواجب بشكل مرتب
  Widget _buildHomeworkRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• $label: ", style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black54, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(IconData icon, String title, String val, Color iconColor) {
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
              Expanded(child: Text(title, style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white60 : Colors.grey[700], fontWeight: FontWeight.bold, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)),
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

  Widget _buildMinimalistDetailRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: isDarkMode ? accentGold : primaryColor.withOpacity(0.6)),
        ),
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