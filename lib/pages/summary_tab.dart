import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'student_rewards_page.dart';

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

  static const List<String> _weekOrder = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

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

  Future<Map<String, dynamic>?> _fetchActiveCycleInfo() async {
    try {
      var activeSnap =
          await FirebaseFirestore.instance.collection('cycles').get();

      if (activeSnap.docs.isNotEmpty) {
        for (var doc in activeSnap.docs) {
          var data = doc.data();
          if (data['active'] == true ||
              data['isActive'] == true ||
              data['isClosed'] == false) {
            return {
              'id': doc.id,
              'data': data,
            };
          }
        }
      }
    } catch (e) {
      debugPrint("خطأ في جلب الدورة الفعالة للملخص: $e");
    }
    return null;
  }

  String? _normalizeDayName(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    if (clean.contains('سبت')) return 'السبت';
    if (clean.contains('أحد') || clean.contains('احد')) return 'الأحد';
    if (clean.contains('اثنين') || clean.contains('إثنين')) return 'الإثنين';
    if (clean.contains('ثلاثاء')) return 'الثلاثاء';
    if (clean.contains('أربعاء') || clean.contains('اربعاء')) return 'الأربعاء';
    if (clean.contains('خميس')) return 'الخميس';
    if (clean.contains('جمعة') || clean.contains('جمعه')) return 'الجمعة';
    return null;
  }

  /// استخراج خريطة {اليوم: الفترة} من scheduleByDay أو الحقول البديلة
  Map<String, String> _resolveDayPeriodMap(Map<String, dynamic>? cycleData) {
    final Map<String, String> result = {};

    final dynamic rawScheduleMap = studentData['scheduleByDay'] ??
        studentData['daySchedules'] ??
        studentData['scheduleDetails'] ??
        cycleData?['scheduleByDay'];

    if (rawScheduleMap is Map) {
      rawScheduleMap.forEach((key, val) {
        final day = _normalizeDayName(key.toString());
        if (day != null && val != null && val != false) {
          final periodText =
              (val == true ? 'عصراً' : val.toString()).trim();
          if (periodText.isNotEmpty) {
            result[day] = periodText;
          }
        }
      });
    }

    if (result.isEmpty) {
      final dynamic rawDays = studentData['attendanceDays'] ??
          studentData['studyDays'] ??
          studentData['days'] ??
          cycleData?['attendanceDays'];

      final fallbackPeriod = (studentData['period'] ??
              studentData['shift'] ??
              cycleData?['period'] ??
              'عصراً')
          .toString()
          .trim();

      if (rawDays is List) {
        for (var item in rawDays) {
          final day = _normalizeDayName(item.toString());
          if (day != null) {
            result[day] = fallbackPeriod.isEmpty ? 'عصراً' : fallbackPeriod;
          }
        }
      } else if (rawDays is String && rawDays.isNotEmpty) {
        for (var part in rawDays.split(RegExp(r'[,،/]+'))) {
          final day = _normalizeDayName(part);
          if (day != null) {
            result[day] = fallbackPeriod.isEmpty ? 'عصراً' : fallbackPeriod;
          }
        }
      }
    }

    // ترتيب النتائج حسب ترتيب أيام الأسبوع
    final Map<String, String> ordered = {};
    for (final day in _weekOrder) {
      if (result.containsKey(day)) {
        ordered[day] = result[day]!;
      }
    }
    return ordered;
  }

  /// تجميع الأيام التي لها نفس الفترة معاً، وفصل الأيام ذات الفترة المختلفة
  List<Map<String, dynamic>> _groupDaysByPeriod(
      Map<String, String> dayMap) {
    final Map<String, List<String>> grouped = {};

    for (final day in _weekOrder) {
      final period = dayMap[day];
      if (period == null || period.isEmpty) continue;
      grouped.putIfAbsent(period, () => []).add(day);
    }

    return grouped.entries
        .map((e) => {
              'period': e.key,
              'days': e.value,
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchActiveCycleInfo(),
      builder: (context, cycleSnap) {
        String? activeCycleId = cycleSnap.data?['id']?.toString();
        Map<String, dynamic>? activeCycleData =
            cycleSnap.data?['data'] as Map<String, dynamic>?;

        final Map<String, String> dayPeriodMap =
            _resolveDayPeriodMap(activeCycleData);
        final List<Map<String, dynamic>> groupedPeriods =
            _groupDaysByPeriod(dayPeriodMap);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 120, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDailyInspiration(),
              _buildDigitalGlassID(studentData, activeCycleId),
              _buildScheduleAndPeriodShowcase(dayPeriodMap, groupedPeriods),
              _buildStudentPointsWallet(context, activeCycleId),
              _buildQuranProgressSection(activeCycleId),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [goldColor, primaryColor],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "لوحة الأداء والإحصائيات الحية",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        fontFamily: 'Cairo',
                        color: isDarkMode ? Colors.white : primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              _buildParentStatsDashboard(),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  /// بطاقة أيام الدوام: الأيام المتشابهة بالفترة معاً، والمختلفة لوحدها
  Widget _buildScheduleAndPeriodShowcase(
    Map<String, String> dayPeriodMap,
    List<Map<String, dynamic>> groupedPeriods,
  ) {
    final Set<String> activeDays = dayPeriodMap.keys.toSet();
    final int totalDaysCount = activeDays.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _buildGlassContainer(
        padding: const EdgeInsets.all(18),
        customColor: isDarkMode
            ? const Color(0xff182234).withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.85),
        customBorderColor:
            goldColor.withValues(alpha: isDarkMode ? 0.38 : 0.48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: goldColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: isDarkMode ? goldColor : primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "أيام ومواعيد الدوام",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            fontFamily: 'Cairo',
                            color: isDarkMode ? Colors.white : primaryColor,
                          ),
                        ),
                        Text(
                          "توزيع الفترات للأهل حسب الأيام",
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Cairo',
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: goldColor.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    "$totalDaysCount أيام / أسبوع",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                      color: isDarkMode ? Colors.white : primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _weekOrder.map((day) {
                final bool active = activeDays.contains(day);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: active
                        ? LinearGradient(
                            colors: isDarkMode
                                ? [
                                    goldColor.withValues(alpha: 0.3),
                                    primaryColor.withValues(alpha: 0.55),
                                  ]
                                : [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.88),
                                  ],
                          )
                        : null,
                    color: active
                        ? null
                        : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? goldColor.withValues(alpha: 0.75)
                          : (isDarkMode
                              ? Colors.white10
                              : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (active) ...[
                        Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: isDarkMode ? goldColor : Colors.amber.shade200,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                          fontFamily: 'Cairo',
                          color: active
                              ? Colors.white
                              : (isDarkMode
                                  ? Colors.white38
                                  : Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            if (groupedPeriods.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.24)
                      : primaryColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  "لم يتم تحديد أيام دوام بعد",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.24)
                      : primaryColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        goldColor.withValues(alpha: isDarkMode ? 0.2 : 0.25),
                  ),
                ),
                child: Column(
                  children: groupedPeriods.asMap().entries.map((entry) {
                    final int idx = entry.key;
                    final String period = entry.value['period'] as String;
                    final List<String> daysInGroup =
                        entry.value['days'] as List<String>;
                    final bool isLast = idx == groupedPeriods.length - 1;

                    IconData periodIcon = Icons.wb_twilight_rounded;
                    Color periodColor = const Color(0xfff59e0b);
                    if (period.contains('عصراً وعالمغرب')) {
                      periodIcon = Icons.timelapse_rounded;
                      periodColor = const Color(0xff8b5cf6);
                    } else if (period.contains('مغرب')) {
                      periodIcon = Icons.nights_stay_outlined;
                      periodColor = const Color(0xfff97316);
                    } else if (period.contains('عصر')) {
                      periodIcon = Icons.wb_twilight_rounded;
                      periodColor = const Color(0xfff59e0b);
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: periodColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: periodColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(periodIcon,
                                        size: 14, color: periodColor),
                                    const SizedBox(width: 5),
                                    Text(
                                      period,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Cairo',
                                        color: isDarkMode
                                            ? Colors.white
                                            : primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  daysInGroup.join('، '),
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Cairo',
                                    color: isDarkMode
                                        ? Colors.white
                                        : primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            color: isDarkMode
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyInspiration() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('settings')
          .doc('general')
          .get(),
      builder: (context, settingsSnapshot) {
        bool isActive = true;
        if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
          isActive = (settingsSnapshot.data!.data()
                  as Map<String, dynamic>)['is_inspiration_active'] ??
              true;
        }

        if (!isActive) return const SizedBox.shrink();

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('inspirations')
              .orderBy('createdAt')
              .get(),
          builder: (context, inspirationSnapshot) {
            if (!inspirationSnapshot.hasData ||
                inspirationSnapshot.data!.docs.isEmpty) {
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
                customColor: isDarkMode
                    ? goldColor.withValues(alpha: 0.1)
                    : goldColor.withValues(alpha: 0.14),
                customBorderColor: goldColor.withValues(alpha: 0.45),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: goldColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wb_sunny_rounded,
                          color:
                              isDarkMode ? goldColor : Colors.orange.shade700,
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("إشراقة اليوم ✨",
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color:
                                      isDarkMode ? Colors.white : primaryColor,
                                  fontFamily: 'Cairo')),
                          const SizedBox(height: 5),
                          Text(
                            text,
                            style: TextStyle(
                                fontSize: 12.5,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey.shade800,
                                height: 1.5,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w600),
                          ),
                          if (source.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                  color: goldColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(source,
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      color:
                                          isDarkMode ? goldColor : primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo')),
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

  Widget _buildDigitalGlassID(
      Map<String, dynamic> data, String? activeCycleId) {
    String studentName = data['name'] ?? 'اسم الطالب';
    var exactSerial = data['serial'];
    String serialNumStr = exactSerial?.toString() ?? '---';
    String grade = data['schoolGrade'] ?? 'غير محدد';
    String supervisor = data['supervisorName'] ?? 'غير محدد';
    String phone = data['phone'] ?? '---';
    String pulse = data['livePulse'] ?? 'none';

    Color dotColor = Colors.transparent;
    String pulseLabel = "";
    if (pulse == 'green') {
      dotColor = Colors.greenAccent.shade400;
      pulseLabel = "يُسمِّع";
    } else if (pulse == 'yellow') {
      dotColor = Colors.amber;
      pulseLabel = "يراجع";
    } else if (pulse == 'blue') {
      dotColor = Colors.lightBlueAccent;
      pulseLabel = "أتم التسميع";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [
                          goldColor.withValues(alpha: 0.16),
                          primaryColor.withValues(alpha: 0.36)
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.88),
                          const Color(0xfff4f7fa).withValues(alpha: 0.75)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: isDarkMode
                        ? goldColor.withValues(alpha: 0.38)
                        : goldColor.withValues(alpha: 0.42),
                    width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDarkMode ? 0.28 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded,
                            color: isDarkMode ? goldColor : primaryColor,
                            size: 19),
                        const SizedBox(width: 8),
                        Text("معهد الشيخ سعيد العبدالله",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey.shade700)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: (isDarkMode ? goldColor : primaryColor)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(9)),
                      child: Text("هوية رقمية",
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? goldColor : primaryColor,
                              fontFamily: 'Cairo')),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Divider(
                      height: 1,
                      color: isDarkMode
                          ? Colors.white12
                          : Colors.black.withValues(alpha: 0.06)),
                ),
                Row(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isDarkMode
                                  ? goldColor
                                  : primaryColor.withValues(alpha: 0.55),
                              width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: (isDarkMode ? goldColor : primaryColor)
                                    .withValues(alpha: 0.22),
                                blurRadius: 14)
                          ]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: data['imageUrl'] != null &&
                                data['imageUrl'].toString().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: data['imageUrl'],
                                fit: BoxFit.cover,
                                placeholder: (c, u) => const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                errorWidget: (c, u, e) =>
                                    _buildAvatarPlaceholder(studentName))
                            : _buildAvatarPlaceholder(studentName),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  studentName,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isDarkMode
                                          ? Colors.white
                                          : primaryColor,
                                      fontFamily: 'Cairo',
                                      height: 1.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (pulse != 'none') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: dotColor.withValues(
                                        alpha: isDarkMode ? 0.15 : 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: dotColor.withValues(alpha: 0.4)),
                                  ),
                                  child: LivePulseDot(
                                      color: dotColor, label: pulseLabel),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.black26
                                    : Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white12
                                        : Colors.black12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pin_rounded,
                                    size: 14,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text("الرقم التسلسلي: $serialNumStr",
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo',
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.grey.shade800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                        child: _buildInfoChip(
                            Icons.school_rounded, "المرحلة", grade)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildInfoChip(
                            Icons.person_pin_rounded, "المشرف", supervisor)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildInfoChip(
                            Icons.phone_android_rounded, "الهاتف", phone)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentPointsWallet(
      BuildContext context, String? activeCycleId) {
    int currentPoints = studentData['points'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () async {
            var exactSerial = studentData['serial'];
            var snap = await FirebaseFirestore.instance
                .collection('students')
                .where('serial', isEqualTo: exactSerial)
                .get();
            if (snap.docs.isNotEmpty && context.mounted) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          StudentRewardsPage(studentDoc: snap.docs.first)));
            }
          },
          child: _buildGlassContainer(
            padding: const EdgeInsets.all(16),
            customColor: isDarkMode
                ? goldColor.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.78),
            customBorderColor: goldColor.withValues(alpha: 0.42),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            goldColor,
                            goldColor.withValues(alpha: 0.65)
                          ]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: goldColor.withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1)
                          ]),
                      child: const Icon(Icons.stars_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("رصيدك الحالي من النقاط",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.grey.shade700)),
                        const SizedBox(height: 2),
                        Text(
                            "اضغط هنا لاستبدال جوائزك وتصفح السجل 🎁",
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                color: isDarkMode
                                    ? goldColor
                                    : primaryColor.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: currentPoints.toDouble()),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                          color: isDarkMode ? goldColor : primaryColor),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: isDarkMode
          ? primaryColor
          : primaryColor.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1) : '?',
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : primaryColor,
              fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: isDarkMode
                ? Colors.white12
                : goldColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 14,
              color:
                  isDarkMode ? goldColor : primaryColor.withValues(alpha: 0.85)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                  fontFamily: 'Cairo')),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : primaryColor,
                  fontFamily: 'Cairo')),
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
                            width: 55,
                            height: 55,
                            child: CircularProgressIndicator(
                                value: attendanceRate,
                                strokeWidth: 5,
                                backgroundColor: isDarkMode
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.green.shade50,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Colors.green)),
                          ),
                          Text("${(attendanceRate * 100).toStringAsFixed(0)}%",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Cairo',
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("نسبة الالتزام",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87)),
                            Text("$present من أصل $total جلسة",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey.shade600,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600)),
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
                            width: 55,
                            height: 55,
                            child: CircularProgressIndicator(
                                value: excellentRate,
                                strokeWidth: 5,
                                backgroundColor: isDarkMode
                                    ? goldColor.withValues(alpha: 0.12)
                                    : const Color(0xfffef9e7),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(goldColor)),
                          ),
                          Icon(Icons.workspace_premium_rounded,
                              size: 20, color: goldColor),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("التميز والاتقان",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87)),
                            Text("$excellent مرات متميزة",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey.shade600,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600)),
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
                      baseColor: goldColor)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildModernStatMiniCard(
                      title: "المستوى المستقر",
                      value: "$good",
                      icon: Icons.thumb_up_alt_rounded,
                      baseColor: Colors.blue.shade500)),
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
                      baseColor: Colors.redAccent.shade400)),
              const SizedBox(width: 10),
              Expanded(
                  child: _buildModernStatMiniCard(
                      title: "جلسات الغياب",
                      value: "$absent",
                      icon: Icons.cancel_presentation_rounded,
                      baseColor: absent >= 3
                          ? Colors.redAccent
                          : Colors.grey.shade500,
                      badgeText: absent >= 3 ? "تنبيه غياب! ⚠️" : null)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatMiniCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color baseColor,
      String? badgeText}) {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(15),
      customColor: baseColor.withValues(alpha: isDarkMode ? 0.11 : 0.06),
      customBorderColor: baseColor.withValues(alpha: 0.32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: baseColor, size: 18)),
              if (badgeText != null)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(badgeText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDarkMode ? Colors.white : primaryColor,
                  fontFamily: 'Cairo',
                  height: 1)),
          const SizedBox(height: 3),
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildQuranProgressSection(String? activeCycleId) {
    bool isCompleted = studentData['studentType'] == 'completed';
    double savedPages = 0.0;

    if (studentData.containsKey('customLastPage') &&
        studentData['customLastPage'] != null) {
      double customVal =
          double.tryParse(studentData['customLastPage'].toString()) ?? 0.0;
      if (customVal > 0) {
        savedPages = customVal;
      }
    }

    if (savedPages == 0 &&
        sessionSnapshot.hasData &&
        sessionSnapshot.data!.docs.isNotEmpty) {
      var sessionDocs = sessionSnapshot.data!.docs;

      List<QueryDocumentSnapshot> sortedSessions = List.from(sessionDocs)
        ..retainWhere((doc) {
          var data = doc.data() as Map;
          bool activeOk = (activeCycleId == null ||
              data['cycleId']?.toString().trim() == activeCycleId);
          return activeOk &&
              data['absent'] == false &&
              data['isExam'] == false &&
              data['didNotRecite'] != true;
        });

      sortedSessions.sort((a, b) {
        var dataA = a.data() as Map<String, dynamic>;
        var dataB = b.data() as Map<String, dynamic>;

        DateTime dateAObj = _parseDate(dataA['date'] ?? '');
        DateTime dateBObj = _parseDate(dataB['date'] ?? '');

        int dateComparison = dateBObj.compareTo(dateAObj);

        if (dateComparison == 0) {
          Timestamp? tA = dataA['timestamp'] as Timestamp?;
          Timestamp? tB = dataB['timestamp'] as Timestamp?;
          if (tA != null && tB != null) return tB.compareTo(tA);
          if (tA == null && tB != null) return -1;
          if (tB == null && tA != null) return 1;
        }
        return dateComparison;
      });

      for (var doc in sortedSessions) {
        var data = doc.data() as Map;

        double? extractedVal =
            double.tryParse(data['memorizedPages']?.toString() ?? '') ??
                double.tryParse(
                    data['totalMemorizedPages']?.toString() ?? '') ??
                double.tryParse(
                    data['total_memorized_pages']?.toString() ?? '') ??
                double.tryParse(data['totalMemorized']?.toString() ?? '') ??
                double.tryParse(
                    data['totalMemorizationPages']?.toString() ?? '') ??
                double.tryParse(data['totalPages']?.toString() ?? '') ??
                double.tryParse(data['end_page']?.toString() ?? '');

        if (extractedVal != null && extractedVal > 0) {
          savedPages = extractedVal;
          break;
        }

        if (isCompleted) {
          String fRev = data['farReview']?.toString() ??
              data['review']?.toString() ??
              '';
          if (fRev.isNotEmpty) {
            RegExp exp = RegExp(r'\d+');
            Iterable<Match> matches = exp.allMatches(fRev);
            int currentMax = 0;
            for (var m in matches) {
              int? val = int.tryParse(m.group(0)!);
              if (val != null && val > currentMax && val <= 604) {
                currentMax = val;
              }
            }
            if (currentMax > 0) {
              savedPages = currentMax.toDouble();
              break;
            }
          }
        }
      }
    }

    if (savedPages == 0) {
      savedPages =
          double.tryParse(studentData['memorizedPages']?.toString() ?? '') ??
              double.tryParse(studentData['end_page']?.toString() ?? '') ??
              double.tryParse(studentData['lastPage']?.toString() ?? '') ??
              double.tryParse(studentData['pagesCount']?.toString() ?? '') ??
              0.0;
    }

    double totalQuranPages = 604.0;
    double remainingPages =
        (totalQuranPages - savedPages).clamp(0.0, totalQuranPages);
    double progressPercentage = (savedPages / totalQuranPages).clamp(0.0, 1.0);

    String title = isCompleted
        ? "مستوى تقدم الختمة الحالية 🔄"
        : "مستوى تقدم الطالب في الختمة 👑";
    String subtitle = isCompleted
        ? "وصل الطالب إلى الصفحة ${savedPages.toInt()} من أصل 604"
        : "تم تمكين ${savedPages.toInt()} من أصل 604 صفحة";
    String footerText = remainingPages == 0
        ? (isCompleted
            ? "مبارك! أتم الطالب مراجعة الختمة بنجاح 🎉👑"
            : "مبارك! للطالب ختم كتاب الله كاملاً، هنيئاً لك 🎉👑")
        : (isCompleted
            ? "متبقي للطالب [ ${remainingPages.toInt()} صفحة ] لإنهاء دورة المراجعة الحالية ✨"
            : "متبقي للطالب [ ${remainingPages.toInt()} صفحة ] ويختم كتاب الله كاملاً ✨");

    Color progressColor = isCompleted ? Colors.deepPurpleAccent : Colors.teal;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _buildGlassContainer(
        padding: const EdgeInsets.all(18),
        customBorderColor: progressColor.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                    isCompleted
                        ? Icons.autorenew_rounded
                        : Icons.auto_stories_rounded,
                    color: progressColor,
                    size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDarkMode ? Colors.white : primaryColor,
                        fontFamily: 'Cairo')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo')),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        "${(progressPercentage * 100).toStringAsFixed(1)}%",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: progressColor,
                            fontFamily: 'Cairo'))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                    value: progressPercentage,
                    minHeight: 8,
                    backgroundColor:
                        isDarkMode ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor))),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: progressColor
                      .withValues(alpha: isDarkMode ? 0.09 : 0.05),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: progressColor.withValues(
                          alpha: isDarkMode ? 0.24 : 0.14))),
              child: Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      color: Colors.red.shade400, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(footerText,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : primaryColor,
                              height: 1.4,
                              fontFamily: 'Cairo'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child,
      EdgeInsetsGeometry padding = EdgeInsets.zero,
      Color? customColor,
      Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ??
                (isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.72)),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
                color: customBorderColor ??
                    (isDarkMode
                        ? Colors.white.withValues(alpha: 0.12)
                        : goldColor.withValues(alpha: 0.25)),
                width: 1.4),
            boxShadow: [
              BoxShadow(
                  color: Colors.black
                      .withValues(alpha: isDarkMode ? 0.22 : 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8))
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class LivePulseDot extends StatefulWidget {
  final Color color;
  final String label;

  const LivePulseDot({super.key, required this.color, required this.label});

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
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
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color
                            .withValues(alpha: 0.4 + (_controller.value * 0.4)),
                        blurRadius: 4 + (_controller.value * 6),
                        spreadRadius: 1 + (_controller.value * 2),
                      )
                    ]),
              );
            }),
        const SizedBox(width: 8),
        Text(widget.label,
            style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'Cairo')),
      ],
    );
  }
}