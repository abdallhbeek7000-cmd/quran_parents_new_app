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

  DateTime _parseDate(String dateStr) {
    try {
      List<String> parts = dateStr.split('-');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (e) {
      return DateTime(2000);
    }
    return DateTime(2000);
  }

  String _getArabicDayName(String dateString) {
    try {
      List<String> parts = dateString.split('-');
      if (parts.length == 3) {
        int year = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int day = int.parse(parts[2]);
        DateTime date = DateTime(year, month, day);
        const List<String> arabicDays = [
          'الإثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'السبت',
          'الأحد'
        ];
        return arabicDays[date.weekday - 1];
      }
    } catch (e) {
      return "";
    }
    return "";
  }

  Future<String?> _getActiveCycleId() async {
    try {
      var cyclesSnap =
          await FirebaseFirestore.instance.collection('cycles').get();

      if (cyclesSnap.docs.isNotEmpty) {
        for (var doc in cyclesSnap.docs) {
          var data = doc.data();
          bool isCurrent = data['isCurrent'] == true;
          bool isActive =
              data['status'] == 'active' || data['active'] == true;
          bool isNotClosed =
              data['isClosed'] != true && data['archived'] != true;

          if ((isCurrent || isActive) && isNotClosed) {
            return doc.id;
          }
        }
      }
    } catch (e) {
      debugPrint("خطأ في جلب الدورة الفعالة للسجل اليومي: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getActiveCycleId(),
      builder: (context, cycleSnap) {
        if (cycleSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        String? activeCycleId = cycleSnap.data;

        List<QueryDocumentSnapshot> activeCycleDocs = sortedDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String docCycleId = data['cycleId']?.toString().trim() ?? '';

          if (activeCycleId != null && activeCycleId.isNotEmpty) {
            return docCycleId == activeCycleId;
          }
          return true;
        }).toList();

        if (activeCycleDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildGlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 56,
                      color: isDarkMode
                          ? accentGold.withOpacity(0.7)
                          : primaryColor.withOpacity(0.45),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "لا توجد جلسات مسجلة في الدورة الحالية لهذا الطالب",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : primaryColor,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        List<QueryDocumentSnapshot> finalSortedList =
            List.from(activeCycleDocs);
        finalSortedList.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;

          DateTime dateAObj = _parseDate(dataA['date'] ?? '');
          DateTime dateBObj = _parseDate(dataB['date'] ?? '');

          int dateComparison = dateBObj.compareTo(dateAObj);

          if (dateComparison == 0) {
            Timestamp? tA =
                (dataA['createdAt'] ?? dataA['timestamp']) as Timestamp?;
            Timestamp? tB =
                (dataB['createdAt'] ?? dataB['timestamp']) as Timestamp?;
            if (tA != null && tB != null) return tB.compareTo(tA);
            if (tA == null && tB != null) return -1;
            if (tB == null && tA != null) return 1;
          }
          return dateComparison;
        });

        // تثبيت أرقام الجلسات مسبقاً مع استثناء أيام العطل الرسمية
        int normalSessionsTotal = finalSortedList.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['isHoliday'] != true && d['sessionType'] != 'holiday';
        }).length;

        int counter = normalSessionsTotal;
        final List<Map<String, dynamic>> preparedItems =
          finalSortedList.map<Map<String, dynamic>>((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final bool isHoliday =
              d['isHoliday'] == true || d['sessionType'] == 'holiday';
          final int fixedNumber = isHoliday ? 0 : counter--;
          return {
            'id': doc.id,
            'data': d,
            'isHoliday': isHoliday,
            'sessionNumber': fixedNumber,
          };
        }).toList();

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 10, bottom: 120),
          itemCount: preparedItems.length,
          itemBuilder: (context, index) {
            final item = preparedItems[index];
            return KeyedSubtree(
              key: ValueKey(item['id']),
              child: _buildSessionItem(
                item['data'] as Map<String, dynamic>,
                item['sessionNumber'] as int,
                isHoliday: item['isHoliday'] as bool,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionItem(
    Map<String, dynamic> session,
    int sessionNumber, {
    bool isHoliday = false,
  }) {
    final String sessionDateRaw = session['date']?.toString() ?? 'بدون تاريخ';
    final String dayName = _getArabicDayName(sessionDateRaw);
    final String displayDate =
        dayName.isNotEmpty ? "$dayName، $sessionDateRaw" : sessionDateRaw;

    // 🌴 تصميم بطاقة العطلة الرسمية مطابق لتطبيق المشرف بلمسة Liquid Glass
    if (isHoliday) {
      final String holidayReason =
          session['note']?.toString().trim().isNotEmpty == true
              ? session['note'].toString().trim()
              : (session['notes']?.toString().trim().isNotEmpty == true
                  ? session['notes'].toString().trim()
                  : (session['title']?.toString().trim().isNotEmpty == true
                      ? session['title'].toString().trim()
                      : 'عطلة رسمية / إجازة معتمدة'));

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          const Color(0xffb45309).withOpacity(0.34),
                          const Color(0xff78350f).withOpacity(0.22),
                        ]
                      : [
                          const Color(0xfffef3c7).withOpacity(0.85),
                          const Color(0xfffde68a).withOpacity(0.72),
                        ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                border: Border.all(
                  color: Colors.amber.shade600.withOpacity(0.65),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.shade900.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade500,
                                Colors.amber.shade700,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.shade800.withOpacity(0.32),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.beach_access_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "عطلة رسمية 🌴",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDarkMode
                                          ? Colors.amber.shade300
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade800
                                          .withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.shade900
                                              .withOpacity(0.25),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      "إجازة",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12.5,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.brown.shade800,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    displayDate,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.brown.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.25)
                            : Colors.white.withOpacity(0.68),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.shade600.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: isDarkMode
                                ? Colors.amber.shade300
                                : Colors.brown.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "السبب: $holidayReason",
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
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
        ),
      );
    }

    final bool isAbsent = session['absent'] ?? false;
    final bool isExam = session['isExam'] ?? false;
    final bool didNotRecite = session['didNotRecite'] ?? false;

    int selectedJuz = 0;
    if (session.containsKey('selectedJuz') && session['selectedJuz'] != null) {
      selectedJuz = int.tryParse(session['selectedJuz'].toString()) ?? 0;
    } else if (session['isJuzAmma'] == true) {
      selectedJuz = 30;
    }

    List<dynamic>? memoSupList = session['newMemoSupervisorNames'];
    List<dynamic>? revSupList = session['reviewSupervisorNames'];
    List<dynamic>? generalSupList = session['supervisorNames'];

    String memoSupName = (memoSupList != null && memoSupList.isNotEmpty)
        ? memoSupList.join(' ، ')
        : '';
    String revSupName = (revSupList != null && revSupList.isNotEmpty)
        ? revSupList.join(' ، ')
        : '';
    String generalSupName =
        (generalSupList != null && generalSupList.isNotEmpty)
            ? generalSupList.join(' ، ')
            : (session['supervisorName'] ?? 'غير محدد');

    String nMemo = session['newMemorization']?.toString().trim() ?? '';
    String nRev = session['nearReview']?.toString().trim() ?? '';
    String fRev = session['farReview']?.toString().trim() ??
        (isCompletedStudent ? (session['review']?.toString().trim() ?? '') : '');
    String sight = session['readingBySight']?.toString().trim() ?? '';
    String ijazahText = session['ijazah']?.toString().trim() ?? '';

    String memRating = session['memorizationRating'] ?? session['rating'] ?? "";
    String newRevRating = session['newReviewRating'] ??
        session['reviewRating'] ??
        session['rating'] ??
        "";
    String oldRevRating = session['oldReviewRating'] ??
        session['reviewRating'] ??
        session['rating'] ??
        "";
    String revRatingLegacy = session['reviewRating'] ?? session['rating'] ?? "";

    String nHw = session['newHomework']?.toString().trim() ?? '';
    String nRevHw = session['newReviewHomework']?.toString().trim() ?? '';
    String oRevHw = session['oldReviewHomework']?.toString().trim() ?? '';
    String oldHw = session['homework']?.toString().trim() ?? '';

    Color statusAccent = isAbsent
        ? Colors.redAccent
        : (isExam
            ? Colors.teal
            : (didNotRecite
                ? Colors.blueGrey
                : (isDarkMode ? accentGold : primaryColor)));

    List<Widget> activeBoxes = [];
    if (!isAbsent && !isExam && !didNotRecite) {
      if (isCompletedStudent && fRev.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(
            Icons.verified_user_rounded,
            "مراجعة الختمة الشاملة",
            fRev,
            isDarkMode ? Colors.tealAccent : Colors.teal));
      } else {
        if (nMemo.isNotEmpty) {
          activeBoxes.add(_buildGridInfoBox(
              Icons.star_rounded, "الحفظ الجديد", nMemo, Colors.amber));
        }
        if (nRev.isNotEmpty) {
          activeBoxes.add(_buildGridInfoBox(
              Icons.menu_book_rounded,
              "مراجعة جديد",
              nRev,
              isDarkMode ? Colors.tealAccent : Colors.teal));
        }
        if (fRev.isNotEmpty) {
          activeBoxes.add(_buildGridInfoBox(Icons.history_toggle_off_rounded,
              "مراجعة قديم", fRev, Colors.lightBlueAccent));
        }
      }
      if (sight.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(Icons.chrome_reader_mode_rounded,
            "قراءة نظراً", sight, Colors.indigoAccent));
      }
      if (ijazahText.isNotEmpty) {
        activeBoxes.add(_buildGridInfoBox(Icons.workspace_premium_rounded,
            "الإجازة القرآنية 📜", ijazahText, Colors.deepOrangeAccent));
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: _buildGlassContainer(
        customBorderColor: statusAccent
            .withOpacity((isAbsent || isExam || didNotRecite) ? 0.45 : 0.25),
        child: Column(
          children: [
            // رأس البطاقة الزجاجي المتدرج
            Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAbsent
                      ? [
                          Colors.redAccent
                              .withOpacity(isDarkMode ? 0.24 : 0.14),
                          Colors.redAccent
                              .withOpacity(isDarkMode ? 0.08 : 0.04),
                        ]
                      : (isExam
                          ? [
                              Colors.teal.withOpacity(isDarkMode ? 0.24 : 0.14),
                              Colors.teal.withOpacity(isDarkMode ? 0.08 : 0.04),
                            ]
                          : (didNotRecite
                              ? [
                                  Colors.blueGrey
                                      .withOpacity(isDarkMode ? 0.24 : 0.14),
                                  Colors.blueGrey
                                      .withOpacity(isDarkMode ? 0.08 : 0.04),
                                ]
                              : [
                                  (isDarkMode ? accentGold : primaryColor)
                                      .withOpacity(isDarkMode ? 0.16 : 0.09),
                                  Colors.transparent,
                                ])),
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.65),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: statusAccent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: statusAccent.withOpacity(0.35),
                          ),
                        ),
                        child: Icon(
                          isAbsent
                              ? Icons.event_busy_rounded
                              : (isExam
                                  ? Icons.workspace_premium_rounded
                                  : (didNotRecite
                                      ? Icons.speaker_notes_off_outlined
                                      : Icons.calendar_today_rounded)),
                          size: 15,
                          color: statusAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "الجلسة #$sessionNumber",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isAbsent
                                    ? (isDarkMode
                                        ? Colors.redAccent.shade100
                                        : Colors.red.shade900)
                                    : (isExam
                                        ? (isDarkMode
                                            ? Colors.tealAccent
                                            : Colors.teal.shade900)
                                        : (isDarkMode
                                            ? Colors.white
                                            : primaryColor)),
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.white60
                                    : Colors.grey.shade700,
                                fontFamily: 'Cairo',
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isAbsent)
                        _buildCustomBadge(
                            "غائب ❌",
                            isDarkMode ? Colors.white : Colors.red.shade800,
                            Colors.redAccent
                                .withOpacity(isDarkMode ? 0.38 : 0.18))
                      else if (isExam)
                        _buildCustomBadge(
                            "جلسة اختبار 📝",
                            isDarkMode ? Colors.white : Colors.teal.shade800,
                            Colors.teal
                                .withOpacity(isDarkMode ? 0.38 : 0.18))
                      else if (didNotRecite)
                        _buildCustomBadge(
                            "حضر ولم يسمّع ℹ️",
                            isDarkMode
                                ? Colors.white
                                : Colors.blueGrey.shade800,
                            Colors.blueGrey
                                .withOpacity(isDarkMode ? 0.38 : 0.18)),
                    ],
                  ),
                  if (!isAbsent &&
                      !isExam &&
                      !didNotRecite &&
                      (selectedJuz > 0 ||
                          ijazahText.isNotEmpty ||
                          (isCompletedStudent && revRatingLegacy.isNotEmpty) ||
                          (!isCompletedStudent &&
                              ((nMemo.isNotEmpty && memRating.isNotEmpty) ||
                                  (nRev.isNotEmpty &&
                                      newRevRating.isNotEmpty) ||
                                  (fRev.isNotEmpty &&
                                      oldRevRating.isNotEmpty))))) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (selectedJuz > 0)
                          _buildCustomBadge(
                            "نظام: جزء ${_getJuzName(selectedJuz)} 📖",
                            isDarkMode
                                ? Colors.amber.shade200
                                : Colors.brown.shade900,
                            accentGold.withOpacity(isDarkMode ? 0.25 : 0.28),
                          ),
                        if (ijazahText.isNotEmpty)
                          _buildCustomBadge(
                            "إجازة 📜",
                            isDarkMode
                                ? Colors.orangeAccent
                                : Colors.deepOrange.shade800,
                            Colors.deepOrange
                                .withOpacity(isDarkMode ? 0.28 : 0.16),
                          ),
                        if (isCompletedStudent && revRatingLegacy.isNotEmpty)
                          _buildCustomBadge(
                              "مراجعة الختمة: $revRatingLegacy",
                              isDarkMode
                                  ? Colors.white
                                  : _getRatingColor(revRatingLegacy),
                              _getRatingColor(revRatingLegacy)
                                  .withOpacity(isDarkMode ? 0.35 : 0.16)),
                        if (!isCompletedStudent) ...[
                          if (nMemo.isNotEmpty && memRating.isNotEmpty)
                            _buildCustomBadge(
                                "حفظ: $memRating",
                                isDarkMode
                                    ? Colors.white
                                    : _getRatingColor(memRating),
                                _getRatingColor(memRating)
                                    .withOpacity(isDarkMode ? 0.35 : 0.16)),
                          if (nRev.isNotEmpty && newRevRating.isNotEmpty)
                            _buildCustomBadge(
                                "م.جديد: $newRevRating",
                                isDarkMode
                                    ? Colors.white
                                    : _getRatingColor(newRevRating),
                                _getRatingColor(newRevRating)
                                    .withOpacity(isDarkMode ? 0.35 : 0.16)),
                          if (fRev.isNotEmpty && oldRevRating.isNotEmpty)
                            _buildCustomBadge(
                                "م.قديم: $oldRevRating",
                                isDarkMode
                                    ? Colors.white
                                    : _getRatingColor(oldRevRating),
                                _getRatingColor(oldRevRating)
                                    .withOpacity(isDarkMode ? 0.35 : 0.16)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (memoSupName.isNotEmpty &&
                      revSupName.isNotEmpty &&
                      memoSupName != revSupName) ...[
                    _buildMinimalistDetailRow(
                        Icons.person_outline_rounded, "مشرف الحفظ", memoSupName,
                        isBold: true),
                    const SizedBox(height: 6),
                    _buildMinimalistDetailRow(Icons.person_outline_rounded,
                        "مشرف المراجعة", revSupName,
                        isBold: true),
                  ] else ...[
                    _buildMinimalistDetailRow(
                        Icons.person_outline_rounded,
                        "المشرف المسجِّل",
                        memoSupName.isNotEmpty
                            ? memoSupName
                            : (revSupName.isNotEmpty
                                ? revSupName
                                : generalSupName),
                        isBold: true),
                  ],

                  if (isAbsent) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent
                            .withOpacity(isDarkMode ? 0.12 : 0.06),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMinimalistDetailRow(
                            Icons.warning_amber_rounded,
                            "نوع الغياب",
                            (session['absenceType'] == null ||
                                    session['absenceType'] == "")
                                ? "بدون عذر"
                                : session['absenceType'].toString(),
                            isBold: true,
                          ),
                          if (session['absenceReason'] != null &&
                              session['absenceReason']
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildMinimalistDetailRow(
                              Icons.info_outline_rounded,
                              "سبب الغياب",
                              session['absenceReason'].toString(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  if (!isAbsent && !isExam && !didNotRecite) ...[
                    _buildGlassDivider(),
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
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),
                      _buildGlassDivider(),
                    ],
                  ],

                  if (!isAbsent && !isExam) ...[
                    if (nHw.isNotEmpty ||
                        nRevHw.isNotEmpty ||
                        oRevHw.isNotEmpty ||
                        oldHw.isNotEmpty) ...[
                      if (didNotRecite) const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentGold.withOpacity(isDarkMode ? 0.12 : 0.08),
                              accentGold.withOpacity(isDarkMode ? 0.04 : 0.02),
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: accentGold.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.assignment_outlined,
                                    size: 16, color: accentGold),
                                const SizedBox(width: 6),
                                Text(
                                    isCompletedStudent
                                        ? "المقدار المطلوب للمرة القادمة:"
                                        : "الواجب القادم:",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDarkMode
                                            ? Colors.white
                                            : primaryColor,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Cairo')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (nHw.isNotEmpty)
                              _buildHomeworkRow("حفظ جديد", nHw),
                            if (nRevHw.isNotEmpty)
                              _buildHomeworkRow("مراجعة جديد", nRevHw),
                            if (oRevHw.isNotEmpty)
                              _buildHomeworkRow(
                                  isCompletedStudent
                                      ? "مراجعة الختمة"
                                      : "مراجعة قديم",
                                  oRevHw),
                            if (oldHw.isNotEmpty &&
                                nHw.isEmpty &&
                                nRevHw.isEmpty &&
                                oRevHw.isEmpty)
                              _buildHomeworkRow("الواجب", oldHw),
                          ],
                        ),
                      ),
                      _buildGlassDivider(),
                    ],
                  ],

                  if (isExam && !isAbsent) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.teal.withOpacity(isDarkMode ? 0.2 : 0.12),
                            Colors.teal.withOpacity(isDarkMode ? 0.06 : 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: Colors.teal.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.workspace_premium_rounded,
                                color: Colors.teal, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("النتيجة الرسمية لاختبار الطالب",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo')),
                              const SizedBox(height: 2),
                              Text("${session['examScore'] ?? '0'} / 100",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: isDarkMode
                                          ? Colors.tealAccent
                                          : Colors.teal.shade800,
                                      fontFamily: 'Cairo')),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (!isAbsent && !isExam) ...[
                    if (didNotRecite) const SizedBox(height: 10),
                    _buildMinimalistDetailRow(
                        Icons.emoji_emotions_outlined,
                        "حالة سلوك الطالب بالحلقة",
                        session['studentStatus'] ?? 'مهذب'),
                    if (session['religiousActivities'] != null &&
                        session['religiousActivities']
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(height: 9),
                      _buildMinimalistDetailRow(Icons.mosque_outlined,
                          "الأنشطة الدينية", session['religiousActivities']),
                    ],
                    if (!didNotRecite && selectedJuz == 0) ...[
                      const SizedBox(height: 9),
                      _buildMinimalistDetailRow(
                        Icons.analytics_outlined,
                        "إجمالي الحفظ للختمة",
                        isCompletedStudent
                            ? "604 صفحة (مكتملة ✨)"
                            : (session['total_memorized_pages'] != null
                                ? "${session['total_memorized_pages']} صفحة"
                                : "---"),
                      ),
                    ]
                  ],

                  if (session['notes'] != null &&
                      session['notes'].toString().trim().isNotEmpty) ...[
                    _buildGlassDivider(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent
                            .withOpacity(isDarkMode ? 0.12 : 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.orangeAccent
                              .withOpacity(isDarkMode ? 0.35 : 0.22),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                            color: isDarkMode
                                ? Colors.orangeAccent
                                : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "ملاحظة المشرف للأهل: ${session['notes']}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.orange.shade200
                                    : Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Divider(
        height: 1,
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : primaryColor.withOpacity(0.08),
      ),
    );
  }

  String _getJuzName(int juz) {
    switch (juz) {
      case 30:
        return "عمَّ (30)";
      case 29:
        return "تبارك (29)";
      case 28:
        return "قد سمع (28)";
      case 27:
        return "الذاريات (27)";
      case 26:
        return "الأحقاف (26)";
      default:
        return "$juz";
    }
  }

  Widget _buildHomeworkRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• $label: ",
              style: TextStyle(
                  fontSize: 11.5,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildGridInfoBox(
      IconData icon, String title, String val, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  Colors.white.withOpacity(0.06),
                  Colors.black.withOpacity(0.18),
                ]
              : [
                  Colors.white.withOpacity(0.72),
                  Colors.white.withOpacity(0.42),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.85),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13.5, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo'),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            val.trim().isEmpty ? '---' : val,
            style: TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : primaryColor,
                fontFamily: 'Cairo',
                height: 1.45),
          )
        ],
      ),
    );
  }

  Widget _buildMinimalistDetailRow(IconData icon, String label, String value,
      {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon,
              size: 17,
              color: isDarkMode ? accentGold : primaryColor.withOpacity(0.7)),
        ),
        const SizedBox(width: 8),
        Text("$label: ",
            style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white60 : Colors.grey.shade700,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '---' : value,
            style: TextStyle(
              fontSize: 12.5,
              color: isBold
                  ? (isDarkMode ? Colors.white : primaryColor)
                  : (isDarkMode ? Colors.white70 : Colors.black87),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withOpacity(0.25),
          width: 0.8,
        ),
      ),
      child: Text(text,
          style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
              fontFamily: 'Cairo')),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child,
      EdgeInsetsGeometry padding = EdgeInsets.zero,
      Color? customColor,
      Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: customColor == null
                ? LinearGradient(
                    colors: isDarkMode
                        ? [
                            Colors.white.withOpacity(0.09),
                            Colors.white.withOpacity(0.03),
                          ]
                        : [
                            Colors.white.withOpacity(0.58),
                            Colors.white.withOpacity(0.34),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: customColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: customBorderColor ??
                  (isDarkMode
                      ? Colors.white.withOpacity(0.14)
                      : Colors.white.withOpacity(0.72)),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.22 : 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case "ممتاز":
        return Colors.green;
      case "جيد جداً":
        return Colors.teal;
      case "جيد":
        return Colors.orange;
      case "مقبول":
        return Colors.blueGrey;
      case "ضعيف":
        return Colors.red;
      default:
        return primaryColor;
    }
  }
}