import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../shared/widgets/risk_badge.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Placeholder data — will come from local storage / Firebase
  List<Assessment> get _mockHistory => [
        Assessment(
          id: '1',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          riskLevel: RiskLevel.low,
          centralLineDetected: true,
          visualFindings: ['Skin appears flesh-colored', 'No redness or swelling visible'],
          reasoning: 'CLISA Score 0. No concerning features.',
          patientMessage: 'Your catheter site looks normal.',
          escalate: false,
        ),
        Assessment(
          id: '2',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          riskLevel: RiskLevel.low,
          centralLineDetected: true,
          visualFindings: ['Normal skin coloration', 'Minimal dressing moisture'],
          reasoning: 'CLISA Score 0. Normal appearance.',
          patientMessage: 'Your catheter site looks normal.',
          escalate: false,
        ),
        Assessment(
          id: '3',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          riskLevel: RiskLevel.moderate,
          centralLineDetected: true,
          visualFindings: ['Mild redness at insertion site', 'No drainage visible'],
          reasoning: 'CLISA Score 1-2. Mild erythema noted.',
          patientMessage: 'Some mild redness was detected. Your clinician will review.',
          escalate: true,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment History')),
      body: SafeArea(
        child: _mockHistory.isEmpty
            ? _buildEmpty(context)
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: _mockHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildHistoryCard(context, _mockHistory[index]),
              ),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
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

  Widget _buildHistoryCard(BuildContext context, Assessment assessment) {
    final dateStr = DateFormat('EEEE, d MMM — HH:mm').format(assessment.timestamp);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
              RiskBadge(riskLevel: assessment.riskLevel),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            assessment.patientMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
          ),
          if (assessment.escalate) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: AppColors.riskModerate),
                const SizedBox(width: 5),
                Text(
                  'Escalated to clinician',
                  style: TextStyle(
                    color: AppColors.riskModerate,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
