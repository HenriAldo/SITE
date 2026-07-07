import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/symptom_response.dart';
import '../../shared/widgets/check_in_step_indicator.dart';
import 'analyzing_screen.dart';

class SymptomQuestionnaireScreen extends StatefulWidget {
  final File image;
  /// Prefills the form when returning here via "Try Again" from an
  /// undetected result, so the patient doesn't re-enter the same answers.
  final SymptomResponse? initialSymptoms;

  const SymptomQuestionnaireScreen({
    super.key,
    required this.image,
    this.initialSymptoms,
  });

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
  final Set<String> _extraSymptoms = {};
  late final _notesController = TextEditingController(
      text: widget.initialSymptoms?.additionalNotes ?? '');

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // The searchable "add more symptoms" list — the 6 built-in tiles above
  // (fever, chills, pain, redness, swelling, discharge) are intentionally
  // excluded so nothing appears twice.
  static const List<String> _extraSymptomOptions = [
    'Fatigue',
    'Weakness',
    'Unintentional weight loss',
    'Loss of appetite',
    'Night sweats',
    'Warmth at the exit site',
    'Skin breakdown or crusting at the site',
    'Swelling of the arm, neck, or face',
    'Visible collateral (surface) veins on the chest',
    'Difficulty flushing or drawing blood from the line',
    'Leaking from the catheter hub or site',
    'Hypotension',
    'Tachycardia',
    'Confusion or altered mental status',
    'Nausea',
    'Vomiting',
    'Mucositis (mouth sores)',
    'Bruising or unusual bleeding',
    'Pallor',
    'Recurrent infections',
    'Shortness of breath',
    'Chest pain',
    'Cough',
    'Numbness or tingling near the collarbone',
    'Jaundice',
    'Abdominal swelling or pain',
    'Bone pain',
    'Headache',
    'Neurological deficits (weakness, vision changes, speech changes)',
    'Constipation',
    'Increased urination',
    'Hair loss',
    'Rash',
    'Peripheral neuropathy (numbness/tingling in hands or feet)',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSymptoms;
    if (initial != null) {
      _hasSymptoms = initial.hasSymptoms;
      _hasFever = initial.hasFever;
      _hasPain = initial.hasPain;
      _hasSwelling = initial.hasSwelling;
      _hasRedness = initial.hasRedness;
      _hasDrainage = initial.hasDrainage;
      _hasChills = initial.hasChills;
      _extraSymptoms.addAll(initial.extraSymptoms);
    }
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A symptom is anything unusual you feel or notice on your '
                  'body — for example fever, chills, swelling, redness, or '
                  'pain around the catheter site.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
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
          'Tap all that apply.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            // Fixed 3-column grid so the 6 core symptoms fill the row
            // edge-to-edge instead of clumping at a fixed tile width.
            const columns = 3;
            const spacing = 10.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _buildSymptomBox(
                  label: 'Fever',
                  icon: Icons.thermostat_outlined,
                  value: _hasFever,
                  width: tileWidth,
                  onTap: () => setState(() => _hasFever = !_hasFever),
                ),
                _buildSymptomBox(
                  label: 'Chills',
                  icon: Icons.ac_unit_outlined,
                  value: _hasChills,
                  width: tileWidth,
                  onTap: () => setState(() => _hasChills = !_hasChills),
                ),
                _buildSymptomBox(
                  label: 'Pain at site',
                  icon: Icons.pin_drop_outlined,
                  value: _hasPain,
                  width: tileWidth,
                  onTap: () => setState(() => _hasPain = !_hasPain),
                ),
                _buildSymptomBox(
                  label: 'Redness',
                  customIcon: _buildRednessIcon(),
                  value: _hasRedness,
                  width: tileWidth,
                  onTap: () => setState(() => _hasRedness = !_hasRedness),
                ),
                _buildSymptomBox(
                  label: 'Swelling',
                  icon: Icons.water_outlined,
                  value: _hasSwelling,
                  width: tileWidth,
                  onTap: () => setState(() => _hasSwelling = !_hasSwelling),
                ),
                _buildSymptomBox(
                  label: 'Discharge',
                  icon: Icons.opacity_outlined,
                  value: _hasDrainage,
                  width: tileWidth,
                  onTap: () => setState(() => _hasDrainage = !_hasDrainage),
                ),
                for (final extra in _extraSymptoms)
                  _buildSymptomBox(
                    label: extra,
                    icon: Icons.check_circle_outline,
                    value: true,
                    width: tileWidth,
                    onTap: () => setState(() => _extraSymptoms.remove(extra)),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _openAddMoreSymptoms(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add more symptoms'),
        ),
      ],
    );
  }

  Widget _buildSymptomBox({
    required String label,
    required bool value,
    required VoidCallback onTap,
    required double width,
    IconData? icon,
    Widget? customIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // Selected state is a light accent tint, not a solid fill — same
          // language as the Yes/No choice cards above.
          color: value ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? AppColors.accent : AppColors.cardBorder,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon ??
                Icon(
                  icon,
                  size: 26,
                  color: value ? AppColors.accent : AppColors.textSecondary,
                ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: value ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddMoreSymptoms(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddSymptomsSheet(
        options: _extraSymptomOptions,
        initiallySelected: _extraSymptoms,
      ),
    );
    if (result != null) {
      setState(() {
        _extraSymptoms
          ..clear()
          ..addAll(result);
      });
    }
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
            suffixIcon: _speechAvailable
                ? IconButton(
                    tooltip: _isListening ? 'Stop dictation' : 'Dictate notes',
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
        if (_isListening) ...[
          const SizedBox(height: 6),
          Text(
            'Listening…',
            style: TextStyle(color: AppColors.accent, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildRednessIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.white, Colors.grey, Colors.black87],
          stops: [0.0, 0.6, 1.0],
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
      extraSymptoms: _extraSymptoms.toList(),
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

/// Bottom sheet with a search bar for adding symptoms beyond the 6
/// built-in tiles. Returns the final selected set on "Done", or null if
/// dismissed without confirming.
class _AddSymptomsSheet extends StatefulWidget {
  final List<String> options;
  final Set<String> initiallySelected;

  const _AddSymptomsSheet({
    required this.options,
    required this.initiallySelected,
  });

  @override
  State<_AddSymptomsSheet> createState() => _AddSymptomsSheetState();
}

class _AddSymptomsSheetState extends State<_AddSymptomsSheet> {
  late final Set<String> _selected = Set.from(widget.initiallySelected);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) => o.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add more symptoms',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search symptoms…',
                  prefixIcon: const Icon(Icons.search, size: 20),
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
                  fillColor: AppColors.background,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No symptoms match your search.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final selected = _selected.contains(option);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (_) => setState(() {
                            if (selected) {
                              _selected.remove(option);
                            } else {
                              _selected.add(option);
                            }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.accent,
                          title: Text(option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
