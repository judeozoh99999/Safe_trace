import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class BatteryOptimizationService {
  static const String _batteryPrefKey = 'battery_optimisation_requested';
  static const String _autostartPrefKey = 'autostart_permission_requested';

  /// Checks and prompts for battery optimization exemption and manufacturer autostart
  /// on problem Android devices (Vivo, Infinix, Tecno, etc.).
  static Future<void> checkAndPromptPermissions(BuildContext context) async {
    if (!Platform.isAndroid || !context.mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check Battery Optimization Exemption
      final isBatteryIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
      final batteryPrompted = prefs.getBool(_batteryPrefKey) ?? false;

      if (!isBatteryIgnored && !batteryPrompted) {
        if (!context.mounted) return;
        final granted = await _showBatteryDialog(context);
        if (granted) {
          await prefs.setBool(_batteryPrefKey, true);
        }
      }

      // 2. Check Manufacturer-Specific Autostart
      final autostartPrompted = prefs.getBool(_autostartPrefKey) ?? false;
      if (!autostartPrompted) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer.toLowerCase();

        final isAggressiveRom = [
          'vivo',
          'infinix',
          'tecno',
          'itel',
          'oppo',
          'realme',
          'xiaomi',
          'transsion'
        ].any((brand) => manufacturer.contains(brand));

        if (isAggressiveRom && context.mounted) {
          await _showAutostartDialog(context, androidInfo.manufacturer);
          await prefs.setBool(_autostartPrefKey, true);
        }
      }
    } catch (e) {
      debugPrint("BatteryOptimizationService error: $e");
    }
  }

  static Future<bool> _showBatteryDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.battery_alert_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keep SafeTrace Active',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SafeTrace needs permission to run in the background to send emergency panic alerts and keep you safe.',
              style: TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              "Without this exemption, your device's battery saver may close the app, causing unexpected sign-outs or delayed distress alerts.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(true);
              await Permission.ignoreBatteryOptimizations.request();
            },
            child: const Text('Allow Background Activity'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  static Future<void> _showAutostartDialog(BuildContext context, String brand) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.settings_suggest_rounded, color: Color(0xFF4F46E5), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$brand Background Setup',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$brand devices require an additional permission for apps to stay alive in the background:',
              style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4),
            ),
            const SizedBox(height: 14),
            _buildStep('1', 'Open Settings on your device'),
            _buildStep('2', 'Go to App Management or Battery'),
            _buildStep('3', 'Find Autostart or Background Management'),
            _buildStep('4', 'Toggle ON for SafeTrace'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            child: const Text(
              'Open App Settings',
              style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  static Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFFEEF2FF),
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }
}
