import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/patient_profile.dart';
import '../../data/services/firestore_service.dart';

/// The clinician's own contact details. Saving here updates what every
/// assigned patient sees in their Care Team screen — there's no per-patient
/// copy to keep in sync.
class ClinicianProfileScreen extends StatefulWidget {
  const ClinicianProfileScreen({super.key});

  @override
  State<ClinicianProfileScreen> createState() =>
      _ClinicianProfileScreenState();
}

class _ClinicianProfileScreenState extends State<ClinicianProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _clinicController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  String get _clinicianId => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contact = await FirestoreService().getClinicianContact(_clinicianId);
    if (contact != null) {
      _nameController.text = contact.clinicianName;
      _phoneController.text = contact.phone;
      _clinicController.text = contact.clinic;
    } else {
      _nameController.text =
          FirebaseAuth.instance.currentUser?.displayName ?? '';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _clinicController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await FirestoreService().saveClinicianContact(
        _clinicianId,
        ClinicianContact(
          clinicianName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          clinic: _clinicController.text.trim(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Saved — every assigned patient will see the update.'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contact Details'),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'These details are shown to every patient assigned to '
                      'you. Updating them here updates it everywhere '
                      'automatically.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        hintText: 'e.g. Dr. Müller',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        hintText: 'e.g. +49 89 1234 5678',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _clinicController,
                      decoration: const InputDecoration(
                        labelText: 'Clinic / practice',
                        hintText: 'e.g. Onkologie Station 4, LMU München',
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
