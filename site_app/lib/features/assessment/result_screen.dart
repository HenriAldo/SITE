import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../shared/widgets/risk_badge.dart';

class ResultScreen extends StatelessWidget {
  final Assessment assessment;

  const ResultScreen({super.key, required this.assessment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Result'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRiskHeader(context),
              const SizedBox(height: 24),
              _buildPatientMessage(context),
              const SizedBox(height: 20),
              if (assessment.centralLineDetected) ...[
                _buildFindingsCard(context),
                const SizedBox(height: 20),
              ],
              if (assessment.imagePath != null) _buildImagePreview(),
              const SizedBox(height: 20),
              _buildNextSteps(context),
              const SizedBox(height: 28),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: assessment.riskLevel.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: assessment.riskLevel.color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RiskBadge(riskLevel: assessment.riskLevel, large: true),
          const SizedBox(height: 16),
          Text(
            _riskTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            _riskSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientMessage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What this means for you',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            assessment.patientMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildFindingsCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual findings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: assessment.visualFindings
                .map(
                  (finding) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: CircleAvatar(
                            radius: 3,
                            backgroundColor: AppColors.teal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            finding,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(assessment.imagePath!),
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildNextSteps(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next steps',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ..._getNextSteps(context).map(
          (step) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(step.$1, size: 14, color: AppColors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.$2,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<(IconData, String)> _getNextSteps(BuildContext context) {
    switch (assessment.riskLevel) {
      case RiskLevel.low:
        return [
          (Icons.calendar_today_outlined, 'Continue your daily check-in as scheduled.'),
          (Icons.info_outline, 'Monitor for any changes in redness, swelling, or pain.'),
          (Icons.phone_outlined, 'Contact your care team if anything concerns you.'),
        ];
      case RiskLevel.moderate:
        return [
          (Icons.person_outlined, 'Your care team has been notified and will review this shortly.'),
          (Icons.watch_later_outlined, 'You will be contacted within 24 hours.'),
          (Icons.emergency_outlined, 'Go to the ER immediately if you develop fever above 38°C.'),
        ];
      case RiskLevel.high:
        return [
          (Icons.emergency_outlined, 'Seek emergency medical care immediately.'),
          (Icons.local_hospital_outlined, 'Go to the nearest emergency department or call your clinic.'),
          (Icons.phone_outlined, 'Call your oncology team now.'),
        ];
    }
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (assessment.riskLevel == RiskLevel.high)
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.local_hospital_outlined, size: 18),
            label: const Text('Emergency Contacts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.riskHigh,
            ),
          ),
        if (assessment.riskLevel != RiskLevel.high) ...[
          ElevatedButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            child: const Text('Back to Home'),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () =>
              Navigator.popUntil(context, (route) => route.isFirst),
          child: const Text('Done'),
        ),
        const SizedBox(height: 16),
        Text(
          'This assessment is for informational purposes only and does not replace clinical judgment.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  String get _riskTitle {
    switch (assessment.riskLevel) {
      case RiskLevel.low:
        return 'No signs of concern';
      case RiskLevel.moderate:
        return 'Your clinician will review this';
      case RiskLevel.high:
        return 'Please seek medical attention now';
    }
  }

  String get _riskSubtitle {
    switch (assessment.riskLevel) {
      case RiskLevel.low:
        return 'Your catheter site looks normal. Continue monitoring daily.';
      case RiskLevel.moderate:
        return 'Some changes were detected. A clinician will review your case.';
      case RiskLevel.high:
        return 'Concerning signs were detected. Do not wait — seek care immediately.';
    }
  }
}
