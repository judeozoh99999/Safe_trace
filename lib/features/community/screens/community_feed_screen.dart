import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/category_tag_pill.dart';
import '../../../shared/widgets/custom_buttons.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../providers/community_provider.dart';

class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Avoid syntax issue with WidgetRef parameter
    return Consumer(
      builder: (context, ref, child) {
        final communityState = ref.watch(communityProvider);
        final notifier = ref.read(communityProvider.notifier);
        const bool isDark = false;

        final filteredNotes = communityState.activeFilter == 'All'
            ? communityState.notes
            : communityState.notes.where((note) => note.category == communityState.activeFilter).toList();

        final filters = ['All', 'Traffic', 'Riot', 'Accident', 'Checkpoint'];

        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inline Left-aligned Header with top spacing
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 12.0),
                  child: const Text(
                    "Community Intelligence",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                // Subtle light divider line
                Container(
                  height: 1.0,
                  width: double.infinity,
                  color: const Color(0xFFE5E7EB),
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                ),
                const SizedBox(height: 16),

                // Horizontal category filter bar
                Container(
                  height: 52,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filters.length,
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      return Center(
                        child: CategoryTagPill(
                          label: filter,
                          isSelected: communityState.activeFilter == filter,
                          onTap: () => notifier.setFilter(filter),
                        ),
                      );
                    },
                  ),
                ),

                // Feed List
                Expanded(
                  child: filteredNotes.isEmpty
                      ? Center(
                          child: Text(
                            "No reports found in this category.",
                            style: TextStyle(
                              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = filteredNotes[index];
                            return _buildNoteCard(context, note, isDark);
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            elevation: 6,
            onPressed: () => _showAddReportSheet(context, notifier, isDark),
            child: const Icon(Icons.add_alert_rounded, size: 28),
          ),
        );
      },
    );
  }

  // Safety Feed Post Card Builder
  Widget _buildNoteCard(BuildContext context, CommunityNoteModel note, bool isDark) {
    Color severityColor;
    switch (note.severity.toLowerCase()) {
      case 'high':
        severityColor = AppColors.error;
        break;
      case 'medium':
        severityColor = AppColors.warning;
        break;
      default:
        severityColor = AppColors.info;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      shape: RoundedRectangleBorder(
        borderRadius: AppBorderRadius.mdBorder,
        side: BorderSide(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category & Severity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    note.category.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 12),

            // Location
            Text(
              note.location,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textLightPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Note body Text
            Text(
              note.noteText,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.dividerDark),
            const SizedBox(height: 8),

            // Time elapsed
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  note.timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Submission Dialog BottomSheet
  void _showAddReportSheet(BuildContext context, CommunityNotifier notifier, bool isDark) {
    final noteController = TextEditingController();
    final locController = TextEditingController(text: "Yaba, Lagos");
    String selectedCategory = "Traffic";
    String selectedSeverity = "Medium";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Report Safety Incident",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Location Input
                    const Text("LOCATION", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SafeTraceTextField(
                      hintText: "E.g. Herbert Macaulay Way, Yaba",
                      controller: locController,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Details Note Input
                    const Text("INCIDENT DETAILS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SafeTraceTextField(
                      hintText: "What is happening? Provide clear details to help others.",
                      controller: noteController,
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Selector columns
                    Row(
                      children: [
                        // Category Selection
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("CATEGORY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedCategory,
                                dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                                items: ['Traffic', 'Riot', 'Accident', 'Checkpoint']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setSheetState(() => selectedCategory = val);
                                },
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // Severity Selection
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("SEVERITY LEVEL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedSeverity,
                                dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                                items: ['Low', 'Medium', 'High']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setSheetState(() => selectedSeverity = val);
                                },
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Submit CTA
                    SafeTraceButton(
                      text: "Submit Safety Alert",
                      onPressed: () {
                        final note = noteController.text.trim();
                        final loc = locController.text.trim();
                        if (note.isEmpty || loc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("All fields are required")),
                          );
                          return;
                        }

                        notifier.addNote(loc, note, selectedCategory, selectedSeverity);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Safety alert submitted to community feed")),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
