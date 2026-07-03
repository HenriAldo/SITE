import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/symptom_response.dart';
import '../../shared/widgets/check_in_step_indicator.dart';
import '../../shared/widgets/zoomable_image.dart';
import 'symptom_questionnaire_screen.dart';

class GuidedCaptureScreen extends StatefulWidget {
  /// When returning here from "Try Again" on an undetected result, the
  /// previous symptom answers are carried along so the questionnaire can
  /// be prefilled once the user retakes the photo.
  final SymptomResponse? initialSymptoms;

  const GuidedCaptureScreen({super.key, this.initialSymptoms});

  @override
  State<GuidedCaptureScreen> createState() => _GuidedCaptureScreenState();
}

class _GuidedCaptureScreenState extends State<GuidedCaptureScreen> {
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Check-In'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _exitCheckIn(context),
        ),
      ),
      body: SafeArea(
        child: _capturedImage == null
            ? _buildFixedLayout(context)
            : _buildScrollableLayout(context),
      ),
    );
  }

  // Before a photo is taken, content reliably fits on screen — keep it a
  // static (non-scrolling) layout.
  Widget _buildFixedLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 28),
          Text(
            'Photograph your\ncatheter exit site',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure the insertion point where the catheter enters your skin is clearly visible.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildGuidelines(context),
          const SizedBox(height: 24),
          _buildImageArea(context),
          const Spacer(),
          _buildActions(context),
        ],
      ),
    );
  }

  // Leaving the check-in entirely (via the top-bar X) loses the photo, so
  // confirm first — but only once there's actually something to lose.
  Future<void> _exitCheckIn(BuildContext context) async {
    if (_capturedImage == null) {
      Navigator.pop(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard this check-in?'),
        content: const Text(
          'Your photo and any symptoms you\'ve entered will be lost if you leave now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: TextStyle(color: AppColors.riskHigh)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  // Once a photo is captured, the review image's height can vary — scroll
  // to guarantee it never overflows the screen.
  Widget _buildScrollableLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 28),
                Text(
                  'Photograph your\ncatheter exit site',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure the insertion point where the catheter enters your skin is clearly visible.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _buildGuidelines(context),
                const SizedBox(height: 24),
                _buildImageArea(context),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: _buildActions(context),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return CheckInStepIndicator(
      currentStep: 1,
      photoDone: _capturedImage != null,
    );
  }

  Widget _buildGuidelines(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _buildGuidelineRow(Icons.light_mode_outlined, 'Good lighting — use flash if possible'),
          const SizedBox(height: 10),
          _buildGuidelineRow(Icons.center_focus_strong_outlined, 'Hold 15–20 cm from the site'),
          const SizedBox(height: 10),
          _buildGuidelineRow(Icons.visibility_outlined, 'Entire dressing and surrounding skin visible'),
        ],
      ),
    );
  }

  Widget _buildGuidelineRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageArea(BuildContext context) {
    if (_capturedImage != null) return _buildReviewArea();

    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.4), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.accent.withOpacity(0.7)),
            const SizedBox(height: 12),
            Text(
              'Tap to take photo',
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'or choose from gallery',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewArea() {
    return Stack(
      children: [
        ZoomableImage(
          file: _capturedImage,
          heroTag: 'guided-capture-preview',
          aspectRatio: 16 / 9,
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => setState(() => _capturedImage = null),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (_capturedImage != null)
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SymptomQuestionnaireScreen(
                  image: _capturedImage!,
                  initialSymptoms: widget.initialSymptoms,
                ),
              ),
            ),
            child: const Text('Continue to Symptoms'),
          )
        else ...[
          ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Take Photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _pickFromGallery,
            child: const Text('Choose from Gallery'),
          ),
        ],
      ],
    );
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo != null) {
      setState(() => _capturedImage = File(photo.path));
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (photo != null) {
      setState(() => _capturedImage = File(photo.path));
    }
  }
}
