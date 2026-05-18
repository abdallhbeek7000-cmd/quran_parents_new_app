import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

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
                          // 🔥 تصفير ومسح الحساب من الذاكرة لكي لا يدخل تلقائياً في المرة القادمة
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildProfileCard(data)),
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sessions')
                .where('studentId', isEqualTo: studentId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text("لا يوجد جلسات مسجلة بعد لهذا الطالب", style: TextStyle(color: Colors.grey[600])),
                    ),
                  ),
                );
              }

              var docs = snapshot.data!.docs;
              docs.sort((a, b) {
                String aDate = (a.data() as Map<String, dynamic>)['date']?.toString() ?? '';
                String bDate = (b.data() as Map<String, dynamic>)['date']?.toString() ?? '';
                return bDate.compareTo(aDate);
              });

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    var session = docs[index].data() as Map<String, dynamic>;
                    return _buildSessionItem(session);
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.all(20),
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

  Widget _buildHonorBoardSection(String currentStudentSerial) {
    if (_isHonorLoading) {
      return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
    }
    if (allWinners.isEmpty) {
      return const SizedBox(height: 140, child: Center(child: Text("سيتم إعلان الفرسان قريباً", style: TextStyle(fontSize: 13, color: Colors.grey))));
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
    final String rating = session['rating'] ?? 'ممتاز';

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
              _buildGradeBadge(rating),
            ],
          ),
          const Divider(height: 20),
          _buildSessionDetail(Icons.star, "الحفظ الجديد:", session['newMemorization'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.menu_book, "مراجعة قريب:", session['nearReview'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.history_toggle_off, "مراجعة بعيد:", session['farReview'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.chrome_reader_mode_outlined, "قراءة نظراً:", session['readingBySight'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.assignment_outlined, "الواجب:", session['homework'] ?? '---'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.emoji_emotions_outlined, "حالة الطالب:", session['studentStatus'] ?? 'مهذب'),
          const SizedBox(height: 8),
          _buildSessionDetail(Icons.brightness_auto_outlined, "الأنشطة الدينية:", session['religiousActivities'] ?? '---'),
          if (session['notes'] != null && session['notes'].toString().trim().isNotEmpty) ...[
            const Divider(height: 20),
            Text("📝 ملاحظة المشرف: ${session['notes']}", style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
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

  Widget _buildGradeBadge(String rating) {
    Color badgeColor = Colors.green;
    if (rating == 'جيد جداً' || rating == 'جيد') badgeColor = Colors.orange;
    if (rating == 'مقبول' || rating == 'ضعيف') badgeColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
      child: Text(rating, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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