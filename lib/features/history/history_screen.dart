import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
import '../../shared/widgets/risk_badge.dart';
import 'entry_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Assessment History')),
      body: userId == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<Assessment>>(
              stream: FirestoreService().assessmentStream(userId),
              builder: (context, assessSnap) {
                if (assessSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  );
                }
                if (assessSnap.hasError) {
                  return Center(child: Text('Error: ${assessSnap.error}'));
                }
                final assessments = assessSnap.data ?? [];
                if (assessments.isEmpty) return _buildEmpty(context);

                // Merge review status from flagged_cases for escalated entries
                return StreamBuilder<List<FlaggedCase>>(
                  stream: FirestoreService().flaggedCasesForUser(userId),
                  builder: (context, flagSnap) {
                    // On error, log and fall back to empty map (cards show
                    // "Awaiting review" rather than crashing).
                    if (flagSnap.hasError) {
                      debugPrint('flaggedCasesForUser error: ${flagSnap.error}');
                    }
                    final flaggedById = {
                      for (final f in flagSnap.data ?? []) f.id: f,
                    };

                    // Assessments are newest-first. Once a newer escalated
                    // entry has been reviewed, older unreviewed entries no
                    // longer need to show "Awaiting review" — the patient's
                    // most recent status already reflects clinician input.
                    var newerReviewedSeen = false;
                    final suppressBadge = List<bool>.filled(
                        assessments.length, false);
                    for (var i = 0; i < assessments.length; i++) {
                      final flagged = flaggedById[assessments[i].id];
                      if (!assessments[i].escalate) continue;
                      if (flagged?.reviewed ?? false) {
                        newerReviewedSeen = true;
                      } else {
                        suppressBadge[i] = newerReviewedSeen;
                      }
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: assessments.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCard(
                        context,
                        assessments[index],
                        flaggedById[assessments[index].id],
                        suppressBadge[index],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No assessments yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first daily check-in\nto see results here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Assessment assessment,
      FlaggedCase? flagged, bool suppressAwaitingBadge) {
    final dateStr =
        DateFormat('d MMM yyyy — HH:mm').format(assessment.timestamp);
    final reviewed = flagged?.reviewed ?? false;
    // Only reflect the clinician's classification once the case is reviewed,
    // so the badge/level and the "reviewed" indicator stay consistent.
    final effectiveLevel = reviewed
        ? (flagged?.clinicianClassification ?? assessment.riskLevel)
        : assessment.riskLevel;
    final hasClinicianOverride =
        reviewed && flagged?.clinicianClassification != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EntryDetailScreen(assessment: assessment),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: effectiveLevel.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: effectiveLevel.color.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assessment.patientMessage,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                  ),
                  if (hasClinicianOverride) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Adjusted by your clinician',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: effectiveLevel.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RiskBadge(riskLevel: effectiveLevel),
                if (assessment.escalate &&
                    (reviewed || !suppressAwaitingBadge)) ...[
                  const SizedBox(height: 6),
                  _reviewIndicator(reviewed),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewIndicator(bool reviewed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          reviewed ? Icons.check_box : Icons.hourglass_empty_outlined,
          size: 14,
          color: reviewed ? AppColors.riskLow : AppColors.riskModerate,
        ),
        const SizedBox(width: 4),
        Text(
          reviewed ? 'Reviewed' : 'Awaiting review',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: reviewed ? AppColors.riskLow : AppColors.riskModerate,
          ),
        ),
      ],
    );
  }
}
