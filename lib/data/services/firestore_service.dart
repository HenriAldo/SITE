import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/assessment.dart';
import '../models/patient_profile.dart';
import '../models/symptom_response.dart';


class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Image Upload ──────────────────────────────────────────────

  Future<String> uploadAssessmentImage(
      String userId, String assessmentId, File imageFile) async {
    // Use the REST API directly — bypasses firebase_storage SDK v11
    // incompatibility with the new .firebasestorage.app bucket format
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Not authenticated');

    final bytes = await imageFile.readAsBytes();
    const bucket = 'site-8f4b1.firebasestorage.app';
    final objectPath = 'assessments/$userId/$assessmentId.jpg';
    final encodedPath = Uri.encodeComponent(objectPath);

    final response = await http.post(
      Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
        '?uploadType=media&name=$encodedPath',
      ),
      headers: {
        'Content-Type': 'image/jpeg',
        'Authorization': 'Bearer $token',
      },
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Storage upload failed ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final downloadToken = json['downloadTokens'] as String;
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
        '/$encodedPath?alt=media&token=$downloadToken';
  }

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
    int? patientAge,
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
        'patient_age': patientAge,
        'image_url': assessment.imageUrl,
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

  // One-time fetch of a patient's most recent assessments — used by the
  // clinician case detail to show a "is it getting worse" photo history.
  Future<List<Assessment>> getRecentAssessments(String userId,
      {int limit = 6}) async {
    final snap = await _assessments(userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map(_assessmentFromDoc)
        .whereType<Assessment>()
        .toList();
  }

  Assessment? _assessmentFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      final symptomsData = data['symptoms'] as Map<String, dynamic>?;
      return Assessment(
        id: data['id'] ?? doc.id,
        timestamp: DateTime.parse(data['timestamp']).toLocal(),
        riskLevel: RiskLevelExtension.fromString(data['risk_level'] ?? 'low'),
        centralLineDetected: data['central_line_detected'] ?? false,
        visualFindings: List<String>.from(data['visual_findings'] ?? []),
        reasoning: data['reasoning'] ?? '',
        patientMessage: data['patient_message'] ?? '',
        escalate: data['escalate'] ?? false,
        imagePath: data['image_path'],
        imageUrl: data['image_url'] as String?,
        symptoms: symptomsData != null
            ? SymptomResponse.fromJson(symptomsData)
            : null,
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

  Future<void> markReviewed(
    String caseId,
    String notes, {
    RiskLevel? classification,
  }) async {
    await _db.collection('flagged_cases').doc(caseId).update({
      'reviewed': true,
      'reviewer_notes': notes,
      'reviewed_at': FieldValue.serverTimestamp(),
      if (classification != null)
        'clinician_classification': classification.name,
    });
  }

  // Undo of a quick-confirm: restore the case to unreviewed and put the
  // clinician classification back to what it was before (or clear it).
  Future<void> revertReview(String caseId, {RiskLevel? classification}) async {
    await _db.collection('flagged_cases').doc(caseId).update({
      'reviewed': false,
      'reviewed_at': null,
      'clinician_classification':
          classification != null ? classification.name : FieldValue.delete(),
    });
  }

  // Write-only feedback channel — clinicians vote on whether the AI's
  // reasoning was helpful. Nothing in the app reads this back; it's
  // collected for the dev/research team to review model quality.
  Future<void> submitReasoningFeedback({
    required String caseId,
    required String clinicianId,
    required bool positive,
  }) async {
    await _db.collection('reasoning_feedback').add({
      'case_id': caseId,
      'clinician_id': clinicianId,
      'vote': positive,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  FlaggedCase? _flaggedCaseFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      final classificationStr = data['clinician_classification'] as String?;
      final symptomsData = data['symptoms'] as Map<String, dynamic>?;
      return FlaggedCase(
        id: data['id'] ?? doc.id,
        userId: data['user_id'] ?? '',
        patientName: data['patient_name'] ?? 'Unknown',
        patientEmail: data['patient_email'] ?? '',
        patientAge: data['patient_age'] as int?,
        timestamp: DateTime.parse(data['timestamp']).toLocal(),
        riskLevel: RiskLevelExtension.fromString(data['risk_level'] ?? 'low'),
        visualFindings: List<String>.from(data['visual_findings'] ?? []),
        reasoning: data['reasoning'] ?? '',
        patientMessage: data['patient_message'] ?? '',
        reviewed: data['reviewed'] ?? false,
        reviewerNotes: data['reviewer_notes'] ?? '',
        imageUrl: data['image_url'] as String?,
        clinicianClassification: classificationStr != null
            ? RiskLevelExtension.fromString(classificationStr)
            : null,
        symptoms: symptomsData != null
            ? SymptomResponse.fromJson(symptomsData)
            : null,
        reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate().toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<FlaggedCase?> getFlaggedCase(String assessmentId) async {
    final doc =
        await _db.collection('flagged_cases').doc(assessmentId).get();
    if (!doc.exists) return null;
    try {
      final data = doc.data()!;
      final classificationStr = data['clinician_classification'] as String?;
      final symptomsData = data['symptoms'] as Map<String, dynamic>?;
      return FlaggedCase(
        id: data['id'] ?? doc.id,
        userId: data['user_id'] ?? '',
        patientName: data['patient_name'] ?? 'Unknown',
        patientEmail: data['patient_email'] ?? '',
        patientAge: data['patient_age'] as int?,
        timestamp: DateTime.parse(data['timestamp']).toLocal(),
        riskLevel: RiskLevelExtension.fromString(data['risk_level'] ?? 'low'),
        visualFindings: List<String>.from(data['visual_findings'] ?? []),
        reasoning: data['reasoning'] ?? '',
        patientMessage: data['patient_message'] ?? '',
        reviewed: data['reviewed'] ?? false,
        reviewerNotes: data['reviewer_notes'] ?? '',
        imageUrl: data['image_url'] as String?,
        clinicianClassification: classificationStr != null
            ? RiskLevelExtension.fromString(classificationStr)
            : null,
        symptoms: symptomsData != null
            ? SymptomResponse.fromJson(symptomsData)
            : null,
        reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate().toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  // Count of open (unreviewed) flagged cases per patient — drives the
  // "needs attention" badge/sort on the clinician patient list.
  Future<Map<String, int>> getOpenFlaggedCounts() async {
    final snap = await _db
        .collection('flagged_cases')
        .where('reviewed', isEqualTo: false)
        .get();
    final counts = <String, int>{};
    for (final doc in snap.docs) {
      final uid = doc.data()['user_id'] as String?;
      if (uid != null) counts[uid] = (counts[uid] ?? 0) + 1;
    }
    return counts;
  }

  Stream<List<FlaggedCase>> flaggedCasesForUser(String userId) {
    // No orderBy — avoids requiring a composite index on (user_id, timestamp).
    // The caller only needs a by-id lookup map so order doesn't matter.
    return _db
        .collection('flagged_cases')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map(_flaggedCaseFromDoc)
            .whereType<FlaggedCase>()
            .toList());
  }

  // ── User Role / Auth Gate ──────────────────────────────────────

  // Drives AuthGate: role (patient vs clinician) and the forced
  // set-password flag both live on this doc, so a single stream lets
  // AuthGate react the instant either one changes.
  Stream<Map<String, dynamic>?> userDocStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data());
  }

  // Firestore's users/{uid}.display_name is the source of truth the
  // clinician side reads (PatientSummary.name, patient cards, etc.) — it's
  // set at patient creation and kept in sync when the patient edits their
  // name. Firebase Auth's own displayName is a separate, often-unset store,
  // so this is what patient-submitted records (e.g. flagged cases) should
  // use to identify the patient, not FirebaseAuth.currentUser.displayName.
  Future<String> getDisplayName(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return (doc.data()?['display_name'] as String?) ?? '';
  }

  Future<void> updateDisplayName(String userId, String displayName) async {
    await _db.collection('users').doc(userId).set(
      {'display_name': displayName},
      SetOptions(merge: true),
    );
  }

  // ── Notification read-state ─────────────────────────────────────
  // Stored on the user doc (not SharedPreferences) so "seen"/"dismissed"
  // state follows the account across devices instead of resetting on a
  // new device, reinstall, or cleared browser storage.

  Future<DateTime?> getNotificationsLastSeen(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final ts = doc.data()?['notifications_last_seen'];
    return ts is Timestamp ? ts.toDate() : null;
  }

  Future<void> setNotificationsLastSeen(String userId, DateTime timestamp) async {
    await _db.collection('users').doc(userId).set(
      {'notifications_last_seen': Timestamp.fromDate(timestamp)},
      SetOptions(merge: true),
    );
  }

  Future<Set<String>> getDismissedNotificationIds(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final ids = doc.data()?['dismissed_notification_ids'];
    return ids is List ? ids.cast<String>().toSet() : <String>{};
  }

  Future<void> setDismissedNotificationIds(
      String userId, Set<String> ids) async {
    await _db.collection('users').doc(userId).set(
      {'dismissed_notification_ids': ids.toList()},
      SetOptions(merge: true),
    );
  }

  // ── Clinician-created patients (one-time-password onboarding) ──

  Future<void> createPatientRecord(
    String patientId, {
    required String email,
    required String displayName,
    required String clinicianId,
  }) async {
    await _db.collection('users').doc(patientId).set({
      'email': email,
      'display_name': displayName,
      'clinicianId': clinicianId,
      'mustChangePassword': true,
    });
  }

  Future<void> clearMustChangePassword(String userId) async {
    await _db.collection('users').doc(userId).set(
      {'mustChangePassword': false},
      SetOptions(merge: true),
    );
  }

  // ── Patient List (clinician) ──────────────────────────────────

  Future<List<PatientSummary>> getPatients() async {
    final snap = await _db.collection('users').get();
    final patients = <PatientSummary>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['role'] == 'clinician') continue;
      final profileData = data['profile'];
      PatientProfile? profile;
      if (profileData != null) {
        try {
          profile = PatientProfile.fromJson(
              Map<String, dynamic>.from(profileData));
        } catch (_) {}
      }
      patients.add(PatientSummary(
        userId: doc.id,
        email: data['email'] ?? '',
        displayName: data['display_name'] ?? '',
        hasProfile: profile != null,
        profile: profile,
        clinicianId: data['clinicianId'] as String?,
      ));
    }
    return patients;
  }

  Future<List<PatientSummary>> getMyPatients(String clinicianId) async {
    final snap = await _db
        .collection('users')
        .where('clinicianId', isEqualTo: clinicianId)
        .get();
    final patients = <PatientSummary>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['role'] == 'clinician') continue;
      final profileData = data['profile'];
      PatientProfile? profile;
      if (profileData != null) {
        try {
          profile = PatientProfile.fromJson(
              Map<String, dynamic>.from(profileData));
        } catch (_) {}
      }
      patients.add(PatientSummary(
        userId: doc.id,
        email: data['email'] ?? '',
        displayName: data['display_name'] ?? '',
        hasProfile: profile != null,
        profile: profile,
        clinicianId: clinicianId,
      ));
    }
    return patients;
  }

  Future<void> assignPatientToClinician(
      String patientId, String clinicianId) async {
    await _db.collection('users').doc(patientId).set(
      {'clinicianId': clinicianId},
      SetOptions(merge: true),
    );
  }

  Future<String?> getAssignedClinicianId(String patientId) async {
    final doc = await _db.collection('users').doc(patientId).get();
    return doc.data()?['clinicianId'] as String?;
  }

  // ── Clinician Contact (own profile, looked up by patients) ────

  Future<void> saveClinicianContact(
      String clinicianId, ClinicianContact contact) async {
    await _db.collection('users').doc(clinicianId).set(
      {'clinician_contact': contact.toJson()},
      SetOptions(merge: true),
    );
  }

  Future<ClinicianContact?> getClinicianContact(String clinicianId) async {
    final doc = await _db.collection('users').doc(clinicianId).get();
    final data = doc.data();
    if (data == null || data['clinician_contact'] == null) return null;
    try {
      return ClinicianContact.fromJson(
          Map<String, dynamic>.from(data['clinician_contact']));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUserEmail(String userId, String email,
      {String? displayName}) async {
    await _db.collection('users').doc(userId).set(
      {
        'email': email,
        if (displayName != null) 'display_name': displayName,
      },
      SetOptions(merge: true),
    );
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
  final int? patientAge;
  final DateTime timestamp;
  final RiskLevel riskLevel;
  final List<String> visualFindings;
  final String reasoning;
  final String patientMessage;
  final bool reviewed;
  final String reviewerNotes;
  final String? imageUrl;
  final RiskLevel? clinicianClassification;
  final SymptomResponse? symptoms;
  final DateTime? reviewedAt;

  const FlaggedCase({
    required this.id,
    required this.userId,
    required this.patientName,
    required this.patientEmail,
    this.patientAge,
    required this.timestamp,
    required this.riskLevel,
    required this.visualFindings,
    required this.reasoning,
    required this.patientMessage,
    required this.reviewed,
    required this.reviewerNotes,
    this.imageUrl,
    this.clinicianClassification,
    this.symptoms,
    this.reviewedAt,
  });
}

// ── Patient Summary ───────────────────────────────────────────

class PatientSummary {
  final String userId;
  final String email;
  final String displayName;
  final bool hasProfile;
  final PatientProfile? profile;
  final String? clinicianId;

  const PatientSummary({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.hasProfile,
    this.profile,
    this.clinicianId,
  });

  String get name =>
      displayName.isNotEmpty ? displayName : email;
}
