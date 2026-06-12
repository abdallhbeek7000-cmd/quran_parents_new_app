import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  // 🚀 دالة تبديل الثيم وحفظه في ذاكرة الهاتف
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  // 🚀 دالة استرجاع الثيم عند فتح التطبيق
  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // الوضع النهاري هو الافتراضي (false)، وإذا كان محفوظ مسبقاً بيقرأه
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false; 
    notifyListeners();
  }
}