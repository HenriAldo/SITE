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
import 'clinician_profile_screen.dart';
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
            icon: const Icon(Icons.person_outline),
            tooltip: 'My contact details',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClinicianProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: Image.asset('assets/images/Logo.png', height: 32),
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
        final hasReviewed = all.any((c) => c.reviewed);

        // If the toggle was on but all reviewed cases vanished, reset it
        if (!hasReviewed && _showReviewed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _showReviewed = false);
          });
        }

        final cases = _showReviewed
            ? all
            : all.where((c) => !c.reviewed).toList();

        // Sort: high → moderate → low → undetected, then newest first
        final riskOrder = {
          RiskLevel.high: 0,
          RiskLevel.moderate: 1,
          RiskLevel.low: 2,
          RiskLevel.undetected: 3,
        };
        cases.sort((a, b) {
          final riskCmp =
              (riskOrder[a.riskLevel] ?? 3).compareTo(riskOrder[b.riskLevel] ?? 3);
          if (riskCmp != 0) return riskCmp;
          return b.timestamp.compareTo(a.timestamp);
        });

        return Column(
          children: [
            _buildFilterBar(all, hasReviewed),
            Expanded(
              child: cases.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Cap card width on wide (web/tablet) screens so
                        // cases form a grid instead of stretching edge to
                        // edge; on narrow phones just use what's available.
                        final available = constraints.maxWidth - 48;
                        final cardWidth =
                            available < 340 ? available : 340.0;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: cases
                                .map((c) => SizedBox(
                                      width: cardWidth,
                                      child: _buildCaseCard(context, c),
                                    ))
                                .toList(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(List<FlaggedCase> all, bool hasReviewed) {
    final pending = all.where((c) => !c.reviewed).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _buildStatChip(pending),
          const Spacer(),
          if (hasReviewed)
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

  Widget _buildStatChip(int pending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
    return _CaseCard(flaggedCase: flaggedCase);
  }
}

/// A single flagged-case card. Quick-classify taps only stage a pending
/// selection locally — nothing is written to Firestore until the clinician
/// taps the confirm checkmark, so a stray tap can't silently reclassify a
/// patient's case.
class _CaseCard extends StatefulWidget {
  final FlaggedCase flaggedCase;

  const _CaseCard({required this.flaggedCase});

  @override
  State<_CaseCard> createState() => _CaseCardState();
}

class _CaseCardState extends State<_CaseCard> {
  late RiskLevel _pending;
  bool _isConfirming = false;

  RiskLevel get _persisted =>
      widget.flaggedCase.clinicianClassification ?? widget.flaggedCase.riskLevel;

  @override
  void initState() {
    super.initState();
    _pending = _persisted;
  }

  @override
  void didUpdateWidget(covariant _CaseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep pending in sync with Firestore updates (e.g. confirmed from
    // another device) as long as the clinician hasn't made an unconfirmed
    // local pick on this card yet.
    final oldPersisted =
        oldWidget.flaggedCase.clinicianClassification ?? oldWidget.flaggedCase.riskLevel;
    if (_pending == oldPersisted && _persisted != oldPersisted) {
      _pending = _persisted;
    }
  }

  bool get _isDirty => _pending != _persisted;

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    try {
      await FirestoreService().markReviewed(
        widget.flaggedCase.id,
        widget.flaggedCase.reviewerNotes,
        classification: _pending,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirmed as ${_pending.label} and marked reviewed'),
            backgroundColor: AppColors.riskLow,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: AppColors.riskHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flaggedCase = widget.flaggedCase;
    final dateStr =
        DateFormat('d MMM yyyy — HH:mm').format(flaggedCase.timestamp);
    final hasImage =
        flaggedCase.imageUrl != null && flaggedCase.imageUrl!.isNotEmpty;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaseDetailScreen(flaggedCase: flaggedCase),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: flaggedCase.reviewed
                ? AppColors.cardBorder
                : _persisted.color.withOpacity(0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: hasImage
                  ? Image.network(
                      flaggedCase.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : Container(
                                  color: AppColors.background,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.accent, strokeWidth: 2),
                                  ),
                                ),
                    )
                  : _imagePlaceholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontSize: 14),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              dateStr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      RiskBadge(riskLevel: _persisted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildQuickClassifyRow(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (flaggedCase.reviewed) ...[
                        const Icon(Icons.check_circle,
                            size: 13, color: AppColors.riskLow),
                        const SizedBox(width: 4),
                        Text(
                          'Reviewed',
                          style: TextStyle(
                            color: AppColors.riskLow,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _persisted.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Awaiting review',
                          style: TextStyle(
                            color: _persisted.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: AppColors.textSecondary, size: 32),
      ),
    );
  }

  Widget _buildQuickClassifyRow() {
    if (widget.flaggedCase.reviewed) {
      return _buildLockedClassification();
    }
    return Row(
      children: [
        Expanded(child: _quickClassifyChip(RiskLevel.low, 'Low')),
        const SizedBox(width: 6),
        Expanded(child: _quickClassifyChip(RiskLevel.moderate, 'Moderate')),
        const SizedBox(width: 6),
        Expanded(child: _quickClassifyChip(RiskLevel.high, 'High')),
        const SizedBox(width: 6),
        _buildConfirmButton(),
      ],
    );
  }

  // Once reviewed, the classification is locked — no more quick-select
  // chips, just a confirmed indicator. Changing it again requires opening
  // the case detail screen.
  Widget _buildLockedClassification() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _persisted.backgroundColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _persisted.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 12, color: _persisted.color),
          const SizedBox(width: 6),
          Text(
            '${_persisted.label} — confirmed',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _persisted.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickClassifyChip(RiskLevel level, String label) {
    final selected = _pending == level;
    return GestureDetector(
      onTap: () => setState(() => _pending = level),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? level.color : AppColors.background,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: selected ? level.color : AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: (_isDirty && !_isConfirming) ? _confirm : null,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isDirty ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: _isDirty ? AppColors.accent : AppColors.cardBorder),
        ),
        child: _isConfirming
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                Icons.check,
                size: 16,
                color: _isDirty ? Colors.white : AppColors.textSecondary,
              ),
      ),
    );
  }
}
