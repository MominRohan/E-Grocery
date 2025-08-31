import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'number_verification_page.dart'; // Import the NumberVerificationPage

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // _otpController is removed as OTP will be entered on NumberVerificationPage

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Keep for potential auto-verification scenario

  // _verificationId is still needed to pass to the next page
  String? _verificationId;
  // _otpSent is removed as this page no longer handles OTP entry UI
  bool _loading = false;
  bool _obscurePassword = true;

  /// 🔹 Send OTP and Navigate
  Future<void> _sendOTPAndNavigate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);

    String phoneNumber = _phoneController.text.trim();
    // Ensure phone number is in E.164 format for Firebase
    // Example: +12223334444. You might need a country code picker or more robust validation.
    if (!phoneNumber.startsWith('+')) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number must be in international format (e.g., +1XXXXXXXXXX).")),
      );
      setState(() => _loading = false);
      return;
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // This callback is triggered if Firebase can automatically verify the OTP.
        // This can happen on some Android devices.
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number automatically verified!")),
        );
        // Handle auto-verification: Sign in and create user data
        try {
            UserCredential userCredential = await _auth.signInWithCredential(credential);
            if (userCredential.user != null) {
                 await _firestore.collection("users").doc(userCredential.user!.uid).set({
                    "name": _nameController.text.trim(),
                    "phone": phoneNumber,
                    // "password": _passwordController.text.trim(), // Avoid storing plain password
                    "createdAt": FieldValue.serverTimestamp(),
                    "uid": userCredential.user!.uid,
                });
                await userCredential.user!.updateDisplayName(_nameController.text.trim());
                // Navigate to home or show success directly
                // For example: Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Account created successfully via auto-verification!")),
                );
            }
        } catch (e) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Auto-verification sign up failed: ${e.toString()}")),
            );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Phone verification failed: ${e.message}")),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId; // Store verificationId
          _loading = false;
        });
        
        // Navigate to NumberVerificationPage with all necessary data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NumberVerificationPage(
              verificationId: verificationId,
              name: _nameController.text.trim(),
              phoneNumber: phoneNumber,
              password: _passwordController.text.trim(), // Pass password if needed on next page
            ),
          ),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP sent to $phoneNumber. Please verify.")),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Called when auto-retrieval times out.
        // You might want to update _verificationId here if it's used elsewhere for timeout scenarios.
        setState(() {
           // _verificationId = verificationId; // Potentially update if needed for retry logic on this page
           _loading = false; // Ensure loading stops
        });
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP auto-retrieval timed out.")),
        );
      },
    );
  }

  // _verifyOTP method is removed as it's handled in NumberVerificationPage

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    // _otpController.dispose(); // Removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Good for pages with many TextFormFields
      appBar: AppBar( // Adding an AppBar for context and back navigation
        title: const Text("Create Account"),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20), // Adjusted spacing

                const Text(
                  "Welcome E-Grocery",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 30),

                // 🔹 Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter your name" : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 🔹 Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    hintText: "+923083316261", // Emphasize E.164 format
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Enter phone number";
                    if (!value.startsWith('+')) return "Include country code (e.g., +1)";
                    // Add more robust validation if needed
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // 🔹 Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                     if (value == null || value.isEmpty) return "Enter password";
                     if (value.length < 6) return "Password must be at least 6 characters";
                     return null;
                  },
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24), // Increased spacing before button

                // 🔹 Sign Up button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    //icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    // Button now directly calls _sendOTPAndNavigate
                    onPressed: _loading ? null : _sendOTPAndNavigate,
                    label: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        // Text no longer changes based on _otpSent
                        : const Text(
                        "Sign Up",
                      style: TextStyle(fontSize: 18,fontWeight: FontWeight.w900)
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 🔹 Log In link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already Have Account? "),
                    GestureDetector(
                      onTap: () {
                        if (_loading) return; // Prevent navigation while loading
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text(
                        "Log In",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
