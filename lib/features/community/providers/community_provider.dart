import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommunityNoteModel {
  final String id;
  final String location;
  final String noteText;
  final String category; // Traffic, Riot, Accident, Checkpoint
  final String severity; // Low, Medium, High
  final String timeAgo;

  CommunityNoteModel({
    required this.id,
    required this.location,
    required this.noteText,
    required this.category,
    required this.severity,
    required this.timeAgo,
  });
}

class CommunityState {
  final String activeFilter; // All, Traffic, Riot, Accident, Checkpoint
  final List<CommunityNoteModel> notes;

  CommunityState({
    this.activeFilter = 'All',
    this.notes = const [],
  });

  CommunityState copyWith({
    String? activeFilter,
    List<CommunityNoteModel>? notes,
  }) {
    return CommunityState(
      activeFilter: activeFilter ?? this.activeFilter,
      notes: notes ?? this.notes,
    );
  }
}

class CommunityNotifier extends StateNotifier<CommunityState> {
  CommunityNotifier()
      : super(CommunityState(
          notes: [
            CommunityNoteModel(
              id: '1',
              location: 'Yaba Terminal, Lagos',
              noteText: 'Protest warning: Local transport union workers gathered near the train station. Security officials are on ground. Avoid the area if possible.',
              category: 'Riot',
              severity: 'High',
              timeAgo: '10 mins ago',
            ),
            CommunityNoteModel(
              id: '2',
              location: 'Ikorodu Road, Lagos',
              noteText: 'Severe gridlock near Maryland due to broken down tanker blocking two lanes. Traffic extends back to Onipanu.',
              category: 'Traffic',
              severity: 'Medium',
              timeAgo: '32 mins ago',
            ),
            CommunityNoteModel(
              id: '3',
              location: 'Ketu Bypass, Lagos',
              noteText: 'Unsanctioned police checkpoint near pedestrian bridge. Officers stopping private vehicles for documents check.',
              category: 'Checkpoint',
              severity: 'Low',
              timeAgo: '1 hr ago',
            ),
            CommunityNoteModel(
              id: '4',
              location: 'Third Mainland Bridge, Lagos',
              noteText: 'Multi-vehicle collision near Adeniji ramp. Expect slow movements on the mainland-bound lane.',
              category: 'Accident',
              severity: 'Medium',
              timeAgo: '2 hrs ago',
            ),
          ],
        ));

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  void addNote(String location, String noteText, String category, String severity) {
    final newNote = CommunityNoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: location,
      noteText: noteText,
      category: category,
      severity: severity,
      timeAgo: 'Just now',
    );
    state = state.copyWith(notes: [newNote, ...state.notes]);
  }
}

final communityProvider = StateNotifierProvider<CommunityNotifier, CommunityState>((ref) {
  return CommunityNotifier();
});
