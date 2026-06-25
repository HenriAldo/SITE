import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/assessment.dart';
import '../../data/services/firestore_service.dart';
import '../../shared/widgets/risk_badge.dart';

class CaseDetailScreen extends StatefulWidget {
  final FlaggedCase flaggedCase;

  const CaseDetailScreen({super.key, required this.flaggedCase});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _notesController = TextEditingController();
  bool _isSaving = false;
  late bool _reviewed;

  @override
  void initState() {
    super.initState();
    _reviewed = widget.flaggedCase.reviewed;
    _notesController.text = widget.flaggedCase.reviewerNotes;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy — HH:mm')
        .format(widget.flaggedCase.timestamp);

    return Scaffold(
      appBar: AppBar(
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientHeader(context, dateStr),
            const SizedBox(height: 24),
            if (widget.flaggedCase.imageUrl != null)
              _buildImageCard(context),
            if (widget.flaggedCase.imageUrl != null)
              const SizedBox(height: 20),
            _buildRiskCard(context),
            const SizedBox(height: 20),
            _buildFindingsCard(context),
            const SizedBox(height: 20),
            _buildReasoningCard(context),
            const SizedBox(height: 20),
            _buildNotesCard(context),
            const SizedBox(height: 28),
            if (!_reviewed) _buildMarkReviewedButton(),
            if (_reviewed) _buildReviewedBanner(context),
          ],
        ),
      ),
    );
  }

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
              Text(
                widget.flaggedCase.patientName,
                style: Theme.of(context).textTheme.titleLarge,
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

  Widget _buildImageCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: widget.flaggedCase.imageUrl!,
        width: double.infinity,
        height: 260,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 260,
          color: AppColors.surface,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
        errorWidget: (context, url, error) {
          if (kDebugMode) debugPrint('── image load error: $error');
          return Container(
            height: 260,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
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
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
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

  Widget _buildFindingsCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Visual Findings',
      icon: Icons.visibility_outlined,
      child: Column(
        children: widget.flaggedCase.visualFindings
            .map(
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
            )
            .toList(),
      ),
    );
  }

  Widget _buildReasoningCard(BuildContext context) {
    return _sectionCard(
      context,
      title: 'AI Reasoning',
      icon: Icons.psychology_outlined,
      child: Text(
        widget.flaggedCase.reasoning,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textPrimary, height: 1.6),
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
          : TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Add your clinical assessment, decision, or follow-up plan...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
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
      );
      setState(() => _reviewed = true);
      if (mounted) {
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
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
