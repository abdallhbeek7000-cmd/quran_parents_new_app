import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🎯 مكتبة الفايربيز ماسيجنج الأساسية للأندرويد
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart'; 
import 'pages/login_page.dart';
import 'pages/parent_home_page.dart';

// تعريف أداة الإشعارات المحلية كمتغير عام ليكون متاحاً في كل مكان
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 🎯 1️⃣ تعريف قناة الإشعارات ذات الأهمية القصوى لإصدار صوت وبنر منبثق فوري
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // نفس الـ ID الموجه من تطبيق المشرفين بالملي
  'إشعارات الحلقة المهمة', 
  description: 'هذه القناة مخصصة لإظهار تنبيهات الحفظ والغياب الفورية بصوت والبنر المنبثق.',
  importance: Importance.max, // تفعيل البنر العلوي المنبثق (Heads-up)
  playSound: true,
);

// 🎯 2️⃣ دالة معالجة الإشعارات في الخلفية (Top-level function) مكتوبة خارج أي كلاس
@pragma('vm:entry-point') // إلزامية لحماية الدالة من الحذف أثناء بناء النسخة النهائية APK
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("استلام إشعار في الخلفية بنجاح: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة الفايربيز
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🎯 3️⃣ الربط الصحيح والحديث المتوافق مع الفايربيز الجديد (onBackgroundMessage) لاختفاء الخط الأحمر نهائياً
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🎯 4️⃣ تسجيل وقفل قناة الصوت والبنر بداخل نظام أندرويد للجوال قبل تشغيل التطبيق
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // إعدادات تهيئة الإشعارات المحلية للأندرويد والأيقونة الرسمية
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      // هنا يمكنك إضافة حدث عند ضغط ولي الأمر على الإشعار مستقبلاً
    },
  );

  // 🎯 5️⃣ خيارات إظهار الصوت والبنر والتطبيق مفتوح في الوجه (Foreground)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, 
    badge: true,
    sound: true, 
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  @override
  void initState() {
    super.initState();

    // 🎯 6️⃣ الاستماع الفوري للإشعارات المستلمة والتطبيق مفتوح بالوجه وعرضها كـ بنر بصوت فوري عبر القناة الصوتية
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'معهد الشيخ سعيد العبدالله',
      theme: ThemeData(
        fontFamily: 'Cairo', // الحفاظ على خط القاهرة الفخم الخاص بك
      ),
      home: const AuthWrapper(),
    );
  }
}

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
        
        if (savedSerial == null || savedSerial.isEmpty) {
          return const LoginPage();
        }

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