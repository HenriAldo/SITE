import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/firestore_service.dart';
import '../../data/models/assessment.dart';
import '../../shared/utils/time_ago.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/skeleton.dart';
import 'case_detail_screen.dart';
import 'clinician_profile_screen.dart';
import 'patients_screen.dart';

class ClinicianDashboardScreen extends StatefulWidget {
  const ClinicianDashboardScreen({super.key});

  @override
  State<ClinicianDashboardScreen> createState() =>
      _ClinicianDashboardScreenState();
}

class _ClinicianDashboardScreenState extends State<ClinicianDashboardScreen> {
  bool _showReviewed = false;
  // Null = show all risk levels; otherwise only cases at this level.
  RiskLevel? _riskFilter;
  int _index = 0;
  // Currently-open case in the wide-screen master-detail side pane.
  FlaggedCase? _selectedCase;
  final ScrollController _listScrollController = ScrollController();

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _selectCase(FlaggedCase c) {
    setState(() => _selectedCase = c);
    // Selected case is pinned to the top of the list — jump there so it's
    // visible without the clinician having to scroll manually.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listScrollController.hasClients) {
        _listScrollController.jumpTo(0);
      }
    });
  }

  static const _riskGroupOrder = [
    RiskLevel.high,
    RiskLevel.moderate,
    RiskLevel.low,
    RiskLevel.undetected,
  ];

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _index,
      children: [
        _buildFlaggedTab(),
        const PatientsScreen(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.accent.withValues(alpha: 0.10),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_red_eye_outlined,
                color: AppColors.accent, size: 22),
            const SizedBox(width: 8),
            Text(
              'SITE',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
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
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Wide (web/tablet): left rail; narrow (phone): bottom bar.
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.surface,
                  // Explicit indicator color — without it, the selection
                  // pill defaults close enough to the accent icon color on
                  // top of it that the selected icon disappears into it.
                  indicatorColor: AppColors.accent.withValues(alpha: 0.15),
                  selectedIconTheme:
                      const IconThemeData(color: AppColors.accent),
                  unselectedIconTheme:
                      IconThemeData(color: AppColors.textSecondary),
                  selectedLabelTextStyle:
                      const TextStyle(color: AppColors.accent),
                  unselectedLabelTextStyle:
                      TextStyle(color: AppColors.textSecondary),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.flag_outlined),
                      label: Text('Flagged'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      label: Text('Patients'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          }
          return content;
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width >= 900
          ? null
          : BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              selectedItemColor: AppColors.accent,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.flag_outlined),
                  label: 'Flagged',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  label: 'Patients',
                ),
              ],
            ),
    );
  }

  Widget _buildFlaggedTab() {
    return StreamBuilder<List<FlaggedCase>>(
      stream: FirestoreService().flaggedCasesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSkeletonGrid();
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

        var cases = _showReviewed
            ? all
            : all.where((c) => !c.reviewed).toList();
        if (_riskFilter != null) {
          cases = cases.where((c) => c.riskLevel == _riskFilter).toList();
        }

        // Keep the open side-pane case in sync with the latest stream data.
        final selected = _selectedCase == null
            ? null
            : all.cast<FlaggedCase?>().firstWhere(
                  (c) => c?.id == _selectedCase!.id,
                  orElse: () => null,
                );

        return Column(
          children: [
            _buildFilterBar(all, hasReviewed),
            Expanded(
              child: cases.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Wide, nothing selected: fill the whole width with
                        // the grid rather than a narrow list + placeholder.
                        if (constraints.maxWidth >= 760 && selected == null) {
                          final cardWidth =
                              constraints.maxWidth - 48 < 340
                                  ? constraints.maxWidth - 48
                                  : 340.0;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildRiskGroups(
                                cases,
                                cardWidth,
                                onOpen: _selectCase,
                              ),
                            ),
                          );
                        }
                        // Wide, something selected: master-detail (list
                        // left, detail right), selected case pinned to top
                        // of the list with its photo hidden (already shown
                        // large in the detail pane).
                        if (constraints.maxWidth >= 760) {
                          final rest =
                              cases.where((c) => c.id != selected!.id).toList();
                          return Row(
                            children: [
                              SizedBox(
                                width: 400,
                                child: SingleChildScrollView(
                                  controller: _listScrollController,
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Pinned to the top of the list; its
                                      // photo is hidden since it's already
                                      // shown large in the detail pane.
                                      _buildCaseCard(
                                        context,
                                        selected!,
                                        onOpen: () => _selectCase(selected),
                                        selected: true,
                                        hidePhoto: true,
                                      ),
                                      const SizedBox(height: 20),
                                      ..._buildRiskGroups(
                                        rest,
                                        double.infinity,
                                        onOpen: _selectCase,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: CaseDetailScreen(
                                  key: ValueKey(selected.id),
                                  flaggedCase: selected,
                                  embedded: true,
                                ),
                              ),
                            ],
                          );
                        }
                        // Narrow: grid of cards that push the detail screen.
                        final available = constraints.maxWidth - 48;
                        final cardWidth =
                            available < 340 ? available : 340.0;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildRiskGroups(cases, cardWidth),
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

  // Groups cases under risk-level section headers (high → undetected),
  // newest first within each group.
  List<Widget> _buildRiskGroups(List<FlaggedCase> cases, double cardWidth,
      {void Function(FlaggedCase)? onOpen, String? selectedId}) {
    final widgets = <Widget>[];
    for (final level in _riskGroupOrder) {
      final group = cases.where((c) => c.riskLevel == level).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (group.isEmpty) continue;

      widgets.add(Padding(
        padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 20, bottom: 12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: level.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '${level.label} (${group.length})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ));
      widgets.add(Wrap(
        spacing: 16,
        runSpacing: 16,
        children: group
            .map((c) => SizedBox(
                  width: cardWidth,
                  child: _buildCaseCard(
                    context,
                    c,
                    onOpen: onOpen == null ? null : () => onOpen(c),
                    selected: selectedId != null && c.id == selectedId,
                  ),
                ))
            .toList(),
      ));
    }
    return widgets;
  }

  Widget _buildFilterBar(List<FlaggedCase> all, bool hasReviewed) {
    final pending = all.where((c) => !c.reviewed).toList();
    final high = pending.where((c) => c.riskLevel == RiskLevel.high).length;
    final mod = pending.where((c) => c.riskLevel == RiskLevel.moderate).length;
    final low = pending.where((c) => c.riskLevel == RiskLevel.low).length;
    final patients = all.map((c) => c.userId).toSet().length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (high > 0) _countPill('$high high pending', AppColors.riskHigh),
                if (mod > 0)
                  _countPill('$mod moderate pending', AppColors.riskModerate),
                if (low > 0) _countPill('$low low pending', AppColors.riskLow),
                if (high + mod + low == 0)
                  _countPill('All reviewed', AppColors.riskLow),
                _plainPill('$patients patient${patients == 1 ? '' : 's'}'),
              ],
            ),
          ),
          _riskFilterChip(RiskLevel.high, 'High'),
          const SizedBox(width: 6),
          _riskFilterChip(RiskLevel.moderate, 'Moderate'),
          const SizedBox(width: 6),
          _riskFilterChip(RiskLevel.low, 'Low'),
          if (hasReviewed) ...[
            const SizedBox(width: 12),
            Text(
              'Show reviewed',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 13),
            ),
            const SizedBox(width: 4),
            Switch(
              value: _showReviewed,
              onChanged: (v) => setState(() => _showReviewed = v),
              activeThumbColor: AppColors.accent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _riskFilterChip(RiskLevel level, String label) {
    final selected = _riskFilter == level;
    return GestureDetector(
      onTap: () => setState(() {
        _riskFilter = selected ? null : level;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? level.color : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: selected ? level.color : AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _countPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _plainPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - 48;
        final cardWidth = available < 340 ? available : 340.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              4,
              (_) => SizedBox(width: cardWidth, child: const SkeletonCaseCard()),
            ),
          ),
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

  Widget _buildCaseCard(BuildContext context, FlaggedCase flaggedCase,
      {VoidCallback? onOpen, bool selected = false, bool hidePhoto = false}) {
    return _CaseCard(
      flaggedCase: flaggedCase,
      onOpen: onOpen,
      selected: selected,
      hidePhoto: hidePhoto,
    );
  }
}

/// A single flagged-case card. Quick-classify taps only stage a pending
/// selection locally — nothing is written to Firestore until the clinician
/// taps the confirm checkmark, so a stray tap can't silently reclassify a
/// patient's case.
class _CaseCard extends StatefulWidget {
  final FlaggedCase flaggedCase;
  /// Opening action — select in a side pane (wide) or push (narrow).
  final VoidCallback? onOpen;
  /// Highlighted as the currently-open case in master-detail mode.
  final bool selected;
  /// Hides the thumbnail — used when the same photo is already shown large
  /// in the detail pane, so the pinned "selected" list entry doesn't repeat it.
  final bool hidePhoto;

  const _CaseCard({
    required this.flaggedCase,
    this.onOpen,
    this.selected = false,
    this.hidePhoto = false,
  });

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
    // Captured before the write so Undo can restore the exact prior state.
    final caseId = widget.flaggedCase.id;
    final priorClassification = widget.flaggedCase.clinicianClassification;
    final confirmedLevel = _pending;
    try {
      await FirestoreService().markReviewed(
        caseId,
        widget.flaggedCase.reviewerNotes,
        classification: confirmedLevel,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirmed as ${confirmedLevel.label} and marked reviewed'),
            backgroundColor: AppColors.riskLow,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () => FirestoreService().revertReview(
                caseId,
                classification: priorClassification,
              ),
            ),
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
    final dateStr = timeAgo(flaggedCase.timestamp);
    final hasImage =
        flaggedCase.imageUrl != null && flaggedCase.imageUrl!.isNotEmpty;

    return InkWell(
      onTap: widget.onOpen ??
          () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CaseDetailScreen(flaggedCase: flaggedCase),
                ),
              ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        // Border painted on the outer, unclipped box; content is clipped
        // separately below via ClipRRect. Keeping clipping and border
        // painting on the same Container can leave a visible seam at the
        // rounded corners where a flush-edge child (like the high-risk
        // stripe) meets the radius.
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.selected
                ? AppColors.accent
                : flaggedCase.reviewed
                    ? AppColors.cardBorder
                    : _persisted.color.withValues(alpha: 0.3),
            width: widget.selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!flaggedCase.reviewed && _persisted == RiskLevel.high)
              Container(
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.riskHigh,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(13),
                  ),
                ),
              ),
            if (!widget.hidePhoto)
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
                  _buildSymptomSummary(context),
                  const SizedBox(height: 8),
                  _buildQuickClassifyRow(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (flaggedCase.reviewed) ...[
                        const Icon(Icons.check_circle,
                            size: 13, color: AppColors.riskLow),
                        const SizedBox(width: 4),
                        const Text(
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
                          'Awaiting · ${elapsedShort(flaggedCase.timestamp)}',
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

  // Compact one-line summary of the patient-reported symptoms so the
  // clinician can quick-classify without opening the detail screen.
  Widget _buildSymptomSummary(BuildContext context) {
    final s = widget.flaggedCase.symptoms;
    final reported = s == null
        ? <String>[]
        : [
            if (s.hasFever) 'Fever',
            if (s.hasChills) 'Chills',
            if (s.hasPain) 'Pain',
            if (s.hasRedness) 'Redness',
            if (s.hasSwelling) 'Swelling',
            if (s.hasDrainage) 'Discharge',
            ...s.extraSymptoms,
          ];

    final String text;
    if (s == null) {
      text = 'No symptom data';
    } else if (!s.hasSymptoms || reported.isEmpty) {
      text = 'No symptoms reported';
    } else {
      text = reported.join(', ');
    }

    return Row(
      children: [
        Icon(Icons.monitor_heart_outlined,
            size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
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
        border: Border.all(color: _persisted.color.withValues(alpha: 0.4)),
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
