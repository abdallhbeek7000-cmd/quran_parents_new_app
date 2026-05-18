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

  final Color primaryColor = const Color(0xff425c75);

  void _login() async {
    final String serialInput = _serialController.text.trim();
    final String phoneInput = _phoneController.text.trim().replaceAll(' ', '');

    if (serialInput.isEmpty || phoneInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الرقم التسلسلي ورقم الهاتف')),
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
            const SnackBar(content: Text('الرقم التسلسلي غير صحيح أو الطالب غير مسجل')),
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
            const SnackBar(content: Text('رقم الهاتف غير متطابق مع الرقم المسجل لدينا للطالب')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تسجيل الدخول: $e')),
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
      backgroundColor: const Color(0xfff5f7fa),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_rounded, size: 80, color: primaryColor),
              const SizedBox(height: 15),
              Text('بوابة أولياء الأمور', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
              const Text('معهد حبل الله المبارك لعلوم القرآن', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _serialController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'الرقم التسلسلي للطالب',
                  prefixIcon: Icon(Icons.pin, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم هاتف ولي الأمر المسجل',
                  prefixIcon: Icon(Icons.phone_android, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('دخول ومتابعة الأبناء', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}