import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<bool> requestPermissionsSilent() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      final requestStatus = await Permission.location.request();
      return requestStatus.isGranted || requestStatus.isLimited;
    }
    return status.isGranted || status.isLimited;
  }

  static Future<bool> checkAndRequestPermissions(BuildContext context) async {
    final serviceEnabled = await Permission.locationWhenInUse.serviceStatus.isEnabled;
    if (!serviceEnabled) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Location Services Disabled"),
            content: const Text("GPS / location services are turned off on your device. Please turn them on in your phone settings."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      return false;
    }

    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
      if (status.isDenied) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context);
        }
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDeniedDialog(context);
      }
      return false;
    }

    return true;
  }

  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Location Permission Required"),
        content: const Text(
          "SafeTrace requires location permissions to pinpoint your position and log safety pins. "
          "Please enable location access in the app settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  static Future<bool> requestPermissions() async {
    final status = await Permission.location.request();
    return status.isGranted || status.isLimited;
  }

  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10 meters filter
      ),
    );
  }

  static Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
        if (p.subLocality != null && p.subLocality!.isNotEmpty) parts.add(p.subLocality!);
        if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
        if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {}

    try {
      final dio = Dio();
      dio.options.headers['User-Agent'] = 'SafeTrace/1.0 (judeozoh99999@gmail.com)';
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': latitude,
          'lon': longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final displayName = response.data['display_name'];
        if (displayName != null && displayName.toString().isNotEmpty) {
          return displayName.toString();
        }
      }
    } catch (e) {
      debugPrint("Reverse geocode error: $e");
    }
    return "Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}";
  }

  static Future<Location?> geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return locations.first;
      }
    } catch (e) {
      debugPrint("Geocode address error: $e");
    }
    return null;
  }
}
