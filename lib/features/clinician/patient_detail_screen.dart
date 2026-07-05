import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/patient_profile.dart';
import '../../data/services/firestore_service.dart';
import '../../shared/widgets/streak_history.dart';

/// Clinician-facing detail page for a single patient: their check-in
/// history (same design as the patient app's Home streak) plus the basic
/// facts already shown in the patient list overview.
class PatientDetailScreen extends StatelessWidget {
  final PatientSummary patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    final profile = patient.profile;

    return Scaffold(
      appBar: AppBar(title: Text(patient.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: StreakHistory(userId: patient.userId),
            ),
            const SizedBox(height: 28),
            Text('Patient details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (profile != null)
              _buildFacts(context, profile)
            else
              _buildNoProfile(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFacts(BuildContext context, PatientProfile profile) {
    final facts = <(String, String)>[
      ('Catheter type', profile.catheterType),
      ('Inserted', DateFormat('d MMM yyyy').format(profile.insertionDate)),
      ('Days in place', '${profile.daysSinceInsertion} days'),
      if (profile.diagnosis.isNotEmpty) ('Diagnosis', profile.diagnosis),
      if (profile.age > 0) ('Age', '${profile.age}'),
      ('Immunosuppressed', profile.isImmunosuppressed ? 'Yes' : 'No'),
      if (profile.comorbidities.isNotEmpty)
        ('Comorbidities', profile.comorbidities.join(', ')),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // On wide (tablet/desktop) screens, keep facts as fixed-width
        // rectangles rather than stretching a single card across the
        // full width.
        final isWide = constraints.maxWidth > 600;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: facts
              .map((f) => SizedBox(
                    width: isWide ? 260 : double.infinity,
                    child: _FactCard(label: f.$1, value: f.$2),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildNoProfile(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 12),
          Text(
            'No clinical profile set up yet.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  final String label;
  final String value;

  const _FactCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
