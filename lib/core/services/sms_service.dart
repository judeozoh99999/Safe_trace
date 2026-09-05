import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

enum SmsSendResult { sent, error, skippedPermissionDenied }

class SmsService {
  static const MethodChannel _smsChannel = MethodChannel('com.safetrace.safetrace/sms');

  static Future<Position?> getBestAvailablePosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () async {
          final last = await Geolocator.getLastKnownPosition();
          return last ?? Position(
            longitude: 0.0,
            latitude: 0.0,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        },
      );
      return pos;
    } catch (e) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Future<String> buildPanicMessage({
    required String firstName,
    required String lastName,
    required double lat,
    required double lng,
  }) async {
    final fullName = "$firstName $lastName".trim();
    final name = fullName.isEmpty ? "A SafeTrace User" : fullName;

    if (lat != 0.0 && lng != 0.0) {
      String resolvedAddr = "";
      try {
        final placemarks = await placemarkFromCoordinates(lat, lng).timeout(
          const Duration(seconds: 5),
          onTimeout: () => [],
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final streetNumber = place.subThoroughfare ?? '';
          final streetName = place.thoroughfare ?? place.street ?? '';
          final street = "$streetNumber $streetName".trim();
          final area = place.subLocality?.isNotEmpty == true ? place.subLocality : place.locality;
          final city = place.locality;
          final state = place.administrativeArea;

          final parts = [street, area, city, state]
              .where((p) => p != null && p.isNotEmpty)
              .toSet()
              .join(", ");

          if (parts.isNotEmpty) {
            resolvedAddr = parts;
          }
        }
      } catch (e) {
        debugPrint("Error reverse geocoding placemark: $e");
      }

      if (resolvedAddr.isEmpty) {
        resolvedAddr = "$lat, $lng";
      }

      final mapsUrl = "https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}";

      return "EMERGENCY ALERT: $name needs immediate help and has triggered a panic alert on SafeTrace.\n"
          "Current location: $resolvedAddr.\n"
          "Open in Maps: $mapsUrl\n"
          "Sent via SafeTrace";
    } else {
      return "EMERGENCY ALERT: $name needs immediate help and has triggered a panic alert on SafeTrace.\n"
          "Location unavailable at this time\n"
          "Sent via SafeTrace";
    }
  }

  static Future<Map<String, SmsSendResult>> sendPanicSms({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    final Map<String, SmsSendResult> resultMap = {};

    if (phoneNumbers.isEmpty) return resultMap;

    debugPrint("Sending SMS message via native channel:\n$message");

    // Platform check for iOS fallback
    if (Platform.isIOS) {
      debugPrint("iOS detected — using sms url launcher fallback");
      try {
        final uri = Uri.parse("sms:${phoneNumbers.join(',')}?body=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          for (final phone in phoneNumbers) {
            resultMap[phone] = SmsSendResult.sent;
          }
        } else {
          for (final phone in phoneNumbers) {
            resultMap[phone] = SmsSendResult.error;
          }
        }
      } catch (e) {
        debugPrint("Error launching SMS on iOS: $e");
        for (final phone in phoneNumbers) {
          resultMap[phone] = SmsSendResult.error;
        }
      }
      return resultMap;
    }

    try {
      final List<Map<String, String>> recipients = phoneNumbers.map((phone) => {
        'phoneNumber': phone,
        'message': message,
      }).toList();

      final result = await _smsChannel.invokeMethod<Map>('sendSms', {
        'recipients': recipients,
      });

      if (result != null) {
        final sentList = List<String>.from(result['sent'] ?? []);
        final failedList = List<String>.from(result['failed'] ?? []);

        for (final phone in phoneNumbers) {
          if (sentList.contains(phone)) {
            resultMap[phone] = SmsSendResult.sent;
          } else if (failedList.contains(phone)) {
            resultMap[phone] = SmsSendResult.error;
          } else {
            resultMap[phone] = SmsSendResult.error;
          }
        }
      } else {
        for (final phone in phoneNumbers) {
          resultMap[phone] = SmsSendResult.error;
        }
      }
    } catch (e) {
      debugPrint("Native SMS platform channel error: $e");
      for (final phone in phoneNumbers) {
        resultMap[phone] = SmsSendResult.error;
      }
    }

    return resultMap;
  }

  /// Launches the device's native SMS application with pre-filled recipients and emergency body.
  /// Serves as a vital safety fallback if the OS restricts background SMS sending.
  static Future<bool> launchSmsAppFallback({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    if (phoneNumbers.isEmpty) return false;
    try {
      final separator = Platform.isAndroid ? ';' : ',';
      final recipients = phoneNumbers.join(separator);
      final uri = Uri.parse("sms:$recipients?body=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for primary contact if multi-recipient is not supported by device SMS intent
        final singleUri = Uri.parse("sms:${phoneNumbers.first}?body=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(singleUri)) {
          return await launchUrl(singleUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint("Error launching SMS fallback app: $e");
    }
    return false;
  }
}
