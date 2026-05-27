import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart'; // 🎯 تم تصحيح الـ Import
import 'package:url_launcher/url_launcher.dart';         // 🎯 تم تصحيح الـ Import

class UpdateChecker {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. قراءة رقم إصدار الجوال الحالي
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      int localVersion = int.tryParse(packageInfo.buildNumber) ?? 1;

      // 2. جلب إعدادات التحديث من الفايربيز
      DocumentSnapshot serverConfig = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('version_control')
          .get();

      if (!serverConfig.exists) return;

      Map<String, dynamic> data = serverConfig.data() as Map<String, dynamic>;
      
      // قراءة الحقول المخصصة للأهل فقط
      int serverVersion = int.tryParse(data['parents_current_version'].toString()) ?? 1;
      String updateUrl = data['update_url'] ?? '';
      bool forceUpdate = data['parents_force_update'] ?? false;

      // 3. المقارنة الآمنة
      if (serverVersion > localVersion && updateUrl.isNotEmpty) {
        if (!context.mounted) return;
        _showUpdateDialog(context, updateUrl, forceUpdate);
      }
    } catch (e) {
      print("خطأ أثناء فحص تحديثات الأهل: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String url, bool isForce) {
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (context) {
        return PopScope(
          canPop: !isForce,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Text("تحديث جديد متاح! 🚀", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              ],
            ),
            content: const Text(
              "تم إطلاق نسخة جديدة من تطبيق بوابة المتابعة تحتوي على تحسينات هامة وميزات فخمة جديدة للأهل. يرجى التحديث الآن لضمان استقرار الخدمة.",
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (!isForce)
                TextButton(
                  child: const Text("لاحقاً", style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.pop(context),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                ),
                onPressed: () async {
                  final Uri downloadUri = Uri.parse(url);
                  // 🎯 تم تصحيح وإغلاق سطر فتح الرابط بالكامل وبشكل مستقر
                  if (!await launchUrl(downloadUri, mode: LaunchMode.externalApplication)) {
                    print("Could not launch $url");
                  }
                },
                child: const Text("تحديث الآن 📥", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}