import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  // دالة التبديل بين الوضع الليلي والنهاري
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // 🎯 تحديث كل شاشات التطبيق فوراً
    
    // حفظ اختيار المستخدم حتى لو أغلق التطبيق
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }

  // دالة قراءة السمة المحفوظة عند فتح التطبيق
  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }
}