import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/sms_service.dart';
import '../../location/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';

class PanicAlertScreen extends ConsumerStatefulWidget {
  const PanicAlertScreen({super.key});

  @override
  ConsumerState<PanicAlertScreen> createState() => _PanicAlertScreenState();
}

class _PanicAlertScreenState extends ConsumerState<PanicAlertScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _cancelHoldController;
  late AnimationController _staggerController;

  bool _isHoldingCancel = false;
  bool _liveLocationActive = true;

  // Active status blinker
  bool _blinkStatus = true;
  Timer? _blinkTimer;

  // Active panic location stream timer
  Timer? _locationUpdateTimer;
  String _resolvedAddress = "Resolving location...";
  bool _initialized = false;

  // SMS status state per contact (phone number -> SmsSendResult)
  final Map<String, SmsSendResult> _smsDeliveryResults = {};
  final List<Map<String, String>> _trustedContactsList = [];
  String _panicMessage = "";
  bool _isSendingSms = false;

  @override
  void initState() {
    super.initState();

    // 1. Repeating warning circle pulse (scale + glow)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 2. Cancel hold button controller (5 seconds hold to cancel)
    _cancelHoldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _cancelHoldController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cancelPanic();
      }
    });

    // 3. Staggered contact entrance/checkmark pop animation
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _staggerController.forward();

    // Blinking timer for the active pill
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      setState(() {
        _blinkStatus = !_blinkStatus;
      });
    });

    // 4. Initialize active panic document and location updates
    _initPanicAlert();
  }

  Future<void> _initPanicAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    double lat = 0.0;
    double lng = 0.0;

    final pos = await SmsService.getBestAvailablePosition();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
    }

    final authState = ref.read(authNotifierProvider);
    final firstName = authState.firstName.isNotEmpty ? authState.firstName : "User";
    final lastName = authState.lastName.isNotEmpty ? authState.lastName : "";

    final message = await SmsService.buildPanicMessage(
      firstName: firstName,
      lastName: lastName,
      lat: lat,
      lng: lng,
    );
    _panicMessage = message;

    String address = "Resolving Location...";
    try {
      final resolved = await LocationService.reverseGeocode(lat, lng);
      if (resolved.isNotEmpty) {
        address = resolved;
      }
    } catch (e) {
      debugPrint("Failed to geocode address: $e");
    }

    if (mounted) {
      setState(() {
        _resolvedAddress = address;
      });
    }

    final List<String> notifiedUids = [];
    final List<String> trustedPhones = [];

    try {
      final reqSnap = await FirebaseFirestore.instance
          .collection('trusted_circle_requests')
          .where('status', whereIn: ['accepted', 'pending_deletion'])
          .get();

      for (final doc in reqSnap.docs) {
        final data = doc.data();
        final reqUid = (data['requester_uid'] ?? '').toString();
        final recUid = (data['recipient_uid'] ?? '').toString();

        if (reqUid == user.uid && recUid.isNotEmpty) {
          final phone = (data['recipient_phone'] ?? '').toString().trim();
          final name = "${data['recipient_first_name'] ?? ''} ${data['recipient_last_name'] ?? ''}".trim();
          if (!notifiedUids.contains(recUid)) notifiedUids.add(recUid);
          if (phone.isNotEmpty && !trustedPhones.contains(phone)) trustedPhones.add(phone);
          _trustedContactsList.add({
            'uid': recUid,
            'phone': phone,
            'name': name.isEmpty ? "Contact" : name,
          });
        } else if (recUid == user.uid && reqUid.isNotEmpty) {
          final phone = (data['requester_phone'] ?? '').toString().trim();
          final name = "${data['requester_first_name'] ?? ''} ${data['requester_last_name'] ?? ''}".trim();
          if (!notifiedUids.contains(reqUid)) notifiedUids.add(reqUid);
          if (phone.isNotEmpty && !trustedPhones.contains(phone)) trustedPhones.add(phone);
          _trustedContactsList.add({
            'uid': reqUid,
            'phone': phone,
            'name': name.isEmpty ? "Contact" : name,
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to query trusted_circle_requests in panic alert: $e");
    }

    // Check SMS Permission
    bool hasSmsPermission = true;
    if (Platform.isAndroid) {
      hasSmsPermission = await Permission.sms.isGranted;
    }

    if (trustedPhones.isNotEmpty) {
      setState(() {
        _isSendingSms = true;
      });

      if (hasSmsPermission) {
        final smsResults = await SmsService.sendPanicSms(
          phoneNumbers: trustedPhones,
          message: message,
        );
        setState(() {
          _smsDeliveryResults.addAll(smsResults);
          _isSendingSms = false;
        });
      } else {
        setState(() {
          for (final phone in trustedPhones) {
            _smsDeliveryResults[phone] = SmsSendResult.skippedPermissionDenied;
          }
          _isSendingSms = false;
        });
      }
    }

    // Write panic_events document with sms_delivery_results map
    try {
      final Map<String, String> smsFirestoreMap = {};
      for (final c in _trustedContactsList) {
        final uid = c['uid']!;
        final phone = c['phone']!;
        final res = _smsDeliveryResults[phone];
        if (res == SmsSendResult.sent) {
          smsFirestoreMap[uid] = "sent";
        } else if (res == SmsSendResult.skippedPermissionDenied) {
          smsFirestoreMap[uid] = "skipped";
        } else {
          smsFirestoreMap[uid] = "failed";
        }
      }

      await FirebaseFirestore.instance.collection('panic_events').add({
        'uid': user.uid,
        'first_name': firstName,
        'last_name': lastName,
        'lat': lat,
        'lng': lng,
        'address': address,
        'triggered_at': FieldValue.serverTimestamp(),
        'sms_delivery_results': smsFirestoreMap,
      });
    } catch (e) {
      debugPrint("Failed to log panic_events document: $e");
    }

    // Set active_panics document
    await FirebaseFirestore.instance.collection('active_panics').doc(user.uid).set({
      'uid': user.uid,
      'first_name': firstName,
      'last_name': lastName,
      'lat': lat,
      'lng': lng,
      'address': address,
      'triggered_at': FieldValue.serverTimestamp(),
      'is_active': true,
      'notified_contacts': notifiedUids,
      'trusted_phones': trustedPhones,
      'declined_by': [],
    });

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_liveLocationActive) return;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        
        await FirebaseFirestore.instance.collection('active_panics').doc(user.uid).update({
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
      } catch (e) {
        debugPrint("Failed to update active panic location: $e");
      }
    });

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  Future<void> _retrySmsForContact(Map<String, String> contact) async {
    final phone = contact['phone']!;
    if (phone.isEmpty) return;

    setState(() {
      _smsDeliveryResults[phone] = SmsSendResult.error;
    });

    final resMap = await SmsService.sendPanicSms(
      phoneNumbers: [phone],
      message: _panicMessage,
    );

    if (mounted) {
      setState(() {
        if (resMap.containsKey(phone)) {
          _smsDeliveryResults[phone] = resMap[phone]!;
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cancelHoldController.dispose();
    _staggerController.dispose();
    _blinkTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _onHoldStart() {
    setState(() {
      _isHoldingCancel = true;
    });
    _cancelHoldController.forward();
  }

  void _onHoldEnd() {
    if (_cancelHoldController.status != AnimationStatus.completed) {
      setState(() {
        _isHoldingCancel = false;
      });
      _cancelHoldController.reverse();
    }
  }

  void _cancelPanic() async {
    _cancelHoldController.reset();
    _locationUpdateTimer?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('active_panics').doc(user.uid).update({
          'is_active': false,
        });
      } catch (e) {
        debugPrint("Failed to deactivate active panic: $e");
      }
    }

    setState(() {
      _isHoldingCancel = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Panic alert resolved. Emergency contacts updated.")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF991B1B), // Dark coral red emergency
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              // Top Header Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _blinkStatus ? const Color(0xFFEF4444) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "PANIC MODE ACTIVE",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "LIVE GPS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Central Warning Exclamation Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing outer halo
                  Container(
                    width: 100 + (_pulseController.value * 20.0),
                    height: 100 + (_pulseController.value * 20.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12 * (1.0 - _pulseController.value)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Inner circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ALERT SENT Headings
              const Text(
                "ALERT SENT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _initialized
                      ? "Location: $_resolvedAddress"
                      : "Resolving location...",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Per-contact SMS Delivery Status Section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TRUSTED CONTACTS SMS STATUS",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_trustedContactsList.isEmpty) ...[
                        const Expanded(
                          child: Center(
                            child: Text(
                              "No trusted contacts added",
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ListView.separated(
                            itemCount: _trustedContactsList.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                            itemBuilder: (context, index) {
                              final contact = _trustedContactsList[index];
                              final firstName = (contact['name'] ?? 'Contact').split(' ').first;
                              final phone = contact['phone'] ?? '';
                              final result = _smsDeliveryResults[phone];

                              Widget statusWidget;
                              if (_isSendingSms && result == null) {
                                statusWidget = const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                );
                              } else if (result == SmsSendResult.sent) {
                                statusWidget = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      "SMS sent",
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                );
                              } else if (result == SmsSendResult.skippedPermissionDenied) {
                                statusWidget = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.block_rounded, color: Colors.grey, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      "SMS skipped — permission denied",
                                      style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                );
                              } else {
                                statusWidget = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Failed",
                                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _retrySmsForContact(contact),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 2),
                                            Text(
                                              "Retry",
                                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      firstName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    statusWidget,
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // Delivery Summary Banner
                        Builder(
                          builder: (context) {
                            if (_trustedContactsList.isEmpty) return const SizedBox.shrink();

                            final results = _smsDeliveryResults.values.toList();
                            if (results.isEmpty) return const SizedBox.shrink();

                            final allSent = results.every((r) => r == SmsSendResult.sent);
                            final allFailed = results.every((r) => r == SmsSendResult.error);
                            final allSkipped = results.every((r) => r == SmsSendResult.skippedPermissionDenied);

                            String summaryText;
                            Color summaryColor;

                            if (allSent) {
                              summaryText = "All alerts sent successfully";
                              summaryColor = const Color(0xFF10B981); // Green
                            } else if (allFailed) {
                              summaryText = "SMS delivery failed. Check your signal";
                              summaryColor = const Color(0xFFEF4444); // Red
                            } else if (allSkipped) {
                              summaryText = "SMS skipped — permission denied";
                              summaryColor = Colors.grey;
                            } else {
                              summaryText = "Partial delivery. See details above";
                              summaryColor = const Color(0xFFF59E0B); // Orange
                            }

                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: summaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: summaryColor.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: summaryColor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      summaryText,
                                      style: TextStyle(
                                        color: summaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actions Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    // Live Location Toggle Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.share, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Live Location Sharing",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Contacts track you in real-time",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _liveLocationActive,
                          activeColor: const Color(0xFF10B981),
                          activeTrackColor: const Color(0xFF10B981).withOpacity(0.3),
                          onChanged: (value) {
                            setState(() {
                              _liveLocationActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Hold to Cancel panic button
              GestureDetector(
                onLongPressStart: (_) => _onHoldStart(),
                onLongPressEnd: (_) => _onHoldEnd(),
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A1B1C), // Deep dark red warning cancel
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress bar indicator
                      if (_isHoldingCancel)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedBuilder(
                              animation: _cancelHoldController,
                              builder: (context, child) {
                                return FractionallySizedBox(
                                  widthFactor: _cancelHoldController.value,
                                  child: Container(
                                    color: Colors.white24,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      Text(
                        _isHoldingCancel
                            ? "HOLDING TO CANCEL..."
                            : "Hold 5s — False Alarm / Cancel",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
