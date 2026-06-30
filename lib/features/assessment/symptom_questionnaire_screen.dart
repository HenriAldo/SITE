import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/symptom_response.dart';
import '../../shared/widgets/check_in_step_indicator.dart';
import 'analyzing_screen.dart';

class SymptomQuestionnaireScreen extends StatefulWidget {
  final File image;

  const SymptomQuestionnaireScreen({super.key, required this.image});

  @override
  State<SymptomQuestionnaireScreen> createState() =>
      _SymptomQuestionnaireScreenState();
}

class _SymptomQuestionnaireScreenState
    extends State<SymptomQuestionnaireScreen> {
  bool? _hasSymptoms;
  bool _hasFever = false;
  bool _hasPain = false;
  bool _hasSwelling = false;
  bool _hasRedness = false;
  bool _hasDrainage = false;
  bool _hasChills = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Symptom Check')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CheckInStepIndicator(currentStep: 2, photoDone: true),
                    const SizedBox(height: 28),
                    Text(
                      'How are you feeling?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Think about the last 24 hours.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    _buildMainQuestion(context),
                    if (_hasSymptoms == true) ...[
                      const SizedBox(height: 24),
                      _buildSymptomChecklist(context),
                    ],
                    const SizedBox(height: 24),
                    _buildNotesField(context),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _hasSymptoms == null ? null : _submit,
                child: const Text('Analyse'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainQuestion(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Did you notice any symptoms in the last 24 hours?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildChoiceCard(
                context,
                label: 'Yes',
                icon: Icons.check,
                isSelected: _hasSymptoms == true,
                onTap: () => setState(() => _hasSymptoms = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildChoiceCard(
                context,
                label: 'No',
                icon: Icons.close,
                isSelected: _hasSymptoms == false,
                onTap: () => setState(() => _hasSymptoms = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomChecklist(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Which symptoms are you experiencing?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Select all that apply.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildSymptomTile(
          'Fever',
          'Temperature above 38°C',
          Icons.thermostat_outlined,
          _hasFever,
          (v) => setState(() => _hasFever = v),
        ),
        _buildSymptomTile(
          'Chills or shivering',
          'Sudden cold feeling or shaking',
          Icons.ac_unit_outlined,
          _hasChills,
          (v) => setState(() => _hasChills = v),
        ),
        _buildSymptomTile(
          'Pain at the catheter site',
          'Tenderness or discomfort around the line',
          Icons.pin_drop_outlined,
          _hasPain,
          (v) => setState(() => _hasPain = v),
        ),
        _buildSymptomTile(
          'Redness',
          'Skin around the catheter appears red',
          Icons.circle_outlined,
          _hasRedness,
          (v) => setState(() => _hasRedness = v),
        ),
        _buildSymptomTile(
          'Swelling',
          'Area around catheter feels puffy',
          Icons.water_outlined,
          _hasSwelling,
          (v) => setState(() => _hasSwelling = v),
        ),
        _buildSymptomTile(
          'Discharge or leaking',
          'Fluid or crusting around the catheter',
          Icons.opacity_outlined,
          _hasDrainage,
          (v) => setState(() => _hasDrainage = v),
        ),
      ],
    );
  }

  Widget _buildNotesField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anything else to add?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Optional — describe anything unusual you noticed…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.accent),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomTile(
    String label,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? AppColors.accent.withOpacity(0.5) : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: value ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: value ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.accent,
              side: BorderSide(color: AppColors.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final symptoms = SymptomResponse(
      hasSymptoms: _hasSymptoms ?? false,
      hasFever: _hasFever,
      hasChills: _hasChills,
      hasPain: _hasPain,
      hasRedness: _hasRedness,
      hasSwelling: _hasSwelling,
      hasDrainage: _hasDrainage,
      additionalNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          image: widget.image,
          symptoms: symptoms,
        ),
      ),
    );
  }
}
