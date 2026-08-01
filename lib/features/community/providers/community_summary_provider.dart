import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/community_safety_summary.dart';

class SummaryLocationParam {
  final LatLng location;
  final bool bypassCache;
  final bool isPreview;

  const SummaryLocationParam({
    required this.location,
    this.bypassCache = false,
    this.isPreview = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryLocationParam &&
          runtimeType == other.runtimeType &&
          location.latitude == other.location.latitude &&
          location.longitude == other.location.longitude &&
          bypassCache == other.bypassCache &&
          isPreview == other.isPreview;

  @override
  int get hashCode =>
      location.latitude.hashCode ^
      location.longitude.hashCode ^
      bypassCache.hashCode ^
      isPreview.hashCode;
}

final communitySafetySummaryProvider =
    FutureProvider.family<CommunitySafetySummary?, SummaryLocationParam>(
        (ref, param) async {
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('getCommunitySafetySummary');
    final response = await callable.call({
      'lat': param.location.latitude,
      'lng': param.location.longitude,
      'radius_km': 12.0,
      'bypass_cache': param.bypassCache,
      'is_preview': param.isPreview,
    });

    if (response.data == null) return null;
    final map = Map<String, dynamic>.from(response.data as Map);
    if (map['summary'] == null ||
        map['note_count'] == null ||
        (map['note_count'] is int && map['note_count'] == 0)) {
      return null;
    }
    return CommunitySafetySummary.fromMap(map);
  } catch (e) {
    // Hide card silently on error
    return null;
  }
});
