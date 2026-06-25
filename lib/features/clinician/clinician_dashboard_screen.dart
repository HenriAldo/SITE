import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/models/assessment.dart';
import '../../shared/widgets/risk_badge.dart';
import 'case_detail_screen.dart';
import 'patients_screen.dart';

class ClinicianDashboardScreen extends StatefulWidget {
  const ClinicianDashboardScreen({super.key});

  @override
  State<ClinicianDashboardScreen> createState() =>
      _ClinicianDashboardScreenState();
}

class _ClinicianDashboardScreenState extends State<ClinicianDashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _showReviewed = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SITE — Clinician Dashboard'),
            Text(
              email,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance,
            builder: (context, mode, _) {
              final isDark = mode != ThemeMode.light;
              return IconButton(
                icon: Icon(
                    isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                onPressed: () => ThemeController.instance
                    .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.flag_outlined, size: 18), text: 'Flagged Cases'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Patients'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlaggedTab(),
          const PatientsScreen(),
        ],
      ),
    );
  }

  Widget _buildFlaggedTab() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildCaseList()),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _buildStatChip(),
          const Spacer(),
          Row(
            children: [
              Text(
                'Show reviewed',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 13),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _showReviewed,
                onChanged: (v) => setState(() => _showReviewed = v),
                activeColor: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip() {
    return StreamBuilder<List<FlaggedCase>>(
      stream: FirestoreService().flaggedCasesStream(),
      builder: (context, snap) {
        final pending =
            (snap.data ?? []).where((c) => !c.reviewed).length;
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: pending > 0
                ? AppColors.riskModerateBg
                : AppColors.riskLowBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: pending > 0
                  ? AppColors.riskModerate.withOpacity(0.4)
                  : AppColors.riskLow.withOpacity(0.4),
            ),
          ),
          child: Text(
            '$pending pending review',
            style: TextStyle(
              color: pending > 0
                  ? AppColors.riskModerate
                  : AppColors.riskLow,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaseList() {
    return StreamBuilder<List<FlaggedCase>>(
      stream: FirestoreService().flaggedCasesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final all = snapshot.data ?? [];
        final cases = _showReviewed
            ? all
            : all.where((c) => !c.reviewed).toList();

        if (cases.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: cases.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildCaseCard(context, cases[i]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 52, color: AppColors.riskLow),
          const SizedBox(height: 16),
          Text(
            _showReviewed ? 'No cases yet' : 'No pending cases',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _showReviewed
                ? 'Flagged cases will appear here.'
                : 'All escalated cases have been reviewed.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCaseCard(BuildContext context, FlaggedCase flaggedCase) {
    final dateStr = DateFormat('d MMM yyyy — HH:mm')
        .format(flaggedCase.timestamp);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaseDetailScreen(flaggedCase: flaggedCase),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: flaggedCase.reviewed
                ? AppColors.cardBorder
                : flaggedCase.riskLevel.color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flaggedCase.patientName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        flaggedCase.patientEmail,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                RiskBadge(riskLevel: flaggedCase.riskLevel),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              dateStr,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (flaggedCase.visualFindings.isNotEmpty)
              Text(
                flaggedCase.visualFindings.first,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textPrimary, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (flaggedCase.reviewed) ...[
                  const Icon(Icons.check_circle,
                      size: 14, color: AppColors.riskLow),
                  const SizedBox(width: 5),
                  Text(
                    'Reviewed',
                    style: TextStyle(
                      color: AppColors.riskLow,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: flaggedCase.riskLevel.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Awaiting review',
                    style: TextStyle(
                      color: flaggedCase.riskLevel.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
