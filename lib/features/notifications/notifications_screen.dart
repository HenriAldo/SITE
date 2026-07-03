import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
import '../../data/services/notification_prefs.dart';
import '../../shared/widgets/risk_badge.dart';
import '../history/entry_detail_screen.dart';

/// Shows every case the clinician has reviewed, newest first. Opening this
/// screen marks all currently-visible reviews as seen, clearing the Home
/// screen's notification badge.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  DateTime? _lastSeenAtOpen;
  bool _lastSeenLoaded = false;
  bool _lastSeenLoading = false;
  bool _wroteNewSeen = false;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: userId == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<List<Assessment>>(
              stream: FirestoreService().assessmentStream(userId),
              builder: (context, assessSnap) {
                final assessments = assessSnap.data ?? [];
                final byId = {for (final a in assessments) a.id: a};

                return StreamBuilder<List<FlaggedCase>>(
                  stream: FirestoreService().flaggedCasesForUser(userId),
                  builder: (context, flagSnap) {
                    final reviewed = (flagSnap.data ?? [])
                        .where((f) => f.reviewed && f.reviewedAt != null)
                        .toList()
                      ..sort((a, b) => b.reviewedAt!.compareTo(a.reviewedAt!));

                    _syncSeenState(userId, reviewed);

                    if (reviewed.isEmpty) return _buildEmpty(context);

                    return ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: reviewed.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final flagged = reviewed[index];
                        final assessment = byId[flagged.id];
                        final level =
                            flagged.clinicianClassification ?? flagged.riskLevel;
                        final isNew = _lastSeenAtOpen == null ||
                            flagged.reviewedAt!.isAfter(_lastSeenAtOpen!);

                        return _buildTile(
                          context,
                          level: level,
                          reviewedAt: flagged.reviewedAt!,
                          isNew: isNew,
                          onTap: assessment == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EntryDetailScreen(
                                          assessment: assessment),
                                    ),
                                  ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  // Reads the "already seen" threshold exactly once per screen visit, then
  // — only after that read has resolved — advances it to the newest
  // reviewed case so the badge clears. The read must fully complete before
  // the write starts, otherwise the write can race ahead of the read and
  // make every case look already-seen.
  void _syncSeenState(String userId, List<FlaggedCase> reviewed) {
    if (!_lastSeenLoaded) {
      if (_lastSeenLoading) return;
      _lastSeenLoading = true;
      NotificationPrefs.getLastSeen(userId).then((lastSeen) {
        if (!mounted) return;
        setState(() {
          _lastSeenAtOpen = lastSeen;
          _lastSeenLoaded = true;
        });
      });
      return;
    }

    if (_wroteNewSeen || reviewed.isEmpty) return;
    _wroteNewSeen = true;
    NotificationPrefs.setLastSeen(userId, reviewed.first.reviewedAt!);
  }

  Widget _buildTile(
    BuildContext context, {
    required RiskLevel level,
    required DateTime reviewedAt,
    required bool isNew,
    required VoidCallback? onTap,
  }) {
    final dateStr = DateFormat('d MMM yyyy — HH:mm').format(reviewedAt);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isNew ? AppColors.accent : AppColors.cardBorder,
            width: isNew ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.fact_check_outlined, color: AppColors.accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your clinician reviewed your check-in',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(dateStr,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            RiskBadge(riskLevel: level),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            "You'll see an update here when your\nclinician reviews a check-in.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
