import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class PanicInterruptScreen extends StatefulWidget {
  const PanicInterruptScreen({super.key});

  @override
  State<PanicInterruptScreen> createState() => _PanicInterruptScreenState();
}

class _PanicInterruptScreenState extends State<PanicInterruptScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  String _victimUid = "";
  String _victimName = "Someone";
  String _victimAddress = "Loading address...";

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _loadPanicDetails();
    _startAlertFeedback();
  }

  Future<void> _loadPanicDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _victimUid = prefs.getString('active_panic_uid') ?? "";
      final first = prefs.getString('active_panic_first_name') ?? "";
      final last = prefs.getString('active_panic_last_name') ?? "";
      _victimName = "$first $last".trim();
      if (_victimName.isEmpty) _victimName = "A SafeTrace User";
      _victimAddress = prefs.getString('active_panic_address') ?? "Location Unknown";
    });
  }

  Future<void> _startAlertFeedback() async {
    try {
      await SafeTraceRingtonePlayer.playRingtone();
    } catch (_) {}

    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (canVibrate) {
        Vibration.vibrate(pattern: [0, 1000, 500], repeat: 0);
      }
    } catch (_) {}
  }

  Future<void> _stopAlertFeedback() async {
    try {
      await SafeTraceRingtonePlayer.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  Future<void> _clearSavedPanic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_panic_uid');
  }

  Future<void> _handleViewLocation() async {
    await _stopAlertFeedback();
    await _clearSavedPanic();
    if (mounted) {
      context.pop(); // Pop interrupt overlay
      if (_victimUid.isNotEmpty) {
        context.push('/panic-map/$_victimUid');
      }
    }
  }

  Future<void> _handleDecline() async {
    await _stopAlertFeedback();
    await _clearSavedPanic();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _victimUid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('active_panics').doc(_victimUid).update({
          'declined_by': FieldValue.arrayUnion([currentUser.uid]),
        });
      } catch (e) {
        debugPrint("Failed to log decline in Firestore: $e");
      }
    }
    
    if (mounted) {
      context.pop(); // Pop interrupt overlay
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopAlertFeedback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD32F2F), // Bright emergency red
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final double glowScale = 1.0 + (_pulseController.value * 0.05);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing Background Rings
                Center(
                  child: Container(
                    width: 250 * glowScale,
                    height: 250 * glowScale,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 180 * glowScale,
                    height: 180 * glowScale,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header Section
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            "EMERGENCY ALERT",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            _victimName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "has triggered a panic alert",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      // Central Location Section
                      Column(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 64 * glowScale,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              _victimAddress,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Action Buttons Section
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFD32F2F),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              onPressed: _handleViewLocation,
                              child: const Text(
                                "View Location on Map",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white60, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _handleDecline,
                              child: const Text(
                                "Stop Alert",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
