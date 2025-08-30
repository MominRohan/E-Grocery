import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;

  /// 🔹 Send OTP
  Future<void> _sendOTP() async {
    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification on some devices
        await _auth.signInWithCredential(credential);
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number automatically verified!")),
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification failed: ${e.message}")),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP sent to ${_phoneController.text}")),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// 🔹 Verify OTP
  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;

    setState(() => _loading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await _auth.signInWithCredential(credential);

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully!")),
      );

      // Navigate to home page after success
      // Navigator.pushReplacementNamed(context, "/home");

    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to verify OTP: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Sign Up"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 🔹 Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter your name" : null,
                ),
                const SizedBox(height: 16),

                // 🔹 Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    hintText: "+923123456789",
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? "Enter phone number" : null,
                ),
                const SizedBox(height: 16),

                // 🔹 OTP Field (after sending OTP)
                if (_otpSent)
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Enter OTP"),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter OTP" : null,
                  ),

                const SizedBox(height: 24),

                // 🔹 Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () {
                      if (_formKey.currentState!.validate()) {
                        if (_otpSent) {
                          _verifyOTP();
                        } else {
                          _sendOTP();
                        }
                      }
                    },
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_otpSent ? "Verify OTP" : "Send OTP"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
