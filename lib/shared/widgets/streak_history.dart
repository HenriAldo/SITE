import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';

/// A GitHub-commit-style 14-day grid of a patient's check-in history,
/// colored by that day's classification (clinician override respected),
/// plus a streak counter. Shared between the patient's own Home screen
/// and the clinician's patient detail screen.
class StreakHistory extends StatelessWidget {
  final String userId;
  /// Height of each day box. Lower = more compact (e.g. clinician detail).
  final double boxHeight;
  /// When provided, filled day boxes are tappable and call this with that
  /// day's assessment (e.g. to open its check-in detail).
  final void Function(Assessment assessment)? onDayTap;

  const StreakHistory({
    super.key,
    required this.userId,
    this.boxHeight = 40,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Assessment>>(
      stream: FirestoreService().assessmentStream(userId),
      builder: (context, assessSnap) {
        final assessments = assessSnap.data ?? [];

        return StreamBuilder<List<FlaggedCase>>(
          stream: FirestoreService().flaggedCasesForUser(userId),
          builder: (context, flagSnap) {
            final flaggedById = {
              for (final f in flagSnap.data ?? []) f.id: f,
            };

            // One entry per local calendar day with a valid (central-line
            // detected) submission, keeping the clinician's classification
            // once reviewed. Assessments are newest-first, so the first
            // match per day is the latest submission for that day.
            final dayLevels = <DateTime, RiskLevel>{};
            final dayAssessments = <DateTime, Assessment>{};
            for (final a in assessments) {
              if (!a.centralLineDetected) continue;
              final day =
                  DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
              if (dayLevels.containsKey(day)) continue;
              final flagged = flaggedById[a.id];
              dayLevels[day] = flagged?.clinicianClassification ?? a.riskLevel;
              dayAssessments[day] = a;
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            bool hasSubmission(DateTime day) => dayLevels.containsKey(day);

            // A streak breaks after one missed local-calendar day. "Today"
            // isn't a miss until the day has actually passed, so start
            // counting from today if it's done, otherwise from yesterday.
            var cursor = hasSubmission(today)
                ? today
                : today.subtract(const Duration(days: 1));
            var streak = 0;
            while (hasSubmission(cursor)) {
              streak++;
              cursor = cursor.subtract(const Duration(days: 1));
            }

            final days = List.generate(
                14, (i) => today.subtract(Duration(days: 13 - i)));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Check-in streak',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (streak > 0) ...[
                      const Icon(Icons.local_fire_department,
                          color: Colors.deepOrange, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day${streak == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Last 14 days',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: days.map((day) {
                    final assessment = dayAssessments[day];
                    final tappable = onDayTap != null && assessment != null;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: GestureDetector(
                          onTap: tappable ? () => onDayTap!(assessment) : null,
                          child: Container(
                            height: boxHeight,
                            decoration: BoxDecoration(
                              color:
                                  dayLevels[day]?.color ?? AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: dayLevels[day] == null
                                  ? Border.all(color: AppColors.cardBorder)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
