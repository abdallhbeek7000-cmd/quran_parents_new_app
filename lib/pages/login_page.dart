import 'dart:io';
import 'dart:math' as math; // 🎯 ضروري لحسابات رسم الزخارف الهندسية بالخلفية
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'parent_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  // الألوان الرسمية الفخمة والمعتمدة بهويتك البصرية
  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  @override
  void initState() {
    super.initState();
    _checkSavedLogin(); 
  }

  void _checkSavedLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedSerial = prefs.getString('saved_student_serial');

    if (savedSerial != null && savedSerial.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        final int? serialNum = int.tryParse(savedSerial);
        List<DocumentSnapshot> matchingStudents = [];

        if (serialNum != null) {
          final intQuery = await FirebaseFirestore.instance
              .collection('students')
              .where('serial', isEqualTo: serialNum)
              .limit(1)
              .get();
          if (intQuery.docs.isNotEmpty) matchingStudents = intQuery.docs;
        }

        if (matchingStudents.isEmpty) {
          final stringQuery = await FirebaseFirestore.instance
              .collection('students')
              .where('serial', isEqualTo: savedSerial)
              .limit(1)
              .get();
          if (stringQuery.docs.isNotEmpty) matchingStudents = stringQuery.docs;
        }

        if (matchingStudents.isNotEmpty && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ParentHomePage(student: matchingStudents.first),
            ),
          );
          return;
        }
      } catch (e) {
        print("Error during auto login sync: $e");
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _login() async {
    final String serialInput = _serialController.text.trim();
    final String phoneInput = _phoneController.text.trim().replaceAll(' ', '');

    if (serialInput.isEmpty || phoneInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('الرجاء إدخال الرقم التسلسلي ورقم الهاتف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final int? serialNum = int.tryParse(serialInput);
      List<DocumentSnapshot> matchingStudents = [];

      if (serialNum != null) {
        final intQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('serial', isEqualTo: serialNum)
            .limit(1)
            .get();
        if (intQuery.docs.isNotEmpty) {
          matchingStudents = intQuery.docs;
        }
      }

      if (matchingStudents.isEmpty) {
        final stringQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('serial', isEqualTo: serialInput)
            .limit(1)
            .get();
        if (stringQuery.docs.isNotEmpty) {
          matchingStudents = stringQuery.docs;
        }
      }

      if (matchingStudents.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('الرقم التسلسلي غير صحيح أو الطالب غير مسجل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final DocumentSnapshot studentDoc = matchingStudents.first;
      final Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
      final String dbPhone = (studentData['phone'] ?? '').toString().trim().replaceAll(' ', '');

      bool isPhoneValid = false;
      if (phoneInput.isNotEmpty && dbPhone.isNotEmpty) {
        if (phoneInput == dbPhone || dbPhone.endsWith(phoneInput) || phoneInput.endsWith(dbPhone)) {
          isPhoneValid = true;
        }
      }

      if (isPhoneValid) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_student_serial', serialInput);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ParentHomePage(student: studentDoc)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('رقم الهاتف غير متطابق مع الرقم المسجل لدينا للطالب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تسجيل الدخول: $e', style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🎨 1. الخلفية الانسيابية ثلاثية الأبعاد
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xffffffff),
                  Color(0xfff1f5f9),
                  Color(0xffe2e8f0),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),

          // 📐 2. رسم زخرفة هندسية إسلامية معاصرة هادئة جداً وشفافة بالخلفية لإبراز هيبة علوم القرآن
          Positioned.fill(
            child: CustomPaint(
              painter: IslamicPatternPainter(
                color: primaryColor.withOpacity(0.015), // هادئة جداً لمنع تشتيت العين
              ),
            ),
          ),

          // 🪐 3. هالات ضوئية عائمة خلف كرت التسجيل لتعطي طابع الأبعاد (Elegant Orbs)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            left: -50,
            child: CircleAvatar(
              radius: 130,
              backgroundColor: primaryColor.withOpacity(0.03),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1,
            right: -60,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: goldColor.withOpacity(0.03),
            ),
          ),

          // 🔐 4. كرت التسجيل والهوية الرقمية بالمنتصف
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 26.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // رمز المعهد الفخم بهالة دائرية مزدوجة مع تطعيم ذهبي راقٍ
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: goldColor.withOpacity(0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.05),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
                      ),
                      child: Icon(Icons.menu_book_rounded, size: 54, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // تدرج لوني انسيابي فخم لاسم البوابة (Gradient Shader)
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [primaryColor, const Color(0xff5f7d9a)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ).createShader(bounds),
                    child: const Text(
                      'بوابة أولياء الأمور', 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Cairo'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'معهد الشيخ سعيد العبدالله لعلوم القرآن', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 40),

                  // 💳 كرت الدخول المطور بحواف ذهبية انسيابية ناعمة جدًا وظلال عائمة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: goldColor.withOpacity(0.1), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.04),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: goldColor.withOpacity(0.02),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "أهلاً بك 👋",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor, fontFamily: 'Cairo'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "سجل دخولك برقم الطالب وهاتفكم للمتابعة",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 25),

                        // حقل الرقم التسلسلي المودرن بخلفية ناعمة وحواف انسيابية
                        TextField(
                          controller: _serialController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: primaryColor, fontWeight: FontWeight.bold),
                          decoration: _buildInputDecoration(
                            label: 'الرقم التسلسلي للطالب',
                            icon: Icons.pin_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // حقل رقم الهاتف المودرن
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: primaryColor, fontWeight: FontWeight.bold),
                          decoration: _buildInputDecoration(
                            label: 'رقم هاتف ولي الأمر المسجل لدينا',
                            icon: Icons.phone_android_rounded,
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // زر الدخول والمتابعة بـ الستايل العائم ذو التأثير البصري الراقي
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, const Color(0xff2f4356)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.25),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, // تفعيل التدرج اللوني للخلفية بالشفافية
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                  )
                                : const Text(
                                    'دخول ومتابعة', 
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة بناء التنسيق الفخم لحقول الإدخال
  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11.5, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7), size: 17),
      filled: true,
      fillColor: const Color(0xfff8fafc),
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor.withOpacity(0.4), width: 1.5),
      ),
    );
  }
}

// 📐 كلاس رسم الزخارف الهندسية الإسلامية الملوكية بدقة متناهية بالخلفية
class IslamicPatternPainter extends CustomPainter {
  final Color color;
  IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final double step = 90.0; // موازنة توزيع الأبعاد والزخارف على الشاشة
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        _draw8PointedStar(canvas, Offset(x, y), 22, paint);
      }
    }
  }

  // رسم النجمة الثمانية الهندسية الإسلامية بدقة انسيابية
  void _draw8PointedStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      double angle1 = (i * 45) * 3.141592653589793 / 180;
      double x1 = center.dx + radius * math.cos(angle1);
      double y1 = center.dy + radius * math.sin(angle1);

      double angle2 = ((i * 45) + 22.5) * 3.141592653589793 / 180;
      double x2 = center.dx + (radius * 0.65) * math.cos(angle2);
      double y2 = center.dy + (radius * 0.65) * math.sin(angle2);

      if (i == 0) {
        path.moveTo(x1, y1);
      } else {
        path.lineTo(x1, y1);
      }
      path.lineTo(x2, y2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}