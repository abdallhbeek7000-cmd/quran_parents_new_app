import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'parent_home_page.dart';
import 'onboarding_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  final Color primaryColor = const Color(0xff425c75);
  final Color goldColor = const Color(0xffD4AF37);

  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: -10, end: 20).animate(
        CurvedAnimation(parent: _bgController, curve: Curves.easeInOutSine));

    _checkSavedLogin();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _serialController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // 🎯 جلب ID الدورة الفعالة حالياً مطابقاً تماماً لحقول قاعدة البيانات عندك (active: true / isCurrent: true)
  Future<String> _getActiveCycleId() async {
    try {
      var activeSnap = await FirebaseFirestore.instance
          .collection('cycles')
          .where('active', isEqualTo: true)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (activeSnap.docs.isNotEmpty) {
        return activeSnap.docs.first.id;
      }

      var currentSnap = await FirebaseFirestore.instance
          .collection('cycles')
          .where('isCurrent', isEqualTo: true)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (currentSnap.docs.isNotEmpty) {
        return currentSnap.docs.first.id;
      }

      var statusSnap = await FirebaseFirestore.instance
          .collection('cycles')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (statusSnap.docs.isNotEmpty) {
        return statusSnap.docs.first.id;
      }

      var latestSnap = await FirebaseFirestore.instance
          .collection('cycles')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      if (latestSnap.docs.isNotEmpty) {
        return latestSnap.docs.first.id;
      }
    } catch (e) {
      debugPrint("خطأ في تحديد الدورة الفعالة: $e");
    }
    return '';
  }

  // 🎯 دالة جلب مستند الطالب بالرقم التسلسلي والدورة الفعالة حصراً
  Future<DocumentSnapshot?> _getStudentForActiveCycle(String serialInput) async {
    String activeCycleId = await _getActiveCycleId();
    final int? serialNum = int.tryParse(serialInput);

    Query query = FirebaseFirestore.instance
        .collection('students')
        .where('serial', whereIn: [serialNum ?? serialInput, serialInput]);

    var snap = await query.get(const GetOptions(source: Source.server));

    if (snap.docs.isEmpty) return null;

    if (activeCycleId.isNotEmpty) {
      for (var doc in snap.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String docCycleId = data['cycleId']?.toString().trim() ?? '';
        if (docCycleId == activeCycleId) {
          return doc;
        }
      }
    }

    return snap.docs.last;
  }

  // 🎯 استخراج معرف المستند من QR Code (يدعم ID مباشر مثل 22BdgUE9tNPW9U1OFEfv أو رابط/نص يحتوي عليه)
  String _extractStudentDocIdFromQr(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last.trim();
      if (lastSegment.isNotEmpty) {
        return lastSegment;
      }
    }

    if (trimmed.contains('/')) {
      return trimmed.split('/').last.trim();
    }

    return trimmed;
  }

  Future<void> _completeLoginNavigation(
    DocumentSnapshot studentDoc, {
    String? serialToSave,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = studentDoc.data() as Map<String, dynamic>? ?? {};
    final String serialValue =
        (serialToSave != null && serialToSave.isNotEmpty)
            ? serialToSave
            : (data['serial']?.toString().trim() ?? '');

    if (serialValue.isNotEmpty) {
      await prefs.setString('saved_student_serial', serialValue);
    }

    final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => hasSeenOnboarding
            ? ParentHomePage(student: studentDoc)
            : OnboardingPage(student: studentDoc),
      ),
    );
  }

  // 🎯 تسجيل الدخول عبر مسح QR Code لبطاقة الطالب
  Future<void> _loginWithQrCode(String rawQrValue) async {
    final String docId = _extractStudentDocIdFromQr(rawQrValue);
    if (docId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('رمز QR غير صالح، حاول مرة أخرى',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef =
          FirebaseFirestore.instance.collection('students').doc(docId);
      final docSnap = await docRef.get(const GetOptions(source: Source.server));

      if (!docSnap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                  'لم يتم العثور على حساب طالب مطابق لرمز QR هذا',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // إذا كان هناك حساب أحدث لنفس الرقم التسلسلي في الدورة الفعالة نستخدمه، وإلا نستخدم المستند الممسوح مباشرةً
      final data = docSnap.data() as Map<String, dynamic>? ?? {};
      final String serialStr = data['serial']?.toString().trim() ?? '';
      DocumentSnapshot targetDoc = docSnap;

      if (serialStr.isNotEmpty) {
        final activeCycleDoc = await _getStudentForActiveCycle(serialStr);
        if (activeCycleDoc != null) {
          final activeCycleId = await _getActiveCycleId();
          final activeDocData =
              activeCycleDoc.data() as Map<String, dynamic>? ?? {};
          final activeDocCycleId =
              activeDocData['cycleId']?.toString().trim() ?? '';
          if (activeCycleId.isNotEmpty && activeDocCycleId == activeCycleId) {
            targetDoc = activeCycleDoc;
          }
        }
      }

      await _completeLoginNavigation(targetDoc, serialToSave: serialStr);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التحقق من رمز QR: $e',
                style: const TextStyle(fontFamily: 'Cairo')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openQrScannerSheet() async {
    if (_isLoading) return;

    final String? scannedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrCardScannerSheet(
        primaryColor: primaryColor,
        goldColor: goldColor,
      ),
    );

    if (scannedValue != null && scannedValue.trim().isNotEmpty && mounted) {
      await _loginWithQrCode(scannedValue);
    }
  }

  void _checkSavedLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? savedSerial = prefs.getString('saved_student_serial');
    final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (savedSerial != null && savedSerial.isNotEmpty) {
      setState(() => _isLoading = true);

      try {
        DocumentSnapshot? targetStudent =
            await _getStudentForActiveCycle(savedSerial);

        if (targetStudent != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => hasSeenOnboarding
                  ? ParentHomePage(student: targetStudent)
                  : OnboardingPage(student: targetStudent),
            ),
          );
          return;
        } else {
          await prefs.remove('saved_student_serial');
        }
      } catch (e) {
        debugPrint("Error during auto login sync: $e");
      }

      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _login() async {
    final String serialInput = _serialController.text.trim();
    final String phoneInput = _phoneController.text.trim().replaceAll(' ', '');

    if (serialInput.isEmpty || phoneInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('الرجاء إدخال الرقم التسلسلي ورقم الهاتف',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot? studentDoc =
          await _getStudentForActiveCycle(serialInput);

      if (studentDoc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                  'الرقم التسلسلي غير صحيح أو الطالب غير مسجل',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, dynamic> studentData =
          studentDoc.data() as Map<String, dynamic>;
      final String dbPhone =
          (studentData['phone'] ?? '').toString().trim().replaceAll(' ', '');

      bool isPhoneValid = false;
      if (phoneInput.isNotEmpty && dbPhone.isNotEmpty) {
        if (phoneInput == dbPhone ||
            dbPhone.endsWith(phoneInput) ||
            phoneInput.endsWith(dbPhone)) {
          isPhoneValid = true;
        }
      }

      if (isPhoneValid) {
        await _completeLoginNavigation(studentDoc, serialToSave: serialInput);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(
                  'رقم الهاتف غير متطابق مع الرقم المسجل لدينا للطالب',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ أثناء تسجيل الدخول: $e',
                  style: const TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xffffffff),
                  Color(0xfff1f5f9),
                  Color(0xffe2e8f0)
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: IslamicPatternPainter(
                  color: primaryColor.withValues(alpha: 0.025)),
            ),
          ),
          AnimatedBuilder(
            animation: _bgAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: (MediaQuery.of(context).size.height * 0.1) +
                        _bgAnimation.value,
                    left: -50 - (_bgAnimation.value / 2),
                    child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withValues(alpha: 0.06))),
                  ),
                  Positioned(
                    bottom: (MediaQuery.of(context).size.height * 0.1) -
                        _bgAnimation.value,
                    right: -60 + _bgAnimation.value,
                    child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: goldColor.withValues(alpha: 0.06))),
                  ),
                ],
              );
            },
          ),
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 26.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: goldColor.withValues(alpha: 0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: primaryColor.withValues(alpha: 0.08),
                            blurRadius: 25,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: primaryColor.withValues(alpha: 0.15),
                              width: 1)),
                      child: Icon(Icons.menu_book_rounded,
                          size: 54, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [primaryColor, const Color(0xff5f7d9a)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ).createShader(bounds),
                    child: const Text('بوابة أولياء الأمور',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Cairo')),
                  ),
                  const SizedBox(height: 4),
                  Text('معهد الشيخ سعيد العبدالله لعلوم القرآن',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo')),
                  const SizedBox(height: 34),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 25,
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("أهلاً بك 👋",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontFamily: 'Cairo')),
                            const SizedBox(height: 4),
                            Text(
                                "سجل دخولك برقم الطالب وهاتفكم أو امسح بطاقة الطالب",
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 11.5,
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 22),
                            TextField(
                              controller: _serialController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold),
                              decoration: _buildGlassInputDecoration(
                                  label: 'الرقم التسلسلي للطالب',
                                  icon: Icons.pin_rounded),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 14,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold),
                              decoration: _buildGlassInputDecoration(
                                  label: 'رقم هاتف ولي الأمر المسجل لدينا',
                                  icon: Icons.phone_android_rounded),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      const Color(0xff2f4356)
                                    ],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6))
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16))),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.2))
                                    : const Text('دخول ومتابعة',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Cairo',
                                            color: Colors.white,
                                            letterSpacing: 0.5)),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: primaryColor.withValues(alpha: 0.16),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(
                                    "أو",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          primaryColor.withValues(alpha: 0.65),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: primaryColor.withValues(alpha: 0.16),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildQrLoginButton(),
                          ],
                        ),
                      ),
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

  Widget _buildQrLoginButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _openQrScannerSheet,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.85),
                const Color(0xfffef9ec).withValues(alpha: 0.85),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: goldColor.withValues(alpha: 0.75),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: goldColor.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [goldColor, const Color(0xffb5964e)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "دخول سريع عبر QR Code",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    "امسح رمز البطاقة المخصص للطالب",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildGlassInputDecoration(
      {required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: primaryColor.withValues(alpha: 0.7),
          fontSize: 12,
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600),
      prefixIcon:
          Icon(icon, color: primaryColor.withValues(alpha: 0.8), size: 18),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.8), width: 1.2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: goldColor.withValues(alpha: 0.8), width: 1.5)),
    );
  }
}

class _QrCardScannerSheet extends StatefulWidget {
  final Color primaryColor;
  final Color goldColor;

  const _QrCardScannerSheet({
    required this.primaryColor,
    required this.goldColor,
  });

  @override
  State<_QrCardScannerSheet> createState() => _QrCardScannerSheetState();
}

class _QrCardScannerSheetState extends State<_QrCardScannerSheet> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasCaptured = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasCaptured) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isNotEmpty) {
        _hasCaptured = true;
        Navigator.of(context).pop(raw);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xff0f172a),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: widget.goldColor.withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Stack(
          children: [
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),
            // تظليل خفيف حول إطار المسح
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.45),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 245,
                      height: 245,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // رأس النافذة وأزرار التحكم (إغلاق + فلاش + تبديل الكاميرا)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleControl(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: widget.goldColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      "مسح بطاقة الطالب",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.goldColor,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildCircleControl(
                        icon: _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        active: _torchOn,
                        onTap: () async {
                          await _scannerController.toggleTorch();
                          if (mounted) {
                            setState(() => _torchOn = !_torchOn);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildCircleControl(
                        icon: Icons.cameraswitch_rounded,
                        onTap: () => _scannerController.switchCamera(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // الإطار الذهبي المخصص لرمز QR
            Center(
              child: Container(
                width: 245,
                height: 245,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: widget.goldColor,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.goldColor.withValues(alpha: 0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
            // تعليمات أسفل الإطار
            Positioned(
              bottom: 28,
              left: 24,
              right: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "وجّه الكاميرا نحو رمز QR الموجود على بطاقة الطالب",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "سيتم تسجيل الدخول تلقائياً فور التعرف على الرمز",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleControl({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? widget.goldColor.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(
            color: active
                ? widget.goldColor
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? widget.goldColor : Colors.white,
        ),
      ),
    );
  }
}

class IslamicPatternPainter extends CustomPainter {
  final Color color;
  IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const double step = 90.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        _draw8PointedStar(canvas, Offset(x, y), 22, paint);
      }
    }
  }

  void _draw8PointedStar(
      Canvas canvas, Offset center, double radius, Paint paint) {
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