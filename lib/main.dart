import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎯 للتحكم بشفافية شريط الحالة (Status Bar)
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart'; // 🎯 لقراءة وتفعيل الثيم
import 'package:flutter_localizations/flutter_localizations.dart'; // 🚀 استدعاء مكتبة اللغات لقلب التطبيق عربي (RTL)
import 'services/theme_provider.dart'; // 🎯 استدعاء مزود السمة
import 'firebase_options.dart'; 
import 'pages/login_page.dart';
import 'package:quran_parents_new/pages/parent_home_page.dart';
import 'pages/onboarding_page.dart'; // 🎯 استدعاء صفحة الترحيب الجديدة

// تعريف أداة الإشعارات المحلية كمتغير عام ليكون متاحاً في كل مكان
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 🎯 المفتاح العالمي السحري للتحكم بالمنبثقات والتوجيه (أضفناه هنا لتسهيل فتح الصفحات لاحقاً)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🎯 1️⃣ تعريف قناة الإشعارات ذات الأهمية القصوى لإصدار صوت وبنر منبثق فوري
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', 
  'إشعارات الحلقة المهمة', 
  description: 'هذه القناة مخصصة لإظهار تنبيهات الحفظ والغياب الفورية بصوت والبنر المنبثق.',
  importance: Importance.max, 
  playSound: true,
);

// 🎯 2️⃣ دالة معالجة الإشعارات في الخلفية
@pragma('vm:entry-point') 
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("استلام إشعار في الخلفية بنجاح: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎯 اللمسة السحرية: جعل شريط البطارية والساعة شفاف بالكامل ليتناسب مع الزجاج الانسيابي
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, 
      statusBarIconBrightness: Brightness.dark, 
    ),
  );

  // تهيئة الفايربيز
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🎯 3️⃣ الربط الصحيح لاختفاء الخط الأحمر نهائياً
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🎯 4️⃣ تسجيل وقفل قناة الصوت والبنر
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // إعدادات تهيئة الإشعارات المحلية
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) {
      // 🚀 هنا يتم التقاط الضغطة إذا كان التطبيق مفتوحاً (Foreground)
      print("تم الضغط على الإشعار المحلي! البيانات: ${details.payload}");
    },
  );

  // 🎯 5️⃣ خيارات إظهار الصوت والبنر والتطبيق مفتوح في الوجه
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, 
    badge: true,
    sound: true, 
  );

  // 🎯 6️⃣ تغليف التطبيق بمزود السمة (ThemeProvider)
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
    
    // 🚀 تفعيل مراقب الضغط على الإشعارات
    _setupInteractedMessage();

    // الاستماع الفوري للإشعارات والتطبيق مفتوح بالوجه
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
          payload: message.data.toString(), // حفظ البيانات لاستخدمها عند الضغط
        );
      }
    });
  }

  // 🚀 الدالة المسؤولة عن فتح التطبيق عند الضغط على الإشعار
  Future<void> _setupInteractedMessage() async {
    // 1. التطبيق كان مغلقاً بالكامل (Terminated) وقام المستخدم بالضغط على الإشعار
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // 2. التطبيق يعمل في الخلفية (Background) وقام المستخدم بالضغط على الإشعار
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  // 🚀 ماذا يحدث عند الضغط على الإشعار؟
  void _handleNotificationTap(RemoteMessage message) {
    print("🔔 تم الضغط على الإشعار في تطبيق الأهل! البيانات: ${message.data}");
    
    // يمكنك لاحقاً إضافة توجيه هنا باستخدام navigatorKey 
    // مثال: navigatorKey.currentState?.push(MaterialPageRoute(...));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    const Color primaryColor = Color(0xff425c75); 
    const Color accentGold = Color(0xffd4af37);

    return MaterialApp(
      navigatorKey: navigatorKey, // 🎯 ربط المفتاح العالمي هنا
      debugShowCheckedModeBanner: false,
      title: 'معهد الشيخ سعيد العبدالله',
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // 🚀 الأسطر السحرية لقلب التطبيق بالكامل ليصبح عربي (RTL)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'), // 👈 دعم اللغة العربية
      ],
      locale: const Locale('ar', 'AE'), // 👈 فرض العربية كلغة أساسية وإجبارية
      
      // ☀️ السمة النهارية (الزجاج الفاتح)
      theme: ThemeData(
        fontFamily: 'Cairo', // 🎯 توحيد خط Cairo
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

      // 🌙 السمة الليلية (الزجاج الداكن الفخم)
      darkTheme: ThemeData(
        fontFamily: 'Cairo', 
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: const Color(0xff121212),
        colorScheme: const ColorScheme.dark(
          primary: accentGold,
          secondary: primaryColor,
        ),
        cardTheme: const CardTheme(color: Color(0xff1e293b)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        dialogBackgroundColor: const Color(0xff1e293b).withOpacity(0.95),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xff1e293b).withOpacity(0.95),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
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
    // 🎯 استخدام المظهر لتلوين شاشة التحميل بشكل ديناميكي
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
        final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false; // 🎯 قراءة قيمة التخطي
        
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
              return Scaffold(
                backgroundColor: bgColor,
                body: Center(child: CircularProgressIndicator(color: indicatorColor)),
              );
            }
            if (studentSnapshot.data!.docs.isEmpty) {
              return const LoginPage();
            }
            
            // 🎯 التوجيه الذكي بناءً على قيمة الشاشة الترحيبية
            if (hasSeenOnboarding) {
              return ParentHomePage(student: studentSnapshot.data!.docs.first);
            } else {
              return OnboardingPage(student: studentSnapshot.data!.docs.first);
            }
          },
        );
      },
    );
  }
}