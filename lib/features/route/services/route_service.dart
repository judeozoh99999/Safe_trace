import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final double durationMinutes;

  RouteResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RouteService {
  static final Dio _dio = Dio();

  /// Forward geocode address to LatLng using free Nominatim OpenStreetMap API
  static Future<LatLng?> geocodeAddress(String address) async {
    final queryCandidates = <String>[address];
    final parts = address.split(',');
    if (parts.length > 1) {
      for (int i = 1; i < parts.length; i++) {
        final sub = parts.sublist(i).join(',').trim();
        if (sub.length >= 3 && !queryCandidates.contains(sub)) {
          queryCandidates.add(sub);
        }
      }
    }

    for (final candidate in queryCandidates) {
      try {
        final response = await _dio.get(
          "https://nominatim.openstreetmap.org/search",
          queryParameters: {
            'q': candidate,
            'format': 'json',
            'limit': 1,
            'countrycodes': 'ng',
          },
          options: Options(
            headers: {
              'User-Agent': 'SafeTraceApp/1.0',
            },
          ),
        );

        if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
          final first = (response.data as List)[0];
          final lat = double.parse(first['lat'].toString());
          final lon = double.parse(first['lon'].toString());
          return LatLng(lat, lon);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Fetch routing path from OSRM driving API
  static Future<RouteResult?> fetchRoute(LatLng start, LatLng dest) async {
    debugPrint("DIRECTIONS API CALL ORIGIN LAT ${start.latitude} ORIGIN LNG ${start.longitude} DESTINATION LAT ${dest.latitude} DESTINATION LNG ${dest.longitude}");

    try {
      final url = "https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${dest.longitude},${dest.latitude}";
      final response = await _dio.get(
        url,
        queryParameters: {
          'overview': 'full',
          'geometries': 'polyline',
          'steps': 'true',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final routes = response.data['routes'] as List;
        if (routes.isNotEmpty) {
          final route = routes[0];
          final legs = route['legs'] as List?;
          String startAddr = "Start (${start.latitude.toStringAsFixed(4)}, ${start.longitude.toStringAsFixed(4)})";
          String endAddr = "End (${dest.latitude.toStringAsFixed(4)}, ${dest.longitude.toStringAsFixed(4)})";
          if (legs != null && legs.isNotEmpty) {
            final firstLeg = legs.first as Map<String, dynamic>?;
            final lastLeg = legs.last as Map<String, dynamic>?;
            if (firstLeg != null && firstLeg['summary'] != null && firstLeg['summary'].toString().isNotEmpty) {
              startAddr = firstLeg['summary'].toString();
            }
            if (lastLeg != null && lastLeg['summary'] != null && lastLeg['summary'].toString().isNotEmpty) {
              endAddr = lastLeg['summary'].toString();
            }
          }
          debugPrint("DIRECTIONS API RESPONSE START ADDRESS $startAddr END ADDRESS $endAddr");

          final geometry = route['geometry'] as String;
          final durationSec = route['duration'] as num;
          final distanceMeters = route['distance'] as num;

          final points = decodePolyline(geometry);

          return RouteResult(
            polylinePoints: points,
            distanceKm: distanceMeters / 1000.0,
            durationMinutes: durationSec / 60.0,
          );
        }
      }
    } catch (e) {
      debugPrint("ROUTE DEBUG ERROR: $e");
    }
    return null;
  }

  /// Decodes Google Polyline Algorithm format to a list of LatLng
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
