import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user stream — rebuilds UI on auth state changes
  Stream<User?> get userStream => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    // Store name + email in Firestore — this is what the clinician side
    // reads to identify patients, so it must be set from the very first
    // sign-up rather than left for the patient to fill in later.
    await FirestoreService().saveUserEmail(
      credential.user!.uid,
      email.trim(),
      displayName: displayName,
    );
    // Best-effort — registration should still succeed if this fails
    try {
      await credential.user?.sendEmailVerification();
    } catch (_) {}
    return credential;
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Creates a Firebase Auth account for a patient the clinician is adding.
  // Uses a throwaway secondary FirebaseApp so createUserWithEmailAndPassword
  // doesn't sign out / replace the clinician's own session (the Firebase
  // Auth SDK always signs in as the just-created user on the app instance
  // that created it).
  Future<String> createPatientAuthAccount({
    required String email,
    required String password,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'patientCreation_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = credential.user!.uid;
      await secondaryAuth.signOut();
      return uid;
    } finally {
      await secondaryApp.delete();
    }
  }

  static const _tempPasswordChars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';

  // Excludes visually ambiguous characters (0/O, 1/l/I) since this is read
  // aloud or copied by hand from clinician to patient.
  String generateTempPassword({int length = 10}) {
    final rand = Random.secure();
    return List.generate(
        length, (_) => _tempPasswordChars[rand.nextInt(_tempPasswordChars.length)])
        .join();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Human-readable error messages
  static String errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Deliberately the same message for all three — distinguishing them
      // lets an attacker enumerate which emails have registered accounts.
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
