import 'package:flutter_riverpod/flutter_riverpod.dart';

class RouteIntelState {
  final String startPoint;
  final String destination;
  final bool isRouteCalculated;
  final String travelTime;
  final String distance;
  final String trafficStatus;
  final String aiAdvisory;

  RouteIntelState({
    this.startPoint = 'Current Location',
    this.destination = '',
    this.isRouteCalculated = false,
    this.travelTime = '',
    this.distance = '',
    this.trafficStatus = '',
    this.aiAdvisory = '',
  });

  RouteIntelState copyWith({
    String? startPoint,
    String? destination,
    bool? isRouteCalculated,
    String? travelTime,
    String? distance,
    String? trafficStatus,
    String? aiAdvisory,
  }) {
    return RouteIntelState(
      startPoint: startPoint ?? this.startPoint,
      destination: destination ?? this.destination,
      isRouteCalculated: isRouteCalculated ?? this.isRouteCalculated,
      travelTime: travelTime ?? this.travelTime,
      distance: distance ?? this.distance,
      trafficStatus: trafficStatus ?? this.trafficStatus,
      aiAdvisory: aiAdvisory ?? this.aiAdvisory,
    );
  }
}

class RouteIntelNotifier extends StateNotifier<RouteIntelState> {
  RouteIntelNotifier() : super(RouteIntelState());

  void setDestination(String dest) {
    state = state.copyWith(destination: dest);
  }

  void calculateRoute() {
    if (state.destination.trim().isEmpty) return;
    
    // Mock route calculation details
    final isLekki = state.destination.toLowerCase().contains("lekki");
    final travelTime = isLekki ? "45 mins" : "32 mins";
    final distance = isLekki ? "18.5 km" : "12.0 km";
    final traffic = isLekki ? "Heavy Traffic" : "Moderate Traffic";
    final advisory = isLekki
        ? "Lekki-Epe expressway has construction delays. Also, community notes report localized street hawker disputes near tollgate. Recommendation: Take Alternative Route via Oniru to avoid pedestrian congestion."
        : "Third Mainland Bridge is flowing smoothly. Normal police checkpoint near bypass, drive with valid documentation. Safe route recommended.";

    state = state.copyWith(
      isRouteCalculated: true,
      travelTime: travelTime,
      distance: distance,
      trafficStatus: traffic,
      aiAdvisory: advisory,
    );
  }

  void clearRoute() {
    state = RouteIntelState();
  }
}

final routeIntelProvider = StateNotifierProvider<RouteIntelNotifier, RouteIntelState>((ref) {
  return RouteIntelNotifier();
});
