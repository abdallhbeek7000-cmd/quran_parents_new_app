import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter/material.dart'; 
import 'package:googleapis_auth/auth_io.dart';

class NotificationService {
  
  // 🔐 دالة جلب تصريح الوصول الذكي بالقراءة المحلية الآمنة
  static Future<String> _getAccessToken() async {
    try {
      final String serviceAccountStr = await rootBundle.loadString('assets/service-account.json');
      final Map<String, dynamic> serviceAccountJson = jsonDecode(serviceAccountStr);
      
      final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      
      final client = await clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      print("Error reading secure service account asset: $e");
      return '';
    }
  }

  // 🚀 الدالة الجوكر: ترسل الإشعار للطالب أو المشرف بذكاء
  static Future<void> sendAndSaveNotification({
    required String studentId, // يعمل كمعرف عام (يستقبل آي دي طالب أو مشرف)
    required String title,
    required String body,
    required String type, 
    BuildContext? context, 
  }) async {
    try {
      // 🎯 1. البحث الذكي لتحديد نوع المستلم
      String targetCollection = 'students';
      DocumentSnapshot targetDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();

      // إن لم يكن طالباً، ابحث في المشرفين
      if (!targetDoc.exists) {
        targetDoc = await FirebaseFirestore.instance.collection('supervisors').doc(studentId).get();
        if (targetDoc.exists) {
          targetCollection = 'supervisors';
        } else {
          // إن لم يكن مشرفاً، ابحث في المدراء
          targetDoc = await FirebaseFirestore.instance.collection('users').doc(studentId).get();
          if (targetDoc.exists) {
            targetCollection = 'users';
          }
        }
      }

      if (!targetDoc.exists || targetDoc.data() == null) {
        print("❌ المستلم غير موجود في أي جدول. تم إلغاء الإشعار.");
        return;
      }

      // 🎯 2. توثيق التنبيه في مجموعة المستلم الصحيحة
      await FirebaseFirestore.instance
          .collection(targetCollection)
          .doc(studentId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print("Notification documented in [$targetCollection] successfully! ✅");

      // 🎯 3. جلب التوكن وإرسال الإشعار
      var data = targetDoc.data() as Map<String, dynamic>;
      String? fcmToken = data['fcmToken'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        final String accessToken = await _getAccessToken();
        if (accessToken.isEmpty) {
          print("Access token generation failed.");
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: Colors.red, content: Text("فشل في قراءة ملف المفتاح السري.")),
            );
          }
          return;
        }
        
        const String projectId = 'quran-habal';
        var url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

        var headers = {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        };

        var requestBody = jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'studentId': studentId,
              'type': type,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'high_importance_channel',
                'sound': 'default',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              }
            },
          }
        });

        var response = await http.post(url, headers: headers, body: requestBody);
        
        if (response.statusCode == 200) {
          print("Push Notification fired successfully to $targetCollection! 🔔🚀");
          if (context != null && context.mounted) {
            // يمكنك تفعيل هذه الرسالة إن أردت
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(backgroundColor: Colors.green, content: Text("🚀 تم إرسال الإشعار بنجاح!")),
            // );
          }
        } else {
          print("FCM V1 Broadcast Error: ${response.statusCode} - ${response.body}");
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red, 
                duration: const Duration(seconds: 10),
                content: Text("❌ خطأ من جوجل: ${response.statusCode}\n${response.body}")
              ),
            );
          }
        }
      } else {
        print("FCM Token is empty for this user ($targetCollection). لم يتم تسجيل الدخول لتلقي الإشعارات.");
      }
    } catch (e) {
      print("Error inside V1 Notification Service: $e");
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.orange, content: Text("⚠️ خطأ في التطبيق: $e")),
        );
      }
    }
  }
}