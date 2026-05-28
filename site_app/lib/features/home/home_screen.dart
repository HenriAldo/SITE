import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../shared/widgets/risk_badge.dart';
import '../assessment/guided_capture_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 28),
                    _buildCheckInCard(context),
                    const SizedBox(height: 20),
                    _buildLastAssessmentCard(context),
                    const SizedBox(height: 20),
                    _buildInfoSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SITE',
              style: TextStyle(
                color: AppColors.teal,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Good morning,\nMax.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Icon(Icons.person_outline, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildCheckInCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.teal.withOpacity(0.15),
            AppColors.teal.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Daily check-in due',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Time to photograph\nyour catheter site',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Takes about 2 minutes. Your clinician may review the result.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GuidedCaptureScreen()),
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Start Check-In'),
          ),
        ],
      ),
    );
  }

  Widget _buildLastAssessmentCard(BuildContext context) {
    // Placeholder — will be populated from local storage
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last Assessment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              RiskBadge(riskLevel: RiskLevel.low),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Yesterday, 09:14',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'No signs of infection. Continue routine monitoring.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your catheter',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(context, Icons.medical_services_outlined, 'Type', 'PICC Line'),
        _buildInfoRow(context, Icons.calendar_today_outlined, 'Inserted', '12 days ago'),
        _buildInfoRow(context, Icons.local_hospital_outlined, 'Care team', 'Oncology, Station 4'),
        const SizedBox(height: 20),
        _buildEmergencyBanner(context),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.riskHighBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.riskHigh.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.emergency_outlined, color: AppColors.riskHigh, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'If you have fever above 38°C or severe chills, go to the emergency room immediately.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.riskHigh.withOpacity(0.9),
                    fontSize: 13,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
