import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart' as rec;
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/notification_service.dart';

class ParentChatTab extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String supervisorId;
  final String supervisorName;
  final bool isDarkMode;
  final String? initialChatId;
  final String? initialTargetId;
  final bool? initialIsSupervisor;

  const ParentChatTab({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.supervisorId,
    required this.supervisorName,
    required this.isDarkMode,
    this.initialChatId,
    this.initialTargetId,
    this.initialIsSupervisor,
  });

  @override
  State<ParentChatTab> createState() => _ParentChatTabState();
}

class _ParentChatTabState extends State<ParentChatTab>
    with AutomaticKeepAliveClientMixin {
  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffcdb375);

  final TextEditingController _peerSearchController = TextEditingController();
  String _peerSearchQuery = '';

  late final Stream<QuerySnapshot> _cyclesStream;
  Stream<QuerySnapshot>? _peersStream;
  Stream<DocumentSnapshot>? _supervisorDocStream;
  Stream<DocumentSnapshot>? _supervisorChatStream;

  _ChatTarget? _activeTarget;
  bool _initialChatHandled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initStreams();
    _tryOpenInitialChat();
  }

  @override
  void didUpdateWidget(covariant ParentChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supervisorId != widget.supervisorId ||
        oldWidget.studentId != widget.studentId) {
      _initStreams();
    }
    if (oldWidget.initialChatId != widget.initialChatId ||
        oldWidget.initialTargetId != widget.initialTargetId) {
      _initialChatHandled = false;
      _tryOpenInitialChat();
    }
  }

  void _initStreams() {
    _cyclesStream = FirebaseFirestore.instance.collection('cycles').snapshots();
    if (widget.supervisorId.isNotEmpty) {
      _peersStream = FirebaseFirestore.instance
          .collection('students')
          .where('supervisorId', isEqualTo: widget.supervisorId)
          .snapshots();
      _supervisorDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.supervisorId)
          .snapshots();
      _supervisorChatStream = FirebaseFirestore.instance
          .collection('chats')
          .doc('${widget.studentId}_${widget.supervisorId}')
          .snapshots();
    }
  }

  Future<void> _tryOpenInitialChat() async {
    if (_initialChatHandled) return;
    final reqChatId = widget.initialChatId?.trim() ?? '';
    final reqTargetId = widget.initialTargetId?.trim() ?? '';
    if (reqChatId.isEmpty && reqTargetId.isEmpty) return;

    _initialChatHandled = true;
    final supChatId = '${widget.studentId}_${widget.supervisorId}';
    final bool isSup = widget.initialIsSupervisor == true ||
        reqChatId == supChatId ||
        (widget.supervisorId.isNotEmpty && reqTargetId == widget.supervisorId);

    if (isSup && widget.supervisorId.isNotEmpty) {
      String supImg = '';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.supervisorId)
            .get();
        if (doc.exists) {
          supImg = _extractImageUrl(doc.data());
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _activeTarget = _ChatTarget(
          chatId: supChatId,
          targetId: widget.supervisorId,
          targetName: widget.supervisorName,
          targetSubtitle: 'المشرف المتابع للحلقة',
          avatarUrl: supImg,
          isSupervisor: true,
        );
      });
      return;
    }

    String peerId = reqTargetId;
    if (peerId.isEmpty && reqChatId.startsWith('peer_')) {
      final parts = reqChatId.replaceFirst('peer_', '').split('_');
      peerId = parts.firstWhere((id) => id != widget.studentId, orElse: () => '');
    }
    if (peerId.isEmpty) return;

    String peerName = 'طالب في الحلقة';
    String peerImg = '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(peerId)
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        peerName = (d['name'] ?? peerName).toString();
        peerImg = _extractImageUrl(d);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _activeTarget = _ChatTarget(
        chatId: reqChatId.isNotEmpty ? reqChatId : _buildPeerChatId(peerId),
        targetId: peerId,
        targetName: peerName,
        targetSubtitle: 'زميل في حلقة ${widget.supervisorName}',
        avatarUrl: peerImg,
        isSupervisor: false,
      );
    });
  }

  @override
  void dispose() {
    _peerSearchController.dispose();
    super.dispose();
  }

  String _extractImageUrl(Map<String, dynamic>? data) {
    if (data == null) return '';
    const possibleKeys = [
      'imageUrl',
      'photoUrl',
      'image',
      'photo',
      'avatarUrl',
      'profileImage',
      'userImage',
      'avatar',
    ];
    for (final key in possibleKeys) {
      final val = data[key]?.toString().trim() ?? '';
      if (val.isNotEmpty &&
          (val.startsWith('http://') || val.startsWith('https://'))) {
        return val;
      }
    }
    return '';
  }

  String? _extractDocCycleId(Map<String, dynamic> data) {
    final raw = data['cycleId'] ??
        data['cycle_id'] ??
        data['activeCycleId'] ??
        data['currentCycleId'];
    if (raw == null) return null;
    final val = raw.toString().trim();
    return val.isEmpty ? null : val;
  }

  bool _belongsToActiveCycle(
    Map<String, dynamic> studentData,
    String? activeCycleId,
    String? activeCycleName,
  ) {
    if (activeCycleId == null || activeCycleId.isEmpty) return true;

    final docCycle = _extractDocCycleId(studentData);
    if (docCycle != null && docCycle.isNotEmpty) {
      if (docCycle == activeCycleId) return true;
      if (activeCycleName != null &&
          activeCycleName.trim().isNotEmpty &&
          docCycle.toLowerCase() == activeCycleName.trim().toLowerCase()) {
        return true;
      }
      return false;
    }

    final dynamic cyclesList = studentData['cycles'] ?? studentData['cycleIds'];
    if (cyclesList is List) {
      return cyclesList.any((item) {
        final s = item?.toString().trim() ?? '';
        return s == activeCycleId ||
            (activeCycleName != null &&
                activeCycleName.trim().isNotEmpty &&
                s.toLowerCase() == activeCycleName.trim().toLowerCase());
      });
    }

    return false;
  }

  String _buildPeerChatId(String otherStudentId) {
    final ids = [widget.studentId, otherStudentId]..sort();
    return 'peer_${ids[0]}_${ids[1]}';
  }

  String _formatListTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'م' : 'ص';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min $amPm';
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_activeTarget != null) {
      return _LiquidConversationView(
        key: ValueKey(_activeTarget!.chatId),
        currentStudentId: widget.studentId,
        currentStudentName: widget.studentName,
        target: _activeTarget!,
        isDarkMode: widget.isDarkMode,
        onBack: () => setState(() => _activeTarget = null),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _cyclesStream,
      builder: (context, cyclesSnap) {
        String? activeCycleId;
        String? activeCycleName;

        if (cyclesSnap.hasData && cyclesSnap.data!.docs.isNotEmpty) {
          for (final doc in cyclesSnap.data!.docs) {
            final cData = doc.data() as Map<String, dynamic>;
            final bool isCurrent = cData['isCurrent'] == true;
            final bool isActive = cData['active'] == true ||
                cData['isActive'] == true ||
                cData['status'] == 'active';
            final bool isNotClosed =
                cData['isClosed'] != true && cData['archived'] != true;

            if ((isCurrent || isActive) && isNotClosed) {
              activeCycleId = doc.id.trim();
              activeCycleName = (cData['name'] ?? cData['title'])?.toString();
              break;
            }
          }
        }

        return _buildConversationsHub(
          activeCycleId: activeCycleId,
          activeCycleName: activeCycleName,
        );
      },
    );
  }

  Widget _buildConversationsHub({
    required String? activeCycleId,
    required String? activeCycleName,
  }) {
    final bool isDark = widget.isDarkMode;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 124),
      children: [
        _buildFastCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          borderColor: accentGold.withOpacity(0.45),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentGold, const Color(0xffb5964e)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.forum_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "التواصل والمحادثات",
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                    ),
                    Text(
                      activeCycleName != null && activeCycleName.trim().isNotEmpty
                          ? "زملاء الحلقة في دورة: $activeCycleName"
                          : "تواصل مع مشرفك وزملائك في الدورة الحالية",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (widget.supervisorId.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 15, color: accentGold),
                const SizedBox(width: 6),
                Text(
                  "مشرف الحلقة",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? accentGold : primaryColor,
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: _supervisorDocStream,
            builder: (context, supSnap) {
              String supImg = '';
              if (supSnap.hasData && supSnap.data!.exists) {
                supImg = _extractImageUrl(
                    supSnap.data!.data() as Map<String, dynamic>?);
              }

              final String supChatId =
                  '${widget.studentId}_${widget.supervisorId}';

              return StreamBuilder<DocumentSnapshot>(
                stream: _supervisorChatStream,
                builder: (context, chatSnap) {
                  String lastMsg = 'اضغط لبدء المحادثة مع المشرف';
                  String timeStr = '';
                  int unread = 0;

                  if (chatSnap.hasData && chatSnap.data!.exists) {
                    final cData =
                        chatSnap.data!.data() as Map<String, dynamic>;
                    if ((cData['lastMessage']?.toString() ?? '').isNotEmpty) {
                      lastMsg = cData['lastMessage'].toString();
                    }
                    timeStr =
                        _formatListTime(cData['lastMessageTime'] as Timestamp?);
                    unread = (cData['unreadByParent'] is num)
                        ? (cData['unreadByParent'] as num).toInt()
                        : 0;
                  }

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _activeTarget = _ChatTarget(
                          chatId: supChatId,
                          targetId: widget.supervisorId,
                          targetName: widget.supervisorName,
                          targetSubtitle: 'المشرف المتابع للحلقة',
                          avatarUrl: supImg,
                          isSupervisor: true,
                        );
                      });
                    },
                    child: _buildFastCard(
                      padding: const EdgeInsets.all(14),
                      borderColor: accentGold.withOpacity(0.72),
                      gradientColors: isDark
                          ? [
                              accentGold.withOpacity(0.18),
                              Colors.white.withOpacity(0.04),
                            ]
                          : [
                              Colors.white.withOpacity(0.9),
                              const Color(0xfffef9ec).withOpacity(0.8),
                            ],
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: accentGold, width: 2),
                                ),
                                child: ClipOval(
                                  child: supImg.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: supImg,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 120,
                                          errorWidget: (_, __, ___) =>
                                              _buildAvatarFallback(
                                                  widget.supervisorName, true),
                                        )
                                      : _buildAvatarFallback(
                                          widget.supervisorName, true),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: accentGold,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: isDark
                                            ? const Color(0xff0f172a)
                                            : Colors.white,
                                        width: 1.5),
                                  ),
                                  child: const Icon(Icons.star_rounded,
                                      size: 10, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.supervisorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: isDark
                                              ? Colors.white
                                              : primaryColor,
                                        ),
                                      ),
                                    ),
                                    if (timeStr.isNotEmpty)
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: unread > 0
                                              ? accentGold
                                              : (isDark
                                                  ? Colors.white54
                                                  : Colors.grey.shade600),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          fontWeight: unread > 0
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: unread > 0
                                              ? (isDark
                                                  ? Colors.white
                                                  : Colors.black87)
                                              : (isDark
                                                  ? Colors.white60
                                                  : Colors.grey.shade700),
                                        ),
                                      ),
                                    ),
                                    if (unread > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accentGold,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 10),
          child: Row(
            children: [
              Icon(Icons.groups_rounded,
                  size: 17, color: isDark ? accentGold : primaryColor),
              const SizedBox(width: 6),
              Text(
                "زملاء الحلقة (الدورة الحالية)",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : primaryColor,
                ),
              ),
            ],
          ),
        ),
        _buildFastCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          borderRadius: 20,
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  size: 19,
                  color: isDark
                      ? Colors.white54
                      : primaryColor.withOpacity(0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _peerSearchController,
                  onChanged: (v) => setState(() => _peerSearchQuery = v.trim()),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "ابحث عن زميل في حلقتك الحالية...",
                    hintStyle: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_peerSearchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _peerSearchController.clear();
                    setState(() => _peerSearchQuery = '');
                  },
                  child: Icon(Icons.close_rounded,
                      size: 17,
                      color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.supervisorId.isEmpty || _peersStream == null)
          _buildFastCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                "لم يتم ربط الطالب بحلقة مشرف بعد لعرض الزملاء.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
          )
        else
          StreamBuilder<QuerySnapshot>(
            stream: _peersStream,
            builder: (context, studentsSnap) {
              if (studentsSnap.connectionState == ConnectionState.waiting &&
                  !studentsSnap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final allDocs = studentsSnap.data?.docs ?? [];
              final peers = allDocs.where((doc) {
                if (doc.id == widget.studentId) return false;
                final data = doc.data() as Map<String, dynamic>;
                if (data['archived'] == true || data['isDeleted'] == true) {
                  return false;
                }
                if (!_belongsToActiveCycle(
                    data, activeCycleId, activeCycleName)) {
                  return false;
                }
                final name = (data['name'] ?? '').toString();
                if (_peerSearchQuery.isNotEmpty &&
                    !name
                        .toLowerCase()
                        .contains(_peerSearchQuery.toLowerCase())) {
                  return false;
                }
                return true;
              }).toList();

              if (peers.isEmpty) {
                return _buildFastCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 44,
                        color: isDark
                            ? Colors.white30
                            : primaryColor.withOpacity(0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _peerSearchQuery.isNotEmpty
                            ? "لا يوجد زميل مطابق لبحثك في الدورة الحالية"
                            : "لا يوجد زملاء آخرون مسجلون معك في الدورة الحالية",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: peers.map((peerDoc) {
                  final pData = peerDoc.data() as Map<String, dynamic>;
                  final peerId = peerDoc.id;
                  final peerName =
                      (pData['name'] ?? 'طالب في الحلقة').toString();
                  final peerImg = _extractImageUrl(pData);
                  final peerChatId = _buildPeerChatId(peerId);

                  return _PeerConversationTile(
                    key: ValueKey(peerChatId),
                    peerId: peerId,
                    peerName: peerName,
                    peerImg: peerImg,
                    peerChatId: peerChatId,
                    currentStudentId: widget.studentId,
                    supervisorName: widget.supervisorName,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    accentGold: accentGold,
                    formatTime: _formatListTime,
                    avatarFallback: _buildAvatarFallback(peerName, false),
                    fastCard: _buildFastCard,
                    onTap: () {
                      setState(() {
                        _activeTarget = _ChatTarget(
                          chatId: peerChatId,
                          targetId: peerId,
                          targetName: peerName,
                          targetSubtitle:
                              'زميل في حلقة ${widget.supervisorName}',
                          avatarUrl: peerImg,
                          isSupervisor: false,
                        );
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAvatarFallback(String name, bool isGold) {
    return Container(
      color: isGold
          ? accentGold.withOpacity(0.2)
          : primaryColor.withOpacity(0.14),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.characters.first : '؟',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: widget.isDarkMode ? accentGold : primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFastCard({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double borderRadius = 24,
    Color? borderColor,
    List<Color>? gradientColors,
  }) {
    final bool isDark = widget.isDarkMode;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors ??
              (isDark
                  ? [
                      const Color(0xff182438).withOpacity(0.86),
                      const Color(0xff111927).withOpacity(0.82),
                    ]
                  : [
                      Colors.white.withOpacity(0.88),
                      Colors.white.withOpacity(0.74),
                    ]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (isDark
                  ? Colors.white.withOpacity(0.14)
                  : Colors.white.withOpacity(0.85)),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}

class _PeerConversationTile extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerImg;
  final String peerChatId;
  final String currentStudentId;
  final String supervisorName;
  final bool isDark;
  final Color primaryColor;
  final Color accentGold;
  final String Function(Timestamp?) formatTime;
  final Widget avatarFallback;
  final Widget Function({
    required Widget child,
    EdgeInsetsGeometry padding,
    double borderRadius,
    Color? borderColor,
    List<Color>? gradientColors,
  }) fastCard;
  final VoidCallback onTap;

  const _PeerConversationTile({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerImg,
    required this.peerChatId,
    required this.currentStudentId,
    required this.supervisorName,
    required this.isDark,
    required this.primaryColor,
    required this.accentGold,
    required this.formatTime,
    required this.avatarFallback,
    required this.fastCard,
    required this.onTap,
  });

  @override
  State<_PeerConversationTile> createState() => _PeerConversationTileState();
}

class _PeerConversationTileState extends State<_PeerConversationTile> {
  late final Stream<DocumentSnapshot> _chatStream;

  @override
  void initState() {
    super.initState();
    _chatStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.peerChatId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatStream,
      builder: (context, chatSnap) {
        String lastMsg = 'زميلك في الدورة الحالية • اضغط للمراسلة';
        String timeStr = '';
        int unread = 0;

        if (chatSnap.hasData && chatSnap.data!.exists) {
          final cData = chatSnap.data!.data() as Map<String, dynamic>;
          if ((cData['lastMessage']?.toString() ?? '').isNotEmpty) {
            lastMsg = cData['lastMessage'].toString();
          }
          timeStr = widget.formatTime(cData['lastMessageTime'] as Timestamp?);
          final unreadKey = 'unreadBy_${widget.currentStudentId}';
          unread =
              (cData[unreadKey] is num) ? (cData[unreadKey] as num).toInt() : 0;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: widget.onTap,
            child: widget.fastCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderRadius: 22,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white24
                            : widget.primaryColor.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: widget.peerImg.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.peerImg,
                              fit: BoxFit.cover,
                              memCacheWidth: 110,
                              errorWidget: (_, __, ___) =>
                                  widget.avatarFallback,
                            )
                          : widget.avatarFallback,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.peerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13.8,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isDark
                                      ? Colors.white
                                      : widget.primaryColor,
                                ),
                              ),
                            ),
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: unread > 0
                                      ? widget.accentGold
                                      : (widget.isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMsg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11.5,
                                  fontWeight: unread > 0
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: unread > 0
                                      ? (widget.isDark
                                          ? Colors.white
                                          : Colors.black87)
                                      : (widget.isDark
                                          ? Colors.white60
                                          : Colors.grey.shade600),
                                ),
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: widget.accentGold, width: 1),
                                ),
                                child: Text(
                                  '$unread',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: widget.accentGold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatTarget {
  final String chatId;
  final String targetId;
  final String targetName;
  final String targetSubtitle;
  final String avatarUrl;
  final bool isSupervisor;

  const _ChatTarget({
    required this.chatId,
    required this.targetId,
    required this.targetName,
    required this.targetSubtitle,
    required this.avatarUrl,
    required this.isSupervisor,
  });
}

class _LiquidConversationView extends StatefulWidget {
  final String currentStudentId;
  final String currentStudentName;
  final _ChatTarget target;
  final bool isDarkMode;
  final VoidCallback onBack;

  const _LiquidConversationView({
    super.key,
    required this.currentStudentId,
    required this.currentStudentName,
    required this.target,
    required this.isDarkMode,
    required this.onBack,
  });

  @override
  State<_LiquidConversationView> createState() =>
      _LiquidConversationViewState();
}

class _LiquidConversationViewState extends State<_LiquidConversationView> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final Color primaryColor = const Color(0xff425c75);
  final Color accentGold = const Color(0xffcdb375);

  final String cloudName = 'dqsrrej2b';
  final String uploadPreset = 'rhjrrtqz';

  late final rec.AudioRecorder _audioRecorder;
  final ImagePicker _imagePicker = ImagePicker();

  late final Stream<DocumentSnapshot> _chatDocStream;
  late final Stream<QuerySnapshot> _messagesStream;

  bool _isUploading = false;
  String _uploadStatusText = '';
  String _activeFilter = 'all';
  Map<String, dynamic>? _replyingTo;
  bool _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = rec.AudioRecorder();
    _chatDocStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.target.chatId)
        .snapshots();
    _messagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.target.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(80)
        .snapshots();

    _scrollController.addListener(_onScroll);
    _clearUnread();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _audioRecorder.dispose();
    _messageController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _keepInputFocused() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_inputFocusNode.hasFocus) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.position.pixels > 220;
    if (show != _showScrollDown && mounted) {
      setState(() => _showScrollDown = show);
    }
  }

  void _clearUnread() {
    final Map<String, dynamic> resetData = widget.target.isSupervisor
        ? {'unreadByParent': 0}
        : {'unreadBy_${widget.currentStudentId}': 0};

    FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.target.chatId)
        .set(resetData, SetOptions(merge: true))
        .catchError((_) {});
  }

  bool _isSentByMe(Map<String, dynamic> msg) {
    final senderId = msg['senderId']?.toString() ?? '';
    if (senderId == widget.currentStudentId) return true;
    if (widget.target.isSupervisor) {
      final senderType = msg['senderType']?.toString().toLowerCase() ?? '';
      return senderType == 'parent' || senderType == 'student';
    }
    return false;
  }

  String _detectMessageType(Map<String, dynamic> msg) {
    final t = msg['type']?.toString().toLowerCase() ?? '';
    if (t == 'image' || t == 'audio') return t;
    if ((msg['imageUrl']?.toString() ?? '').isNotEmpty) return 'image';
    if ((msg['audioUrl']?.toString() ?? '').isNotEmpty) return 'audio';
    return 'text';
  }

  DateTime? _extractDateTime(Map<String, dynamic> msg) {
    final raw = msg['timestamp'] ?? msg['createdAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'م' : 'ص';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }

  String _formatDayHeader(DateTime? dt) {
    if (dt == null) return 'اليوم';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) return 'اليوم';
    if (target == yesterday) return 'أمس';
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatRecordTimer(int seconds) {
    final int mins = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
      );
      if (picked == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatusText = 'جاري رفع الصورة... 🖼️';
      });

      final bytes = await picked.readAsBytes();
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: picked.name),
        );

      final response = await request.send();
      final resBytes = await response.stream.toBytes();
      final jsonMap = jsonDecode(String.fromCharCodes(resBytes));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        await _sendMediaMessage(
          type: 'image',
          imageUrl: jsonMap['secure_url'].toString(),
        );
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل رفع الصورة');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تعذر إرسال الصورة: $e",
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        _keepInputFocused();
      }
    }
  }

  Future<void> _uploadAndSendAudio(String? path, int durationSeconds) async {
    if (path == null || path.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'جاري إرسال الرسالة الصوتية... 🎙️';
    });

    try {
      Uint8List? audioBytes;
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (kIsWeb) {
        final res = await http.get(Uri.parse(path));
        audioBytes = res.bodyBytes;
      } else {
        final file = File(path);
        if (await file.exists()) {
          audioBytes = await file.readAsBytes();
        }
      }

      if (audioBytes == null || audioBytes.isEmpty) return;

      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes('file', audioBytes, filename: fileName),
        );

      final response = await request.send();
      final resBytes = await response.stream.toBytes();
      final jsonMap = jsonDecode(String.fromCharCodes(resBytes));

      if (response.statusCode == 200 && jsonMap['secure_url'] != null) {
        await _sendMediaMessage(
          type: 'audio',
          audioUrl: jsonMap['secure_url'].toString(),
          duration: durationSeconds > 0 ? durationSeconds : 1,
        );
      } else {
        throw Exception(jsonMap['error']?['message'] ?? 'فشل رفع الصوت');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تعذر إرسال التسجيل الصوتي",
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        _keepInputFocused();
      }
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyPayload = _replyingTo;
    setState(() => _replyingTo = null);
    _messageController.clear();
    _keepInputFocused();
    _scrollToBottom();

    final Map<String, dynamic> msgData = {
      'senderId': widget.currentStudentId,
      'senderName': widget.currentStudentName,
      'senderType': widget.target.isSupervisor ? 'parent' : 'student',
      'type': 'text',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };
    if (replyPayload != null) msgData['replyTo'] = replyPayload;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.target.chatId)
        .collection('messages')
        .add(msgData);

    await _updateChatSummaryAndNotify(text);
    _keepInputFocused();
  }

  Future<void> _sendMediaMessage({
    required String type,
    String? imageUrl,
    String? audioUrl,
    int? duration,
  }) async {
    final replyPayload = _replyingTo;
    setState(() => _replyingTo = null);
    _scrollToBottom();

    final Map<String, dynamic> msgData = {
      'senderId': widget.currentStudentId,
      'senderName': widget.currentStudentName,
      'senderType': widget.target.isSupervisor ? 'parent' : 'student',
      'type': type,
      'text': '',
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {},
    };
    if (replyPayload != null) msgData['replyTo'] = replyPayload;

    if (type == 'image') {
      msgData['imageUrl'] = imageUrl;
    } else if (type == 'audio') {
      msgData['audioUrl'] = audioUrl;
      msgData['duration'] = duration ?? 1;
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.target.chatId)
        .collection('messages')
        .add(msgData);

    final preview = type == 'audio'
        ? '🎙️ تسجيل صوتي (${_formatRecordTimer(duration ?? 0)})'
        : '📷 صورة';
    await _updateChatSummaryAndNotify(preview);
  }

  Future<void> _updateChatSummaryAndNotify(String preview) async {
    if (widget.target.isSupervisor) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.target.chatId)
          .set({
        'studentId': widget.currentStudentId,
        'studentName': widget.currentStudentName,
        'supervisorId': widget.target.targetId,
        'supervisorName': widget.target.targetName,
        'lastMessage': preview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderType': 'parent',
        'lastSenderId': widget.currentStudentId,
        'unreadBySupervisor': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (mounted) {
        await NotificationService.sendAndSaveNotification(
          studentId: widget.target.targetId,
          title: "💬 رسالة من (${widget.currentStudentName})",
          body: preview,
          type: "chat",
          context: context,
        );
      }
    } else {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.target.chatId)
          .set({
        'chatType': 'peer',
        'participants': [widget.currentStudentId, widget.target.targetId],
        'lastMessage': preview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': widget.currentStudentId,
        'lastSenderName': widget.currentStudentName,
        'unreadBy_${widget.target.targetId}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (mounted) {
        await NotificationService.sendAndSaveNotification(
          studentId: widget.target.targetId,
          title: "💬 رسالة من زميلك ${widget.currentStudentName}",
          body: preview,
          type: "chat",
          context: context,
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showAttachmentSheet() {
    final bool isDark = widget.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "إرسال صورة",
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: isDark ? Colors.white : primaryColor,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachOption(
                    icon: Icons.photo_library_rounded,
                    label: "معرض الصور",
                    color: primaryColor,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.camera_alt_rounded,
                    label: "التقاط صورة",
                    color: accentGold,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isDark = widget.isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(icon,
                color: isDark && color == primaryColor ? accentGold : color,
                size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: isDark ? Colors.white : primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        CircularProgressIndicator(color: accentGold),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white,
                        size: 48),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageActions({
    required String messageId,
    required String msgType,
    required String messageText,
    required bool isMe,
  }) {
    HapticFeedback.mediumImpact();
    final bool isDark = widget.isDarkMode;
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    final preview = msgType == 'image'
        ? '📷 صورة'
        : (msgType == 'audio' ? '🎙️ تسجيل صوتي' : messageText);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff1e293b) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.target.chatId)
                          .collection('messages')
                          .doc(messageId)
                          .set({
                        'reactions': {widget.currentStudentId: emoji}
                      }, SetOptions(merge: true));
                      Navigator.pop(sheetCtx);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.08),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 20),
              ListTile(
                dense: true,
                leading: Icon(Icons.reply_rounded,
                    color: isDark ? accentGold : primaryColor),
                title: Text(
                  "رد على الرسالة",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() {
                    _replyingTo = {
                      'id': messageId,
                      'senderName': isMe ? 'أنت' : widget.target.targetName,
                      'text': preview,
                    };
                  });
                  _inputFocusNode.requestFocus();
                },
              ),
              if (msgType == 'text' && messageText.isNotEmpty)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.copy_rounded,
                      color: isDark ? Colors.white70 : primaryColor),
                  title: Text(
                    "نسخ النص",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Clipboard.setData(ClipboardData(text: messageText));
                  },
                ),
              if (isMe)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: const Text(
                    "حذف الرسالة",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.target.chatId)
                        .collection('messages')
                        .doc(messageId)
                        .delete();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xff182438).withOpacity(0.88)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: widget.target.isSupervisor
                        ? accentGold.withOpacity(0.72)
                        : (isDark
                            ? Colors.white.withOpacity(0.16)
                            : Colors.white.withOpacity(0.9)),
                    width: 1.3,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: accentGold.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: accentGold.withOpacity(0.35)),
                      ),
                      child: IconButton(
                        onPressed: widget.onBack,
                        tooltip: "رجوع للمحادثات",
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: isDark ? accentGold : primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.target.isSupervisor
                              ? accentGold
                              : primaryColor.withOpacity(0.35),
                          width: 1.8,
                        ),
                      ),
                      child: ClipOval(
                        child: widget.target.avatarUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.target.avatarUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 110,
                                errorWidget: (_, __, ___) =>
                                    _buildHeaderFallback(),
                              )
                            : _buildHeaderFallback(),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.target.targetName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : primaryColor,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Icon(
                                widget.target.isSupervisor
                                    ? Icons.verified_user_rounded
                                    : Icons.school_rounded,
                                size: 12.5,
                                color: accentGold,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.target.targetSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? accentGold
                                        : primaryColor.withOpacity(0.85),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              _buildFilterChip('all', 'الكل', Icons.forum_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('image', 'الصور', Icons.image_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('audio', 'الصوتيات', Icons.graphic_eq_rounded),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Stack(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: _chatDocStream,
                builder: (context, chatSnap) {
                  bool isReadByOther = false;
                  if (chatSnap.hasData && chatSnap.data!.exists) {
                    final cData =
                        chatSnap.data!.data() as Map<String, dynamic>;
                    isReadByOther = widget.target.isSupervisor
                        ? (cData['unreadBySupervisor'] ?? 0) == 0
                        : (cData['unreadBy_${widget.target.targetId}'] ?? 0) ==
                            0;
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
                    builder: (context, msgSnap) {
                      if (msgSnap.connectionState == ConnectionState.waiting &&
                          !msgSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final rawDocs = msgSnap.data?.docs ?? [];
                      final filtered = rawDocs.where((doc) {
                        final map = doc.data() as Map<String, dynamic>;
                        final type = _detectMessageType(map);
                        if (_activeFilter == 'image' && type != 'image') {
                          return false;
                        }
                        if (_activeFilter == 'audio' && type != 'audio') {
                          return false;
                        }
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 28),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xff182438)
                                      .withOpacity(0.85)
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: accentGold.withOpacity(0.4)),
                            ),
                            child: Text(
                              _activeFilter != 'all'
                                  ? "لا توجد رسائل ضمن هذا الفلتر"
                                  : "ابدأ المحادثة الآن برسالة نصية أو صوتية أو صورة!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : primaryColor,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final msg = doc.data() as Map<String, dynamic>;
                          final docId = doc.id;
                          final isMe = _isSentByMe(msg);
                          final dt = _extractDateTime(msg);
                          final timeString = _formatTime(dt);
                          final msgType = _detectMessageType(msg);
                          final messageText =
                              (msg['text'] ?? msg['message'] ?? '').toString();
                          final Map<String, dynamic>? replyTo =
                              msg['replyTo'] is Map
                                  ? Map<String, dynamic>.from(msg['replyTo'])
                                  : null;

                          final olderDoc = (index + 1 < filtered.length)
                              ? filtered[index + 1]
                              : null;
                          final olderDt = olderDoc != null
                              ? _extractDateTime(
                                  olderDoc.data() as Map<String, dynamic>)
                              : null;
                          final bool showDateDivider = dt != null &&
                              (olderDt == null || !_isSameDay(dt, olderDt));

                          final Map<String, dynamic> reactions =
                              msg['reactions'] is Map
                                  ? Map<String, dynamic>.from(msg['reactions'])
                                  : {};
                          final List<String> displayEmojis = reactions.values
                              .map((e) => e.toString())
                              .toSet()
                              .toList();

                          return Column(
                            key: ValueKey(docId),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDateDivider)
                                Center(
                                  child: Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.white.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color:
                                            accentGold.withOpacity(0.45),
                                      ),
                                    ),
                                    child: Text(
                                      _formatDayHeader(dt),
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDark ? accentGold : primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: isMe
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: Container(
                                  margin: EdgeInsets.only(
                                    bottom: displayEmojis.isNotEmpty ? 16 : 9,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.78,
                                  ),
                                  child: GestureDetector(
                                    onLongPress: () => _showMessageActions(
                                      messageId: docId,
                                      msgType: msgType,
                                      messageText: messageText,
                                      isMe: isMe,
                                    ),
                                    child: Container(
                                      padding: msgType == 'image' &&
                                              replyTo == null
                                          ? const EdgeInsets.fromLTRB(6, 6, 6, 8)
                                          : const EdgeInsets.fromLTRB(
                                              15, 10, 15, 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(22),
                                          topRight: const Radius.circular(22),
                                          bottomLeft:
                                              Radius.circular(isMe ? 5 : 22),
                                          bottomRight:
                                              Radius.circular(isMe ? 22 : 5),
                                        ),
                                        color: isMe
                                            ? primaryColor
                                            : (isDark
                                                ? const Color(0xff1e293b)
                                                    .withOpacity(0.95)
                                                : Colors.white
                                                    .withOpacity(0.96)),
                                        border: Border.all(
                                          color: isMe
                                              ? accentGold.withOpacity(0.5)
                                              : (isDark
                                                  ? Colors.white
                                                      .withOpacity(0.14)
                                                  : accentGold
                                                      .withOpacity(0.25)),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          if (replyTo != null)
                                            _buildReplyPreview(replyTo, isMe),
                                          if (msgType == 'audio')
                                            _StudentAudioPlayer(
                                              audioUrl:
                                                  msg['audioUrl']?.toString() ??
                                                      '',
                                              duration: (msg['duration'] is num)
                                                  ? (msg['duration'] as num)
                                                      .toInt()
                                                  : 0,
                                              isMe: isMe,
                                              isDark: isDark,
                                              primaryColor: primaryColor,
                                              accentGold: accentGold,
                                            )
                                          else if (msgType == 'image')
                                            GestureDetector(
                                              onTap: () => _showImagePreview(
                                                  msg['imageUrl']?.toString() ??
                                                      ''),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: CachedNetworkImage(
                                                  imageUrl: msg['imageUrl']
                                                          ?.toString() ??
                                                      '',
                                                  width: 220,
                                                  height: 200,
                                                  fit: BoxFit.cover,
                                                  memCacheWidth: 440,
                                                  placeholder: (_, __) =>
                                                      Container(
                                                    width: 220,
                                                    height: 200,
                                                    color: Colors.black12,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: accentGold,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (_, __, ___) =>
                                                      const SizedBox(
                                                    width: 220,
                                                    height: 110,
                                                    child: Icon(
                                                        Icons
                                                            .broken_image_rounded,
                                                        color: Colors.redAccent),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              messageText,
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                color: isMe
                                                    ? Colors.white
                                                    : (isDark
                                                        ? Colors.white
                                                        : Colors.black87),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                height: 1.45,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (displayEmojis.isNotEmpty) ...[
                                                Text(displayEmojis.join(' '),
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                                const SizedBox(width: 6),
                                              ],
                                              Text(
                                                timeString,
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : (isDark
                                                          ? Colors.white54
                                                          : Colors.black45),
                                                ),
                                              ),
                                              if (isMe) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.done_all_rounded,
                                                  size: 14,
                                                  color: isReadByOther
                                                      ? accentGold
                                                      : Colors.white54,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
              if (_showScrollDown)
                Positioned(
                  bottom: 12,
                  left: 16,
                  child: GestureDetector(
                    onTap: _scrollToBottom,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: accentGold, width: 1.3),
                      ),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: accentGold, size: 24),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 8,
            bottom: isKeyboardOpen ? 12 : 104,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xff182438).withOpacity(0.92)
                      : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: accentGold.withOpacity(0.58),
                    width: 1.3,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingTo != null)
                      Container(
                        margin: const EdgeInsets.only(
                            bottom: 6, left: 4, right: 4, top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.07)
                              : primaryColor.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            right: BorderSide(color: accentGold, width: 3.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply_rounded,
                                size: 17,
                                color: isDark ? accentGold : primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "الرد على ${_replyingTo!['senderName']}",
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? accentGold : primaryColor,
                                    ),
                                  ),
                                  Text(
                                    _replyingTo!['text'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 11.5,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _replyingTo = null);
                                _keepInputFocused();
                              },
                              child: Icon(Icons.close_rounded,
                                  size: 17,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    if (_isUploading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: accentGold),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _uploadStatusText,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : primaryColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _StudentRecordingBar(
                        audioRecorder: _audioRecorder,
                        messageController: _messageController,
                        inputFocusNode: _inputFocusNode,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        accentGold: accentGold,
                        onSendText: _sendTextMessage,
                        onSendAudio: _uploadAndSendAudio,
                        onOpenAttach: _showAttachmentSheet,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderFallback() {
    return Container(
      color: primaryColor.withOpacity(0.16),
      child: Center(
        child: Text(
          widget.target.targetName.isNotEmpty
              ? widget.target.targetName.characters.first
              : '؟',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: widget.isDarkMode ? accentGold : primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final bool isDark = widget.isDarkMode;
    final bool selected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor
              : (isDark
                  ? Colors.white.withOpacity(0.09)
                  : Colors.white.withOpacity(0.85)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accentGold : accentGold.withOpacity(0.35),
            width: selected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13.5,
                color: selected
                    ? accentGold
                    : (isDark ? Colors.white70 : primaryColor)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(Map<String, dynamic> replyTo, bool isMe) {
    final bool isDark = widget.isDarkMode;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withOpacity(0.22)
            : (isDark
                ? Colors.white.withOpacity(0.07)
                : primaryColor.withOpacity(0.07)),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          right: BorderSide(color: isMe ? accentGold : primaryColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo['senderName']?.toString() ?? 'رسالة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isMe ? accentGold : (isDark ? accentGold : primaryColor),
            ),
          ),
          Text(
            replyTo['text']?.toString() ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11.5,
              color: isMe
                  ? Colors.white.withOpacity(0.88)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRecordingBar extends StatefulWidget {
  final rec.AudioRecorder audioRecorder;
  final TextEditingController messageController;
  final FocusNode inputFocusNode;
  final bool isDark;
  final Color primaryColor;
  final Color accentGold;
  final VoidCallback onSendText;
  final Function(String? path, int durationSeconds) onSendAudio;
  final VoidCallback onOpenAttach;

  const _StudentRecordingBar({
    required this.audioRecorder,
    required this.messageController,
    required this.inputFocusNode,
    required this.isDark,
    required this.primaryColor,
    required this.accentGold,
    required this.onSendText,
    required this.onSendAudio,
    required this.onOpenAttach,
  });

  @override
  State<_StudentRecordingBar> createState() => _StudentRecordingBarState();
}

class _StudentRecordingBarState extends State<_StudentRecordingBar>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  async.Timer? _timer;
  int _seconds = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await widget.audioRecorder.hasPermission()) {
        rec.RecordConfig config;
        String savePath = '';

        if (kIsWeb) {
          config = const rec.RecordConfig(encoder: rec.AudioEncoder.opus);
        } else {
          config = const rec.RecordConfig(
              encoder: rec.AudioEncoder.aacLc, bitRate: 128000);
          final dir = await getTemporaryDirectory();
          savePath =
              '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await widget.audioRecorder.start(config, path: savePath);
        HapticFeedback.mediumImpact();

        _seconds = 0;
        _timer?.cancel();
        _timer = async.Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });

        _pulseController.repeat(reverse: true);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("خطأ بدء التسجيل: $e");
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    _pulseController.stop();
    final finalDur = _seconds;
    try {
      final path = await widget.audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _seconds = 0;
      });
      widget.onSendAudio(path, finalDur);
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _pulseController.stop();
    await widget.audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _seconds = 0;
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_isRecording) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 23),
            onPressed: _cancelRecording,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.25).animate(_pulseController),
                  child: const Icon(Icons.fiber_manual_record_rounded,
                      color: Colors.redAccent, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmt(_seconds),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "جاري التسجيل...",
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color:
                        widget.isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _stopAndSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: widget.accentGold, width: 1.3),
              ),
              child:
                  Icon(Icons.send_rounded, color: widget.accentGold, size: 20),
            ),
          ),
        ],
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.messageController,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: widget.messageController,
                focusNode: widget.inputFocusNode,
                autofocus: false,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  widget.onSendText();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) widget.inputFocusNode.requestFocus();
                  });
                },
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: "اكتب رسالتك هنا...",
                  hintStyle: TextStyle(
                    fontFamily: 'Cairo',
                    color:
                        widget.isDark ? Colors.white54 : Colors.grey.shade500,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (!hasText)
              IconButton(
                tooltip: "إرسال صورة",
                icon: Icon(
                  Icons.camera_alt_outlined,
                  color: widget.isDark
                      ? Colors.white60
                      : widget.primaryColor.withOpacity(0.82),
                  size: 22,
                ),
                onPressed: widget.onOpenAttach,
              ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                if (hasText) {
                  widget.onSendText();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) widget.inputFocusNode.requestFocus();
                  });
                } else {
                  _startRecording();
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasText
                        ? [const Color(0xffb5964e), widget.accentGold]
                        : [widget.primaryColor, const Color(0xff2f4459)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: widget.accentGold.withOpacity(0.8),
                      width: 1.3),
                ),
                child: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: hasText ? Colors.white : widget.accentGold,
                  size: 20,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudentAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;
  final bool isDark;
  final Color primaryColor;
  final Color accentGold;

  const _StudentAudioPlayer({
    required this.audioUrl,
    required this.duration,
    required this.isMe,
    required this.isDark,
    required this.primaryColor,
    required this.accentGold,
  });

  @override
  State<_StudentAudioPlayer> createState() => _StudentAudioPlayerState();
}

class _StudentAudioPlayerState extends State<_StudentAudioPlayer> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _total = Duration(seconds: widget.duration);

    if (!kIsWeb) {
      _player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ));
    }

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else if (widget.audioUrl.isNotEmpty) {
        await _player.stop();
        await _player.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      debugPrint("خطأ تشغيل الصوت: $e");
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final activeBar = widget.isMe ? widget.accentGold : widget.primaryColor;
    final inactiveBar = widget.isMe
        ? Colors.white.withOpacity(0.32)
        : (widget.isDark ? Colors.white24 : Colors.grey.shade400);

    return SizedBox(
      width: 205,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: CircleAvatar(
              radius: 17,
              backgroundColor:
                  widget.isMe ? widget.accentGold : widget.primaryColor,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 20,
                color: widget.isMe ? widget.primaryColor : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(20, (index) {
                    final double h = 5 + ((index * 7) % 14).toDouble();
                    final double progress = _total.inSeconds > 0
                        ? (_position.inSeconds / _total.inSeconds)
                        : 0.0;
                    final bool active = (index / 20) <= progress;
                    return Expanded(
                      child: Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: active ? activeBar : inactiveBar,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(_isPlaying ? _position : _total),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.85)
                        : (widget.isDark
                            ? Colors.white60
                            : Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}