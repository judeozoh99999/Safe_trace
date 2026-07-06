import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeViewMode { map, history }

class HomeState {
  final HomeViewMode viewMode;
  final bool isTracking;
  final double currentLatitude;
  final double currentLongitude;
  final List<Map<String, String>> logs;

  HomeState({
    this.viewMode = HomeViewMode.map,
    this.isTracking = false,
    this.currentLatitude = 6.5244, // Lagos Default
    this.currentLongitude = 3.3792,
    this.logs = const [
      {
        'id': '1',
        'location': 'Yaba, Lagos',
        'timestamp': 'Today, 2:30 PM',
        'note': 'Heading back from the tech hub. High traffic observed.',
        'aiAdvice': 'Remain inside public transport. Keep devices secured.'
      },
      {
        'id': '2',
        'location': 'Lekki Phase 1, Lagos',
        'timestamp': 'Yesterday, 8:15 PM',
        'note': 'Stopped by a grocery store. Well lit area.',
        'aiAdvice': 'Excellent decision to stay in well-lit areas. Maintain awareness of surrounding vehicles.'
      },
      {
        'id': '3',
        'location': 'Ikeja City Mall, Lagos',
        'timestamp': '2 days ago, 11:00 AM',
        'note': 'Meeting with a client at the food court.',
        'aiAdvice': 'Stay in crowded public areas. Secure personal belongings.'
      }
    ],
  });

  HomeState copyWith({
    HomeViewMode? viewMode,
    bool? isTracking,
    double? currentLatitude,
    double? currentLongitude,
    List<Map<String, String>>? logs,
  }) {
    return HomeState(
      viewMode: viewMode ?? this.viewMode,
      isTracking: isTracking ?? this.isTracking,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      logs: logs ?? this.logs,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(HomeState());

  void setViewMode(HomeViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void toggleTracking() {
    state = state.copyWith(isTracking: !state.isTracking);
  }

  void addLog(String location, String note, String aiAdvice) {
    final newLog = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'location': location,
      'timestamp': 'Just now',
      'note': note,
      'aiAdvice': aiAdvice,
    };
    state = state.copyWith(logs: [newLog, ...state.logs]);
  }

  void deleteLog(String id) {
    state = state.copyWith(logs: state.logs.where((log) => log['id'] != id).toList());
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier();
});
