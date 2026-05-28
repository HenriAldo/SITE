import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import 'symptom_questionnaire_screen.dart';

class GuidedCaptureScreen extends StatefulWidget {
  const GuidedCaptureScreen({super.key});

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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
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
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStep(1, 'Photo', isActive: true, isCompleted: _capturedImage != null),
        _buildStepLine(),
        _buildStep(2, 'Symptoms', isActive: false),
        _buildStepLine(),
        _buildStep(3, 'Result', isActive: false),
      ],
    );
  }

  Widget _buildStep(int number, String label, {bool isActive = false, bool isCompleted = false}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.teal
                : isActive
                    ? AppColors.teal.withOpacity(0.2)
                    : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive || isCompleted ? AppColors.teal : AppColors.cardBorder,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: isActive ? AppColors.teal : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.teal : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
        color: AppColors.divider,
      ),
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
          _buildGuidelineRow(Icons.light_mode_outlined, 'Good lighting — use natural light if possible'),
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
        Icon(icon, size: 16, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageArea(BuildContext context) {
    if (_capturedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.file(
              _capturedImage!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
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
                  child: const Icon(Icons.refresh, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.teal.withOpacity(0.4), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.teal.withOpacity(0.7)),
            const SizedBox(height: 12),
            Text(
              'Tap to take photo',
              style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w500),
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

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (_capturedImage != null)
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SymptomQuestionnaireScreen(image: _capturedImage!),
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
