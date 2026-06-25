import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/models/patient_profile.dart';
import '../../data/services/firestore_service.dart';
import '../../shared/widgets/risk_badge.dart';
import '../assessment/guided_capture_screen.dart';
import '../profile/profile_screen.dart';

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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final name = snapshot.data?.displayName;
        final hour = DateTime.now().hour;
        final timeGreeting = hour < 12
            ? 'Good morning,'
            : hour < 18
                ? 'Good afternoon,'
                : 'Good evening,';
        final greeting = name != null && name.isNotEmpty
            ? '$timeGreeting\n$name.'
            : timeGreeting;
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
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Icon(Icons.person_outline, color: AppColors.textSecondary),
          ),
        ),
          ],
        );
      },
    );
  }

  Widget _buildCheckInCard(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return _buildCheckInDueCard(context);

    return StreamBuilder<List<Assessment>>(
      stream: FirestoreService().assessmentStream(userId),
      builder: (context, snapshot) {
        final assessments = snapshot.data ?? [];
        final checkedInToday =
            assessments.isNotEmpty && _isToday(assessments.first.timestamp);
        return checkedInToday
            ? _buildCheckedInTodayCard(context)
            : _buildCheckInDueCard(context);
      },
    );
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Widget _buildCheckInDueCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withOpacity(0.15),
            AppColors.accent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
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
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Daily check-in due',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.accent,
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

  Widget _buildCheckedInTodayCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.riskLowBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.riskLow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.riskLow, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's check-in complete",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Come back tomorrow for your next check-in.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastAssessmentCard(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<Assessment>>(
      stream: FirestoreService().assessmentStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2),
            ),
          );
        }

        final assessments = snapshot.data ?? [];
        if (assessments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.history_outlined,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No assessments yet — complete your first check-in.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        final latest = assessments.first;
        final dateStr =
            DateFormat('EEEE, d MMM — HH:mm').format(latest.timestamp);

        return Container(
          padding: const EdgeInsets.all(16),
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
                  RiskBadge(riskLevel: latest.riskLevel),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                latest.patientMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<PatientProfile?>(
      future: userId != null
          ? FirestoreService().getProfile(userId)
          : Future.value(null),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your catheter',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (profile != null) ...[
              if (profile.catheterType.isNotEmpty)
                _buildInfoRow(context, Icons.medical_services_outlined,
                    'Type', profile.catheterType),
              _buildInfoRow(
                context,
                Icons.calendar_today_outlined,
                'Inserted',
                '${profile.daysSinceInsertion} days ago',
              ),
              if (profile.careTeam != null &&
                  profile.careTeam!.clinic.isNotEmpty)
                _buildInfoRow(context, Icons.local_hospital_outlined,
                    'Care team', profile.careTeam!.clinic),
            ] else ...[
              _buildInfoRow(context, Icons.info_outline, 'Profile',
                  'Set up in your profile'),
            ],
            const SizedBox(height: 20),
            _buildEmergencyBanner(context),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
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
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
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
