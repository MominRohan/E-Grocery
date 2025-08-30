import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get Current User
  User? get currentUser => _firebaseAuth.currentUser;

  // Listen to Authentication State Changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // 🔹 Step 1: Send OTP
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto verification (sometimes works without user entering SMS code)
        await _firebaseAuth.signInWithCredential(credential);
      },
      verificationFailed: verificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // 🔹 Step 2: Verify OTP & Sign In
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
    required String fullName,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential =
      await _firebaseAuth.signInWithCredential(credential);

      // Save user in Firestore (only if new)
      await _createUserInFirestore(
        userCredential.user!.uid,
        fullName,
        userCredential.user!.phoneNumber ?? "",
      );

      return userCredential;
    } catch (e) {
      throw FirebaseAuthException(
        code: "otp-verification-failed",
        message: "Failed to verify OTP: ${e.toString()}",
      );
    }
  }

  // 🔹 Create User in Firestore
  Future<void> _createUserInFirestore(
      String uid, String fullName, String phoneNumber) async {
    DocumentSnapshot? lastUserSnapshot;
    QuerySnapshot querySnapshot = await _firestore
        .collection("users")
        .orderBy("userID", descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      lastUserSnapshot = querySnapshot.docs.first;
    }

    int newUserID =
    lastUserSnapshot != null ? (lastUserSnapshot['userID'] as int) + 1 : 1;

    // Only create new user if not already exists
    final existingUser = await _firestore.collection("users").doc(uid).get();
    if (!existingUser.exists) {
      await _firestore.collection("users").doc(uid).set({
        "userID": newUserID,
        "fullName": fullName,
        "phoneNumber": phoneNumber,
        "email": null,
        "address": null,
        "isVendor": false,
        "profilePhoto": null,
        "dob": null,
        "vendorApplicationStatus": null,
      });
    }
  }

  // 🔹 Sign Out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw FirebaseAuthException(
        code: "sign-out-failed",
        message: "Failed to sign out: ${e.toString()}",
      );
    }
  }
}
