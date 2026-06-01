import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assessment.dart';
import '../models/patient_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Assessments ──────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _assessments(String userId) =>
      _db.collection('users').doc(userId).collection('assessments');

  /// Saves an assessment for the patient and, if escalated,
  /// also writes to the top-level flagged_cases collection
  /// so clinicians can query across all patients.
  Future<void> saveAssessment(
    String userId,
    Assessment assessment, {
    String? patientName,
    String? patientEmail,
  }) async {
    final batch = _db.batch();

    // Always save to patient's own sub-collection
    final assessmentRef = _assessments(userId).doc(assessment.id);
    batch.set(assessmentRef, assessment.toJson());

    // If escalated → also write to top-level flagged_cases
    if (assessment.escalate) {
      final flaggedRef =
          _db.collection('flagged_cases').doc(assessment.id);
      batch.set(flaggedRef, {
        ...assessment.toJson(),
        'user_id': userId,
        'patient_name': patientName ?? 'Unknown Patient',
        'patient_email': patientEmail ?? '',
        'reviewed': false,
        'reviewer_notes': '',
        'reviewed_at': null,
      });
    }

    await batch.commit();
  }

  Stream<List<Assessment>> assessmentStream(String userId) {
    return _assessments(userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(_assessmentFromDoc)
            .whereType<Assessment>()
            .toList());
  }

  Assessment? _assessmentFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      return Assessment(
        id: data['id'] ?? doc.id,
        timestamp: DateTime.parse(data['timestamp']),
        riskLevel: RiskLevelExtension.fromString(data['risk_level'] ?? 'low'),
        centralLineDetected: data['central_line_detected'] ?? false,
        visualFindings: List<String>.from(data['visual_findings'] ?? []),
        reasoning: data['reasoning'] ?? '',
        patientMessage: data['patient_message'] ?? '',
        escalate: data['escalate'] ?? false,
        imagePath: data['image_path'],
      );
    } catch (_) {
      return null;
    }
  }

  // ── Flagged Cases (clinician) ─────────────────────────────────

  Stream<List<FlaggedCase>> flaggedCasesStream() {
    return _db
        .collection('flagged_cases')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(_flaggedCaseFromDoc)
            .whereType<FlaggedCase>()
            .toList());
  }

  Future<void> markReviewed(String caseId, String notes) async {
    await _db.collection('flagged_cases').doc(caseId).update({
      'reviewed': true,
      'reviewer_notes': notes,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  FlaggedCase? _flaggedCaseFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      return FlaggedCase(
        id: data['id'] ?? doc.id,
        userId: data['user_id'] ?? '',
        patientName: data['patient_name'] ?? 'Unknown',
        patientEmail: data['patient_email'] ?? '',
        timestamp: DateTime.parse(data['timestamp']),
        riskLevel: RiskLevelExtension.fromString(data['risk_level'] ?? 'low'),
        visualFindings: List<String>.from(data['visual_findings'] ?? []),
        reasoning: data['reasoning'] ?? '',
        patientMessage: data['patient_message'] ?? '',
        reviewed: data['reviewed'] ?? false,
        reviewerNotes: data['reviewer_notes'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  // ── User Role ─────────────────────────────────────────────────

  Future<String?> getUserRole(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['role'] as String?;
  }

  // ── Patient Profile ───────────────────────────────────────────

  Future<void> saveProfile(String userId, PatientProfile profile) async {
    await _db
        .collection('users')
        .doc(userId)
        .set({'profile': profile.toJson()}, SetOptions(merge: true));
  }

  Future<PatientProfile?> getProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null || data['profile'] == null) return null;
    try {
      return PatientProfile.fromJson(
          Map<String, dynamic>.from(data['profile']));
    } catch (_) {
      return null;
    }
  }
}

// ── Flagged Case Model ────────────────────────────────────────

class FlaggedCase {
  final String id;
  final String userId;
  final String patientName;
  final String patientEmail;
  final DateTime timestamp;
  final RiskLevel riskLevel;
  final List<String> visualFindings;
  final String reasoning;
  final String patientMessage;
  final bool reviewed;
  final String reviewerNotes;

  const FlaggedCase({
    required this.id,
    required this.userId,
    required this.patientName,
    required this.patientEmail,
    required this.timestamp,
    required this.riskLevel,
    required this.visualFindings,
    required this.reasoning,
    required this.patientMessage,
    required this.reviewed,
    required this.reviewerNotes,
  });
}
