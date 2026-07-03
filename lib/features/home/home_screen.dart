import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/notification_prefs.dart';
import '../../shared/widgets/risk_badge.dart';
import '../assessment/guided_capture_screen.dart';
import '../history/entry_detail_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/faq_screen.dart';
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
        Row(
          children: [
            const _NotificationBell(),
            const SizedBox(width: 10),
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
        // Only count scans where a central line was actually detected;
        // failed/no-detection scans should not block the daily retake.
        final validToday = assessments.any(
            (a) => a.centralLineDetected && _isToday(a.timestamp));
        return validToday
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
          const SizedBox(height: 16),
          _build116117Notice(context),
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
                const SizedBox(height: 16),
                _build116117Notice(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build116117Notice(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri(scheme: 'tel', path: '116117')),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 12, color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'In doubt? Call '),
                  TextSpan(
                    text: '116117',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' — the medical on-call service.'),
                ],
              ),
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

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EntryDetailScreen(assessment: latest)),
          ),
          child: Container(
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
        ),
        );
      },
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Temporarily disabled — see _buildStreakSection below.
        // _buildStreakSection(context),
        // const SizedBox(height: 20),
        _buildFaqButton(context),
      ],
    );
  }

  Widget _buildStreakSection(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

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
            for (final a in assessments) {
              if (!a.centralLineDetected) continue;
              final day =
                  DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
              if (dayLevels.containsKey(day)) continue;
              final flagged = flaggedById[a.id];
              dayLevels[day] = flagged?.clinicianClassification ?? a.riskLevel;
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            bool hasSubmission(DateTime day) => dayLevels.containsKey(day);

            // A streak breaks after one missed local-calendar day. "Today"
            // isn't a miss until the day has actually passed, so start
            // counting from today if it's done, otherwise from yesterday.
            var cursor =
                hasSubmission(today) ? today : today.subtract(const Duration(days: 1));
            var streak = 0;
            while (hasSubmission(cursor)) {
              streak++;
              cursor = cursor.subtract(const Duration(days: 1));
            }

            final days =
                List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));

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
                  children: days
                      .map((day) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: dayLevels[day]?.color ??
                                        AppColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: dayLevels[day] == null
                                        ? Border.all(color: AppColors.cardBorder)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFaqButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FaqScreen()),
      ),
      icon: const Icon(Icons.help_outline, size: 18),
      label: const Text('See FAQ'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}

/// Bell icon showing a dot when the clinician has reviewed a check-in the
/// patient hasn't seen yet. Purely local (SharedPreferences) — no push
/// infrastructure required.
class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<FlaggedCase>>(
      stream: FirestoreService().flaggedCasesForUser(userId),
      builder: (context, flagSnap) {
        final reviewed = (flagSnap.data ?? [])
            .where((f) => f.reviewed && f.reviewedAt != null)
            .toList();

        return FutureBuilder<DateTime?>(
          future: NotificationPrefs.getLastSeen(userId),
          builder: (context, lastSeenSnap) {
            final lastSeen = lastSeenSnap.data;
            final hasUnread = reviewed.any(
                (f) => lastSeen == null || f.reviewedAt!.isAfter(lastSeen));

            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
                if (mounted) setState(() {});
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_outlined,
                        color: AppColors.textSecondary),
                    if (hasUnread)
                      Positioned(
                        top: 9,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.riskHigh,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
