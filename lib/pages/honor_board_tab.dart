import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HonorBoardTab extends StatelessWidget {
  final List<Map<String, dynamic>> allWinners;
  final Map<String, String> studentImagesCache;
  final bool isHonorLoading;
  final String currentStudentSerial;
  final bool isDarkMode;

  const HonorBoardTab({
    super.key,
    required this.allWinners,
    required this.studentImagesCache,
    required this.isHonorLoading,
    required this.currentStudentSerial,
    required this.isDarkMode,
  });

  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120, top: 15), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🚀 1. ترويسة الصفحة (تم رفعها للأعلى لتملأ الفراغ)
          Icon(Icons.workspace_premium_rounded, size: 70, color: goldColor.withOpacity(isDarkMode ? 0.8 : 0.6)),
          const SizedBox(height: 10),
          Text(
            "منظومة تحفيز الطلاب الذكية",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : primaryColor),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
            child: Text(
              "يتم تحديث قائمة النجوم بشكل دوري من قبل إدارة المعهد لتكريم الطلاب الأكثر انضباطاً وتميزاً في الحفظ والمراجعة.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isDarkMode ? Colors.white60 : Colors.grey.shade600, height: 1.5, fontWeight: FontWeight.w600),
            ),
          ),
          
          const SizedBox(height: 15),
          Divider(color: isDarkMode ? Colors.white12 : Colors.black12, indent: 40, endIndent: 40),
          const SizedBox(height: 15),

          // 🚀 2. شبكة النجوم التفاعلية (The Adaptive Grid)
          _buildHonorBoardGrid(),
        ],
      ),
    );
  }

  Widget _buildHonorBoardGrid() {
    if (isHonorLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 50),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (allWinners.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            Icon(Icons.hourglass_empty_rounded, size: 50, color: isDarkMode ? Colors.white24 : Colors.black12),
            const SizedBox(height: 10),
            Text("سيتم إعلان نجوم الأسبوع قريباً...", style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: GridView.builder(
        shrinkWrap: true, // مهم جداً عشان ياخد مساحته جوا الـ SingleChildScrollView
        physics: const NeverScrollableScrollPhysics(),
        // 🚀 توزيع ذكي: يعرض 3 طلاب بالصف على الشاشات العادية، و2 لو الشاشة صغيرة جداً
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140, 
          childAspectRatio: 0.78, // نسبة الطول للعرض للكارت
          crossAxisSpacing: 12,
          mainAxisSpacing: 15,
        ),
        itemCount: allWinners.length,
        itemBuilder: (context, index) {
          var winner = allWinners[index];
          String winnerSerialStr = winner['serial']?.toString() ?? '';
          String winnerName = winner['name'] ?? '';
          
          // 🎯 التحقق إذا كان هذا الطالب هو ابن ولي الأمر الحالي
          bool isCurrent = (winnerSerialStr == currentStudentSerial && currentStudentSerial.isNotEmpty);
          String finalImageUrl = studentImagesCache[winnerSerialStr] ?? '';

          return _buildGlassContainer(
            padding: const EdgeInsets.all(8),
            // إشعاع ذهبي خاص لكارت ابن ولي الأمر
            customColor: isCurrent ? goldColor.withOpacity(0.15) : (isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.5)),
            customBorderColor: isCurrent ? goldColor.withOpacity(0.8) : (isDarkMode ? Colors.white12 : Colors.white),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isCurrent ? goldColor : (isDarkMode ? Colors.white24 : primaryColor.withOpacity(0.3)), width: 2),
                        boxShadow: isCurrent ? [BoxShadow(color: goldColor.withOpacity(0.4), blurRadius: 10)] : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: finalImageUrl.isNotEmpty && finalImageUrl.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: finalImageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))),
                                errorWidget: (context, url, error) => _buildFallbackAvatar(winnerName),
                              )
                            : _buildFallbackAvatar(winnerName),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: goldColor, width: 1.5)),
                        child: Icon(Icons.star_rounded, size: 12, color: goldColor),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  winnerName, 
                  textAlign: TextAlign.center, 
                  maxLines: 2, 
                  overflow: TextOverflow.ellipsis, 
                  style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white : primaryColor, fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold, fontFamily: 'Cairo', height: 1.2),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCurrent ? goldColor.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isCurrent ? "👑 بطلنا" : "🏆 متميز", 
                    style: TextStyle(fontSize: 10, color: isCurrent ? goldColor : (isDarkMode ? Colors.orangeAccent : Colors.orange.shade700), fontWeight: FontWeight.bold, fontFamily: 'Cairo')
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return Container(
      color: primaryColor.withOpacity(0.1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1) : '?', 
          style: TextStyle(fontSize: 22, color: isDarkMode ? goldColor : primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo')
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry padding = EdgeInsets.zero, Color? customColor, Color? customBorderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: customColor ?? (isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: customBorderColor ?? (isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6)), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: child,
        ),
      ),
    );
  }
}