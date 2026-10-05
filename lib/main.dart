import 'package:flutter/foundation.dart'; // 🎯 للتحقق من بيئة التشغيل (kIsWeb)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/theme_provider.dart';
import 'firebase_options.dart'; 
import 'pages/login_page.dart';
import 'package:quran_parents_new/pages/parent_home_page.dart';
import 'pages/onboarding_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'إشعارات الحلقة المهمة', 
  description: 'هذه القناة مخصصة لإظهار تنبيهات الحفظ والغياب الفورية بصوت والبنر المنبثق.',
  importance: Importance.max, 
  playSound: true,
);

@pragma('vm:entry-point') 
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("استلام إشعار في الخلفية بنجاح: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🎯 التحكم بشريط النظام للأندرويد والآيفون فقط
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, 
        statusBarIconBrightness: Brightness.dark, 
      ),
    );
  }

  // 🎯 تهيئة الفايربيز بأمان
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("خطأ في تهيئة الفايربيز: $e");
  }

  // 🎯 تفعيل الإشعارات للموبايل فقط وحمايتها في الويب لمنع الشاشة البيضاء
  if (!kIsWeb) {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          print("تم الضغط على الإشعار المحلي! البيانات: ${details.payload}");
        },
      );

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, 
        badge: true,
        sound: true, 
      );
    } catch (e) {
      print("خطأ في إعداد الإشعارات: $e");
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
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
    
    if (!kIsWeb) {
      _setupInteractedMessage();

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
                icon: '@mipmap/launcher_icon',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });
    }
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _handleNotificationTap(RemoteMessage message) {
    print("🔔 تم الضغط على الإشعار في تطبيق الأهل! البيانات: ${message.data}");
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    const Color primaryColor = Color(0xff425c75); 
    const Color accentGold = Color(0xffd4af37);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'معهد الشيخ سعيد العبدالله',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'),
      ],
      locale: const Locale('ar', 'AE'),
      
      theme: ThemeData(
        fontFamily: 'Cairo',
        brightness: Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xfff1f5f9),
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: accentGold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: primaryColor,
          centerTitle: true,
          elevation: 0,
        ),
        dialogBackgroundColor: Colors.white.withOpacity(0.95),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
        ),
      ),

      darkTheme: ThemeData(
        fontFamily: 'Cairo', 
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xff121212),
        colorScheme: const ColorScheme.dark(
          primary: accentGold,
          secondary: primaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xff121212) : const Color(0xfff1f5f9);
    final indicatorColor = isDarkMode ? const Color(0xffd4af37) : const Color(0xff425c75);

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: bgColor,
            body: Center(child: CircularProgressIndicator(color: indicatorColor)),
          );
        }
        
        final prefs = snapshot.data!;
        final String? savedSerial = prefs.getString('saved_student_serial');
        final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        
        if (savedSerial == null || savedSerial.isEmpty) {
          return const LoginPage();
        }

        int? serialAsInt = int.tryParse(savedSerial);

        // 🎯 جلب الدورة الفعالة أولاً لاختيار طالب الدورة الجديدة فقط تجنباً للطلاب المنسوخين
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('cycles')
              .where('isClosed', isEqualTo: false)
              .limit(1)
              .get(),
          builder: (context, cycleSnapshot) {
            if (!cycleSnapshot.hasData) {
              return Scaffold(
                backgroundColor: bgColor,
                body: Center(child: CircularProgressIndicator(color: indicatorColor)),
              );
            }

            String? activeCycleId;
            if (cycleSnapshot.data!.docs.isNotEmpty) {
              activeCycleId = cycleSnapshot.data!.docs.first.id;
            }

            return FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('students')
                  .where('serial', isEqualTo: serialAsInt ?? savedSerial)
                  .get(),
              builder: (context, studentSnapshot) {
                if (!studentSnapshot.hasData) {
                  return Scaffold(
                    backgroundColor: bgColor,
                    body: Center(child: CircularProgressIndicator(color: indicatorColor)),
                  );
                }

                if (studentSnapshot.data!.docs.isEmpty) {
                  return const LoginPage();
                }

                var docs = studentSnapshot.data!.docs;
                DocumentSnapshot targetStudentDoc = docs.first;

                // اختيار حساب الطالب المربوط بالدورة النشطة الجديدة
                if (activeCycleId != null) {
                  for (var doc in docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['cycleId'] == activeCycleId) {
                      targetStudentDoc = doc;
                      break;
                    }
                  }
                }

                if (hasSeenOnboarding) {
                  return ParentHomePage(student: targetStudentDoc);
                } else {
                  return OnboardingPage(student: targetStudentDoc);
                }
              },
            );
          },
        );
      },
    );
  }
}