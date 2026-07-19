import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/patient_profile.dart';
import '../../data/services/firestore_service.dart';

class ProfileEditScreen extends StatefulWidget {
  final PatientProfile? existing;
  /// If provided, saves to this patient's userId instead of the logged-in user.
  final String? targetUserId;
  /// Display label shown in the app bar when editing another patient.
  final String? patientLabel;

  const ProfileEditScreen({
    super.key,
    this.existing,
    this.targetUserId,
    this.patientLabel,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // A clinician editing a patient's profile can see/change everything;
  // a patient editing their own profile may only change catheter type
  // and care team — clinical context and the insertion date are set by
  // the clinician.
  bool get _isClinicianEditing => widget.targetUserId != null;

  // Clinical fields
  late TextEditingController _ageController;
  late TextEditingController _diagnosisController;
  late TextEditingController _comorbiditiesController;
  String _catheterType = 'PICC';
  DateTime _insertionDate = DateTime.now();
  bool _isImmunosuppressed = false;

  // Preserved as-is when the patient (not the clinician) is editing.
  String? _existingLastLabSummary;

  static const List<String> _catheterTypes = [
    'PICC',
    'Hickman',
    'Broviac',
    'Port-a-Cath',
    'Other CVC',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _ageController = TextEditingController(
        text: p != null && p.age > 0 ? '${p.age}' : '');
    _diagnosisController = TextEditingController(text: p?.diagnosis ?? '');
    _comorbiditiesController = TextEditingController(
        text: p?.comorbidities.join(', ') ?? '');
    _existingLastLabSummary = p?.lastLabSummary;
    _catheterType = p?.catheterType ?? 'PICC';
    _insertionDate = p?.insertionDate ?? DateTime.now();
    _isImmunosuppressed = p?.isImmunosuppressed ?? false;
  }

  @override
  void dispose() {
    _ageController.dispose();
    _diagnosisController.dispose();
    _comorbiditiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientLabel != null
            ? 'Profile — ${widget.patientLabel}'
            : widget.existing == null
                ? 'Set Up Profile'
                : 'Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  )
                : const Text('Save',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Catheter'),
              const SizedBox(height: 12),
              _buildCatheterTypeField(),
              const SizedBox(height: 14),
              if (_isClinicianEditing)
                _buildInsertionDateField(context)
              else
                _readOnlyRow('Insertion date',
                    DateFormat('d MMMM yyyy').format(_insertionDate)),
              const SizedBox(height: 24),
              _sectionHeader('Clinical Context'),
              const SizedBox(height: 12),
              if (_isClinicianEditing) ...[
                _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter your age' : null,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _diagnosisController,
                  label: 'Diagnosis',
                  hint: 'e.g. DLBCL on R-CHOP',
                ),
                const SizedBox(height: 14),
                _buildImmunosuppressionField(),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _comorbiditiesController,
                  label: 'Comorbidities',
                  hint: 'e.g. Hypertension, Diabetes (comma-separated)',
                ),
              ] else ...[
                if (_ageController.text.isNotEmpty)
                  _readOnlyRow('Age', _ageController.text),
                if (_diagnosisController.text.isNotEmpty)
                  _readOnlyRow('Diagnosis', _diagnosisController.text),
                _readOnlyRow('Immunosuppressed',
                    _isImmunosuppressed ? 'Yes' : 'No'),
                if (_comorbiditiesController.text.isNotEmpty)
                  _readOnlyRow('Comorbidities', _comorbiditiesController.text),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: const Text('Save Profile'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: validator,
    );
  }

  Widget _buildCatheterTypeField() {
    return DropdownButtonFormField<String>(
      initialValue: _catheterType,
      dropdownColor: AppColors.surface,
      decoration: const InputDecoration(labelText: 'Catheter type'),
      items: _catheterTypes
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (v) => setState(() => _catheterType = v ?? 'PICC'),
    );
  }

  Widget _buildInsertionDateField(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _insertionDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.accent),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _insertionDate = picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Insertion date',
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
          ),
          controller: TextEditingController(
            text: DateFormat('d MMMM yyyy').format(_insertionDate),
          ),
        ),
      ),
    );
  }

  Widget _buildImmunosuppressionField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Immunosuppressed',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Switch(
            value: _isImmunosuppressed,
            onChanged: (v) => setState(() => _isImmunosuppressed = v),
            activeThumbColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final comorbidities = _comorbiditiesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Save to target patient if set (clinician editing), otherwise own profile
    final userId = widget.targetUserId ??
        FirebaseAuth.instance.currentUser?.uid;

    // When a clinician edits a patient's profile, the signed-in user is the
    // clinician, not the patient — use the patient's own label instead of
    // falling back to the clinician's Auth displayName. Otherwise, prefer
    // Firestore's users/{uid}.display_name (the source clinicians read)
    // over Firebase Auth's own displayName.
    final name = widget.patientLabel ??
        (userId != null ? await FirestoreService().getDisplayName(userId) : '');
    final resolvedName = name.isNotEmpty
        ? name
        : FirebaseAuth.instance.currentUser?.displayName ?? '';

    final profile = PatientProfile(
      name: resolvedName,
      age: int.tryParse(_ageController.text.trim()) ?? 0,
      catheterType: _catheterType,
      insertionDate: _insertionDate,
      diagnosis: _diagnosisController.text.trim(),
      isImmunosuppressed: _isImmunosuppressed,
      comorbidities: comorbidities,
      lastLabSummary: _existingLastLabSummary,
    );

    try {
      if (userId != null) {
        await FirestoreService().saveProfile(userId, profile);
      }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, true); // return true = saved
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save profile: $e'),
            backgroundColor: AppColors.riskHigh,
          ),
        );
      }
    }
  }
}
