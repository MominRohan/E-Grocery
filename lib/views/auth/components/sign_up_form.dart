import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Removed SvgPicture import as it might not be needed if AppIcons.eye is also changed or if it was only for eyeSlash
// import 'package:flutter_svg/svg.dart'; 

import '../../../core/constants/constants.dart';
import '../../../core/utils/validators.dart';
import 'already_have_accout.dart';
import '../number_verification_page.dart'; // Import NumberVerificationPage

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Add Firestore instance
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      String name = _nameController.text.trim();
      String rawPhoneNumber = _phoneController.text.trim();
      String password = _passwordController.text.trim();

      String formattedPhoneNumber = rawPhoneNumber;
      if (rawPhoneNumber.isNotEmpty && !rawPhoneNumber.startsWith('+')) {
        if (rawPhoneNumber.startsWith('0')) {
          formattedPhoneNumber = "+92${rawPhoneNumber.substring(1)}";
        } else if (rawPhoneNumber.length == 10 && !rawPhoneNumber.startsWith('92')) {
          formattedPhoneNumber = "+92$rawPhoneNumber";
        } else if (rawPhoneNumber.startsWith('92')) {
          formattedPhoneNumber = "+$rawPhoneNumber";
        } else {
          formattedPhoneNumber = "+92$rawPhoneNumber";
        }
      } else if (rawPhoneNumber.startsWith('+') && rawPhoneNumber.length < 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid phone number format.")),
        );
        setState(() => _isLoading = false);
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            UserCredential userCredential = await _auth.signInWithCredential(credential);
            if (userCredential.user != null) {
              await _firestore.collection("users").doc(userCredential.user!.uid).set({
                "name": name,
                "phone": formattedPhoneNumber,
                "createdAt": FieldValue.serverTimestamp(),
                "uid": userCredential.user!.uid,
              });
              await userCredential.user!.updateDisplayName(name);
              setState(() => _isLoading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Phone number automatically verified & account created!")),
                );
                // TODO: Navigate to home screen or dashboard
              }
            }
          } catch (e) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Auto-verification sign up failed: ${e.toString()}")),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Phone verification failed: ${e.message}")),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("OTP sent to $formattedPhoneNumber")),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NumberVerificationPage(
                  verificationId: verificationId,
                  name: name,
                  phoneNumber: formattedPhoneNumber,
                  password: password,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _isLoading = false);
          print("OTP auto-retrieval timeout. Verification ID: $verificationId");
        },
        timeout: const Duration(seconds: 60),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields correctly.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(AppDefaults.margin),
        padding: const EdgeInsets.all(AppDefaults.padding),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: AppDefaults.boxShadow,
          borderRadius: AppDefaults.borderRadius,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Name"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: Validators.requiredWithFieldName('Name').call,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
              ),
              const SizedBox(height: AppDefaults.padding),
              const Text("Phone Number"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Phone number is required.";
                  }
                  return null;
                },
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
              ),
              const SizedBox(height: AppDefaults.padding),
              const Text("Password"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Password is required.";
                  }
                  if (value.length < 6) {
                    return "Password must be at least 6 characters.";
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon( // Changed from SvgPicture.asset
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).iconTheme.color ?? Colors.grey,
                    ),
                  ),
                ),
                enabled: !_isLoading,
                onFieldSubmitted: (_) => _isLoading ? null : _onSubmit(),
              ),
              const SizedBox(height: AppDefaults.padding * 2),
              ElevatedButton(
                onPressed: _isLoading ? null : _onSubmit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDefaults.borderRadius,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text("Sign Up"),
              ),
              const SizedBox(height: AppDefaults.padding),
              const AlreadyHaveAnAccount(),
            ],
          ),
        ),
      ),
    );
  }
}
