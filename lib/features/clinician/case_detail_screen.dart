import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
import '../../shared/widgets/risk_badge.dart';

class CaseDetailScreen extends StatefulWidget {
  final FlaggedCase flaggedCase;
  /// When shown in a side pane (master-detail) rather than pushed.
  final bool embedded;

  const CaseDetailScreen({
    super.key,
    required this.flaggedCase,
    this.embedded = false,
  });

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _notesController = TextEditingController();
  bool _isSaving = false;
  late bool _reviewed;
  late RiskLevel _classification;
  bool? _reasoningFeedback;

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _reviewed = widget.flaggedCase.reviewed;
    _notesController.text = widget.flaggedCase.reviewerNotes;
    _classification = widget.flaggedCase.clinicianClassification ??
        widget.flaggedCase.riskLevel;
    // Phones already have built-in dictation on the keyboard — only offer
    // the in-app mic (and its permission prompt) on web.
    if (kIsWeb) _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _notesController.text = result.recognizedWords;
          _notesController.selection =
              TextSelection.collapsed(offset: _notesController.text.length);
        });
      },
    );
  }

  @override
  void dispose() {
    if (_isListening) _speech.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReasoningFeedback(bool positive) async {
    setState(() => _reasoningFeedback = positive);
    final clinicianId = FirebaseAuth.instance.currentUser?.uid;
    if (clinicianId == null) return;
    try {
      await FirestoreService().submitReasoningFeedback(
        caseId: widget.flaggedCase.id,
        clinicianId: clinicianId,
        positive: positive,
      );
    } catch (_) {
      // Best-effort — feedback is a nice-to-have, don't disrupt the review.
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy — HH:mm')
        .format(widget.flaggedCase.timestamp);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(widget.flaggedCase.patientName),
        actions: [
          if (!_reviewed)
            TextButton.icon(
              onPressed: _isSaving ? null : _markReviewed,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark reviewed'),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          if (isWide && widget.flaggedCase.imageUrl != null) {
            return _buildWideLayout(context, dateStr);
          }
          return _buildNarrowLayout(context, dateStr);
        },
      ),
    );
  }

  // ── Wide layout (web / tablet): info left, image right ───────

  Widget _buildWideLayout(BuildContext context, String dateStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: scrollable info column
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPatientHeader(context, dateStr),
                const SizedBox(height: 24),
                _buildRiskCard(context),
                const SizedBox(height: 20),
                _buildPhotoHistory(context),
                _buildClassifyRow(context),
                const SizedBox(height: 20),
                _buildNotesCard(context),
                if (widget.flaggedCase.symptoms != null) ...[
                  const SizedBox(height: 20),
                  _buildSymptomsCard(context),
                ],
                const SizedBox(height: 20),
                _buildReasoningCard(context),
                const SizedBox(height: 28),
                if (!_reviewed) _buildMarkReviewedButton(),
                if (_reviewed) _buildReviewedBanner(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Right: sticky image pane
        Container(
          width: 400,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.divider)),
          ),
          child: _buildImagePane(context, sticky: true),
        ),
      ],
    );
  }

  // ── Narrow layout (phone): stacked ───────────────────────────

  Widget _buildNarrowLayout(BuildContext context, String dateStr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPatientHeader(context, dateStr),
          const SizedBox(height: 24),
          if (widget.flaggedCase.imageUrl != null) ...[
            _buildImagePane(context, sticky: false),
            const SizedBox(height: 20),
          ],
          _buildRiskCard(context),
          const SizedBox(height: 20),
          _buildPhotoHistory(context),
          _buildClassifyRow(context),
          const SizedBox(height: 20),
          _buildNotesCard(context),
          if (widget.flaggedCase.symptoms != null) ...[
            const SizedBox(height: 20),
            _buildSymptomsCard(context),
          ],
          const SizedBox(height: 20),
          _buildReasoningCard(context),
          const SizedBox(height: 28),
          if (!_reviewed) _buildMarkReviewedButton(),
          if (_reviewed) _buildReviewedBanner(context),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────

  Widget _buildPatientHeader(BuildContext context, String dateStr) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline,
              color: AppColors.accent, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.flaggedCase.patientName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (widget.flaggedCase.patientAge != null &&
                      widget.flaggedCase.patientAge! > 0)
                    Text(
                      '${widget.flaggedCase.patientAge} y',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // The image pane — used in both layouts.
  // In sticky=true (wide layout) it fills the available height and is not scrollable.
  Widget _buildImagePane(BuildContext context, {required bool sticky}) {
    final imageWidget = widget.flaggedCase.imageUrl != null
        ? GestureDetector(
            onTap: () => _openFullScreenImage(context),
            child: Hero(
              tag: 'case-image-${widget.flaggedCase.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(sticky ? 0 : 14),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: CachedNetworkImage(
                    imageUrl: widget.flaggedCase.imageUrl!,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      if (kDebugMode) debugPrint('── image load error: $error');
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined,
                                  color: AppColors.textSecondary, size: 32),
                              const SizedBox(height: 8),
                              Text('Image unavailable',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    if (sticky) {
      return Stack(
        children: [
          Positioned.fill(child: imageWidget),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.zoom_in, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Tap to zoom',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: imageWidget,
      ),
    );
  }

  void _openFullScreenImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenImageViewer(
          imageUrl: widget.flaggedCase.imageUrl!,
          caseId: widget.flaggedCase.id,
        ),
      ),
    );
  }

  // Recent site photos for this patient so the clinician can judge whether
  // the site is getting better or worse, not just its current state.
  Widget _buildPhotoHistory(BuildContext context) {
    return FutureBuilder<List<Assessment>>(
      future:
          FirestoreService().getRecentAssessments(widget.flaggedCase.userId),
      builder: (context, snap) {
        final withImages = (snap.data ?? [])
            .where((a) => a.imageUrl != null && a.imageUrl!.isNotEmpty)
            .toList();
        // Nothing to compare against — hide the strip entirely.
        if (withImages.length < 2) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photo history',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Most recent first',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: withImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final a = withImages[i];
                  final isCurrent = a.id == widget.flaggedCase.id;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _FullScreenImageViewer(
                            imageUrl: a.imageUrl!, caseId: a.id),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isCurrent
                                    ? AppColors.accent
                                    : AppColors.cardBorder,
                                width: isCurrent ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: a.imageUrl!,
                              width: 110,
                              height: 82,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  width: 110,
                                  height: 82,
                                  color: AppColors.surface),
                              errorWidget: (_, __, ___) => Container(
                                width: 110,
                                height: 82,
                                color: AppColors.surface,
                                child: Icon(Icons.broken_image_outlined,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCurrent
                              ? 'This case'
                              : DateFormat('d MMM').format(a.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isCurrent
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontWeight:
                                isCurrent ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildRiskCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.flaggedCase.riskLevel.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.flaggedCase.riskLevel.color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RiskBadge(riskLevel: widget.flaggedCase.riskLevel, large: true),
          const SizedBox(height: 12),
          Text(
            'Patient message',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            widget.flaggedCase.patientMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'AI Reasoning',
      icon: Icons.psychology_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.flaggedCase.reasoning,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textPrimary, height: 1.6),
          ),
          if (widget.flaggedCase.visualFindings.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text('Visual findings',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...widget.flaggedCase.visualFindings.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: CircleAvatar(
                          radius: 3, backgroundColor: AppColors.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildReasoningFeedbackRow(context),
        ],
      ),
    );
  }

  Widget _buildReasoningFeedbackRow(BuildContext context) {
    return Row(
      children: [
        Text(
          'Was this reasoning helpful?',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _submitReasoningFeedback(true),
          icon: Icon(
            _reasoningFeedback == true
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            size: 18,
            color: _reasoningFeedback == true
                ? AppColors.riskLow
                : AppColors.textSecondary,
          ),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () => _submitReasoningFeedback(false),
          icon: Icon(
            _reasoningFeedback == false
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            size: 18,
            color: _reasoningFeedback == false
                ? AppColors.riskHigh
                : AppColors.textSecondary,
          ),
          visualDensity: VisualDensity.compact,
        ),
        if (_reasoningFeedback != null) ...[
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Thanks — this will be sent to us to improve the model.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClassifyRow(BuildContext context) {
    const levels = [RiskLevel.low, RiskLevel.moderate, RiskLevel.high];

    return _sectionCard(
      context,
      title: 'Clinician Classification',
      icon: Icons.tune_outlined,
      child: Row(
        children: levels.map((level) {
          final selected = _classification == level;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: level != levels.last ? 8 : 0,
              ),
              child: GestureDetector(
                onTap: _reviewed
                    ? null
                    : () => setState(() => _classification = level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? level.backgroundColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? level.color
                          : AppColors.cardBorder,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(level.icon,
                          size: 14,
                          color: selected
                              ? level.color
                              : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        level.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? level.color
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSymptomsCard(BuildContext context) {
    final s = widget.flaggedCase.symptoms!;
    final reported = [
      if (s.hasFever) 'Fever',
      if (s.hasChills) 'Chills or shivering',
      if (s.hasPain) 'Pain at catheter site',
      if (s.hasRedness) 'Redness',
      if (s.hasSwelling) 'Swelling',
      if (s.hasDrainage) 'Discharge or leaking',
      ...s.extraSymptoms,
    ];

    return _sectionCard(
      context,
      title: 'Patient-Reported Symptoms',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!s.hasSymptoms)
            Text('Patient reported no symptoms.',
                style: Theme.of(context).textTheme.bodyMedium)
          else if (reported.isEmpty)
            Text('Symptoms present — none selected.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            ...reported.map(
              (label) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const CircleAvatar(
                        radius: 3, backgroundColor: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(label,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          if (s.additionalNotes != null && s.additionalNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(
              '"${s.additionalNotes}"',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Clinician Notes',
      icon: Icons.edit_note_outlined,
      child: _reviewed
          ? Text(
              _notesController.text.isEmpty
                  ? 'No notes added.'
                  : _notesController.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textPrimary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Add your clinical assessment, decision, or follow-up plan...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    suffixIcon: _speechAvailable
                        ? IconButton(
                            tooltip:
                                _isListening ? 'Stop dictation' : 'Dictate notes',
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                            ),
                            onPressed: _toggleListening,
                          )
                        : null,
                  ),
                ),
                if (_isListening)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Listening…',
                      style: TextStyle(color: AppColors.accent, fontSize: 12),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildMarkReviewedButton() {
    return ElevatedButton.icon(
      onPressed: _isSaving ? null : _markReviewed,
      icon: _isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.check_circle_outline, size: 18),
      label: const Text('Mark as Reviewed'),
    );
  }

  Widget _buildReviewedBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.riskLowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.riskLow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.riskLow, size: 18),
          const SizedBox(width: 10),
          Text(
            'This case has been reviewed.',
            style: TextStyle(
              color: AppColors.riskLow,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markReviewed() async {
    setState(() => _isSaving = true);
    try {
      await FirestoreService().markReviewed(
        widget.flaggedCase.id,
        _notesController.text.trim(),
        classification: _classification,
      );
      if (mounted) {
        // When pushed as its own route, pop back to the dashboard; when
        // embedded in a side pane, stay put (the stream updates in place).
        if (!widget.embedded) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Case marked as reviewed'),
            backgroundColor: AppColors.riskLow,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.riskHigh,
          ),
        );
        setState(() => _isSaving = false);
      }
    }
  }
}

// ── Full-screen image viewer ──────────────────────────────────

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String caseId;

  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.caseId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Image', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Hero(
          tag: 'case-image-$caseId',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 8,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
