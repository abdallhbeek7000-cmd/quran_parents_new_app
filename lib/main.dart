import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 
import 'pages/login_page.dart';
import 'pages/parent_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة الفايربيز الرسمية والمستقرة للويب
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'معهد الشيخ سعيد العبدالله',
      theme: ThemeData(
        fontFamily: 'Cairo',
      ),
      home: const AuthWrapper(),
    );
  }
}

// 🧠 وجت الفحص الذكي: يفتح التطبيق بلمحة بصر ويفحص الحساب المحفوظ بدون تجميد الويب
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xfff5f7fa),
            body: Center(child: CircularProgressIndicator(color: Color(0xff425c75))),
          );
        }
        
        final String? savedSerial = snapshot.data!.getString('saved_student_serial');
        
        // إذا لم يجد حساباً سابقاً، يفتح صفحة تسجيل الدخول فوراً
        if (savedSerial == null || savedSerial.isEmpty) {
          return const LoginPage();
        }

        // إذا وجد حساباً، يجلب بيانات الطالب لفتح البوابة مباشرة
        int? serialAsInt = int.tryParse(savedSerial);
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('students')
              .where('serial', isEqualTo: serialAsInt ?? savedSerial)
              .limit(1)
              .get(),
          builder: (context, studentSnapshot) {
            if (!studentSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: Color(0xfff5f7fa),
                body: Center(child: CircularProgressIndicator(color: Color(0xff425c75))),
              );
            }
            if (studentSnapshot.data!.docs.isEmpty) {
              return const LoginPage();
            }
            return ParentHomePage(student: studentSnapshot.data!.docs.first);
          },
        );
      },
    );
  }
}