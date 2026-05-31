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
      padding: const EdgeInsets.only(bottom: 120), // مساحة للشريط العائم
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text("🏆 لوحة أوسمة الشرف للمعهد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isDarkMode ? Colors.white : primaryColor)),
          ),
          _buildHonorBoardSection(),
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
  }

  Widget _buildHonorBoardSection() {
    if (isHonorLoading) {
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