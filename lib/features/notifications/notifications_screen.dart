import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
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

  // Cases opened during this visit — cleared immediately on tap so the
  // border updates the moment the patient returns from the detail screen,
  // rather than staying "new" until the whole notifications screen is
  // reopened.
  final Set<String> _viewedIds = {};

  Set<String> _dismissedIds = {};
  bool _dismissedLoaded = false;

  // Captured in didChangeDependencies (not dispose — by then the context
  // is deactivated and .of(context) throws) so the delete/undo snackbar
  // doesn't linger after leaving this screen.
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      FirestoreService().getDismissedNotificationIds(userId).then((ids) {
        if (mounted) {
          setState(() {
            _dismissedIds = ids;
            _dismissedLoaded = true;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _messenger?.clearSnackBars();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: userId == null
          ? const Center(child: Text('Not signed in'))
          : !_dismissedLoaded
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
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

                        final visible = reviewed
                            .where((f) => !_dismissedIds.contains(f.id))
                            .toList();

                        if (visible.isEmpty) return _buildEmpty(context);

                        return ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final flagged = visible[index];
                            final assessment = byId[flagged.id];
                            final level = flagged.clinicianClassification ??
                                flagged.riskLevel;
                            final isNew = !_viewedIds.contains(flagged.id) &&
                                (_lastSeenAtOpen == null ||
                                    flagged.reviewedAt!.isAfter(_lastSeenAtOpen!));

                            return Dismissible(
                              key: ValueKey(flagged.id),
                              direction: DismissDirection.endToStart,
                              background: _buildDismissBackground(),
                              onDismissed: (_) =>
                                  _dismissNotification(userId, flagged),
                              child: _buildTile(
                                context,
                                level: level,
                                reviewedAt: flagged.reviewedAt!,
                                isNew: isNew,
                                onTap: assessment == null
                                    ? null
                                    : () {
                                        setState(() => _viewedIds.add(flagged.id));
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EntryDetailScreen(
                                                assessment: assessment),
                                          ),
                                        );
                                      },
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
      FirestoreService().getNotificationsLastSeen(userId).then((lastSeen) {
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
    FirestoreService()
        .setNotificationsLastSeen(userId, reviewed.first.reviewedAt!);
  }

  Future<void> _dismissNotification(String userId, FlaggedCase flagged) async {
    setState(() => _dismissedIds = {..._dismissedIds, flagged.id});
    await FirestoreService().setDismissedNotificationIds(userId, _dismissedIds);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() => _dismissedIds = {..._dismissedIds}..remove(flagged.id));
            await FirestoreService()
                .setDismissedNotificationIds(userId, _dismissedIds);
          },
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.riskHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
    );
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
            const Icon(Icons.fact_check_outlined, color: AppColors.accent, size: 22),
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
