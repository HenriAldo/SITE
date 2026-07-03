import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/zoomable_image.dart';

class EntryDetailScreen extends StatelessWidget {
  final Assessment assessment;

  const EntryDetailScreen({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EEEE, d MMMM yyyy — HH:mm').format(assessment.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: Text(dateStr),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (assessment.escalate) ...[
              _buildClinicianSection(context),
              const SizedBox(height: 20),
            ],
            _buildImage(),
            const SizedBox(height: 20),
            _buildStatusSection(context),
            const SizedBox(height: 20),
            _buildSymptomsSection(context),
            const SizedBox(height: 20),
            _buildAiSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final hasUrl =
        assessment.imageUrl != null && assessment.imageUrl!.isNotEmpty;
    final hasFile = !kIsWeb &&
        assessment.imagePath != null &&
        File(assessment.imagePath!).existsSync();

    if (!hasUrl && !hasFile) return const SizedBox.shrink();

    return ZoomableImage(
      url: hasUrl ? assessment.imageUrl : null,
      file: hasFile ? File(assessment.imagePath!) : null,
      heroTag: 'entry-${assessment.id}',
      aspectRatio: 4 / 3,
    );
  }

  // The displayed status: fetch the clinician's review (if any) for every
  // assessment, not just escalated ones — so unreviewed non-escalated
  // cases (including "Not Detected") can still show a not-yet-checked
  // notice on the detail screen.
  Widget _buildStatusSection(BuildContext context) {
    return FutureBuilder<FlaggedCase?>(
      future: FirestoreService().getFlaggedCase(assessment.id),
      builder: (context, snap) {
        final flagged = snap.data;
        final effectiveLevel =
            flagged?.clinicianClassification ?? assessment.riskLevel;
        final hasClinician = flagged?.clinicianClassification != null;
        final reviewed = flagged?.reviewed ?? false;
        return _statusCard(context, effectiveLevel,
            clinicianOverride: hasClinician, reviewed: reviewed);
      },
    );
  }

  Widget _statusCard(BuildContext context, RiskLevel level,
      {required bool clinicianOverride, required bool reviewed}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: level.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: level.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          RiskBadge(riskLevel: level, large: true),
          const SizedBox(width: 12),
          if (clinicianOverride)
            Expanded(
              child: Text(
                'Confirmed by your clinician',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12, color: level.color, fontWeight: FontWeight.w500),
              ),
            )
          else if (!reviewed)
            Expanded(
              child: Text(
                'Not yet checked by a clinician',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSymptomsSection(BuildContext context) {
    final symptoms = assessment.symptoms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your reported symptoms',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: symptoms == null
              ? Text('No symptom data recorded.',
                  style: Theme.of(context).textTheme.bodyMedium)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!symptoms.hasSymptoms)
                      Text('No symptoms reported.',
                          style: Theme.of(context).textTheme.bodyMedium)
                    else ...[
                      if (symptoms.hasFever) _symptomRow(context, 'Fever'),
                      if (symptoms.hasChills)
                        _symptomRow(context, 'Chills or shivering'),
                      if (symptoms.hasPain)
                        _symptomRow(context, 'Pain at catheter site'),
                      if (symptoms.hasRedness) _symptomRow(context, 'Redness'),
                      if (symptoms.hasSwelling) _symptomRow(context, 'Swelling'),
                      if (symptoms.hasDrainage)
                        _symptomRow(context, 'Discharge or leaking'),
                      for (final extra in symptoms.extraSymptoms)
                        _symptomRow(context, extra),
                      if (!symptoms.hasFever &&
                          !symptoms.hasChills &&
                          !symptoms.hasPain &&
                          !symptoms.hasRedness &&
                          !symptoms.hasSwelling &&
                          !symptoms.hasDrainage &&
                          symptoms.extraSymptoms.isEmpty)
                        Text('Symptoms present but none selected.',
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (symptoms.additionalNotes != null &&
                        symptoms.additionalNotes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Text(
                        '"${symptoms.additionalNotes}"',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _symptomRow(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildAiSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI assessment', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assessment.patientMessage,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textPrimary, height: 1.6),
              ),
              if (assessment.visualFindings.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text('Visual findings',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ...assessment.visualFindings.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: CircleAvatar(
                              radius: 3,
                              backgroundColor: AppColors.accent),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (assessment.reasoning.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text('Reasoning',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  assessment.reasoning,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Only shown for escalated assessments
  Widget _buildClinicianSection(BuildContext context) {
    return FutureBuilder<FlaggedCase?>(
      future: FirestoreService().getFlaggedCase(assessment.id),
      builder: (context, snap) {
        final flagged = snap.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clinician review',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: snap.connectionState == ConnectionState.waiting
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            color: AppColors.accent, strokeWidth: 2),
                      ),
                    )
                  : flagged == null
                      ? Row(
                          children: [
                            const Icon(Icons.hourglass_empty,
                                size: 16, color: AppColors.riskModerate),
                            const SizedBox(width: 8),
                            Text(
                              'Your clinician has not reviewed this yet.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.riskModerate),
                            ),
                          ],
                        )
                      : flagged.reviewed
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        size: 16, color: AppColors.riskLow),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reviewed',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.riskLow),
                                    ),
                                  ],
                                ),
                                if (flagged.reviewerNotes.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    flagged.reviewerNotes,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.5),
                                  ),
                                ],
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.hourglass_empty,
                                    size: 16, color: AppColors.riskModerate),
                                const SizedBox(width: 8),
                                Text(
                                  'Awaiting clinician review.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.riskModerate),
                                ),
                              ],
                            ),
            ),
          ],
        );
      },
    );
  }
}
