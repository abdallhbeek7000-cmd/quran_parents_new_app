import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import 'parent_home_page.dart';

class OnboardingPage extends StatefulWidget {
  final DocumentSnapshot student;

  const OnboardingPage({super.key, required this.student});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'icon': Icons.admin_panel_settings_rounded,
      'title': "هويتك الرقمية الفخمة",
      'desc': "تابع بيانات ابنك ومستوى تقدمه في الختمة بلمحة سريعة من خلال بطاقة الطالب الزجاجية.",
    },
    {
      'icon': Icons.swipe_rounded,
      'title': "تنقل سائل وذكي",
      'desc': "اسحب الشريط السفلي العائم يميناً ويساراً للتنقل بين الخلاصة، السجل اليومي، ولوحة التميز بكل نعومة.",
    },
    {
      'icon': Icons.notifications_active_rounded,
      'title': "تنبيهات لحظية",
      'desc': "كن على اطلاع دائم بكل ما يخص ابنك (غياب، اختبارات، أو تميز) عبر مركز الإشعارات الفوري.",
    },
  ];

  void _completeOnboarding() async {
    // 🎯 حفظ أن المستخدم أكمل الجولة ليتم تخطيها مستقبلاً
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ParentHomePage(student: widget.student)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9),
      body: Stack(
        children: [
          // 🎨 الخلفية الانسيابية
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode 
                    ? [const Color(0xff0f172a), const Color(0xff1e293b), const Color(0xff0f172a)] 
                    : [const Color(0xffe2e8f0), const Color(0xffcfdef3), const Color(0xffe0eafc)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -50, left: -50,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? goldColor.withOpacity(0.1) : goldColor.withOpacity(0.15))),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.25))),
          ),

          // 📱 محتوى الشاشات
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 🧊 الأيقونة الزجاجية
                            ClipRRect(
                              borderRadius: BorderRadius.circular(40),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  padding: const EdgeInsets.all(30),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(40),
                                    border: Border.all(color: isDarkMode ? Colors.white12 : Colors.white.withOpacity(0.6), width: 1.5),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                                  ),
                                  child: Icon(
                                    _onboardingData[index]['icon'],
                                    size: 80,
                                    color: isDarkMode ? goldColor : primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            Text(
                              _onboardingData[index]['title'],
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : primaryColor, fontFamily: 'Cairo'),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _onboardingData[index]['desc'],
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, height: 1.6, color: isDarkMode ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 🚦 نقاط التمرير وزر المتابعة
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // النقاط
                      Row(
                        children: List.generate(_onboardingData.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(left: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index 
                                  ? (isDarkMode ? goldColor : primaryColor) 
                                  : (isDarkMode ? Colors.white24 : Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      
                      // زر المتابعة / البدء
                      GestureDetector(
                        onTap: () {
                          if (_currentPage == _onboardingData.length - 1) {
                            _completeOnboarding();
                          } else {
                            _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          decoration: BoxDecoration(
                            color: isDarkMode ? goldColor : primaryColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [BoxShadow(color: (isDarkMode ? goldColor : primaryColor).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                          ),
                          child: Text(
                            _currentPage == _onboardingData.length - 1 ? "ابدأ التجربة 🚀" : "التالي",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}