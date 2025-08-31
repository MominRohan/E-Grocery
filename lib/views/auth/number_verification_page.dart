import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/components/network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_defaults.dart';
import '../../core/constants/app_images.dart';
import '../../core/themes/app_themes.dart';
import 'dialogs/verified_dialogs.dart';

class OTPTextFields extends StatefulWidget {
  final Function(String otp) onOtpEntered;
  const OTPTextFields({super.key, required this.onOtpEntered});

  @override
  State<OTPTextFields> createState() => _OTPTextFieldsState();
}

class _OTPTextFieldsState extends State<OTPTextFields> {
  late List<TextEditingController> _otpControllers;
  late List<FocusNode> _otpFocusNodes;

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(6, (_) => TextEditingController());
    _otpFocusNodes = List.generate(6, (_) => FocusNode());

    for (int i = 0; i < 6; i++) {
      _otpControllers[i].addListener(() {
        String currentOtp = _otpControllers.map((c) => c.text).join();
        widget.onOtpEntered(currentOtp);
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.defaultTheme.copyWith(
        inputDecorationTheme: AppTheme.otpInputDecorationTheme,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(6, (index) {
          return SizedBox(
            width: 48,
            height: 58,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (KeyEvent event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                  if (_otpControllers[index].text.isEmpty && index > 0) {
                    FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
                    _otpControllers[index - 1].clear();
                  }
                }
              },
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(1),
                  FilteringTextInputFormatter.digitsOnly,
                ],
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (value.length == 1 && index < 5) {
                    FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
                  } else if (value.isEmpty && index > 0) {
                    FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
                  }
                },
                onTap: () {
                  _otpControllers[index].selection = TextSelection.fromPosition(
                      TextPosition(offset: _otpControllers[index].text.length));
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

class NumberVerificationPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String? name; // Made nullable
  final String? password; // Made nullable

  const NumberVerificationPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.name, // Now optional
    this.password, // Now optional
  });

  @override
  State<NumberVerificationPage> createState() => _NumberVerificationPageState();
}

class _NumberVerificationPageState extends State<NumberVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _enteredOtp = "";

  Future<void> _verifyOtpAndFinalize() async { // Renamed method
    if (_enteredOtp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the complete 6-digit OTP.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _enteredOtp,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // If it's a sign-up flow (name is present), create/update Firestore document
        if (widget.name != null && widget.name!.isNotEmpty) {
          await _firestore.collection("users").doc(userCredential.user!.uid).set({
            "name": widget.name,
            "phone": widget.phoneNumber,
            "password": widget.password, // Save password for login verification
            "createdAt": FieldValue.serverTimestamp(),
            "uid": userCredential.user!.uid,
          });
          await userCredential.user!.updateDisplayName(widget.name);
        } 
        // If it's a login flow, the user should already exist in Firestore.
        // You might want to update last login time or other details if necessary.

        setState(() => _isLoading = false);

        if (mounted) {
          showGeneralDialog(
            barrierLabel: 'Dialog',
            barrierDismissible: true,
            context: context,
            pageBuilder: (ctx, anim1, anim2) => const VerifiedDialog(),
            transitionBuilder: (ctx, anim1, anim2, child) => ScaleTransition(
              scale: anim1,
              child: child,
            ),
          ).then((_) {
            // TODO: Navigate to home or appropriate screen
            // Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.name != null ? "Account created/verified!" : "Login successful!")),
            );
          });
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Verification failed: Could not get user details.")),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message = "An error occurred during verification.";
      if (e.code == 'invalid-verification-code') {
        message = "Invalid OTP. Please try again.";
      } else if (e.code == 'session-expired') {
        message = "The OTP has expired. Please request a new one.";
      } else {
        message = e.message ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: $e")),
        );
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Phone number automatically verified.")),
        );
        // Consider calling _verifyOtpAndFinalize if auto-verification occurs for resend
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to resend OTP: ${e.message}")),
        );
      },
      codeSent: (String newVerificationId, int? resendToken) {
        setState(() => _isLoading = false);
        // Potentially update widget.verificationId if you want to use the new one immediately
        // For now, just inform the user.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A new OTP has been sent.")),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Handle timeout for resend
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldWithBoxBackground,
      appBar: AppBar(
        title: const Text("Verify Phone Number"),
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDefaults.padding),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDefaults.padding),
                  margin: const EdgeInsets.all(AppDefaults.margin),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: AppDefaults.borderRadius,
                  ),
                  child: Column(
                    children: [
                      const NumberVerificationHeader(),
                      OTPTextFields(
                        onOtpEntered: (otp) {
                          setState(() {
                            _enteredOtp = otp;
                          });
                        },
                      ),
                      const SizedBox(height: AppDefaults.padding * 3),
                      ResendButton(onPressed: _isLoading ? null : _resendOtp),
                      const SizedBox(height: AppDefaults.padding),
                      VerifyButton(
                        isLoading: _isLoading,
                        onPressed: _verifyOtpAndFinalize, // Updated to new method name
                         // Distinguish button text based on whether it's sign-up or login
                        buttonText: widget.name != null && widget.name!.isNotEmpty 
                            ? 'Verify & Create Account' 
                            : 'Verify & Log In',
                      ),
                      const SizedBox(height: AppDefaults.padding),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String buttonText; // Added to customize button text

  const VerifyButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.buttonText, // Added
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(buttonText), // Use dynamic button text
      ),
    );
  }
}

class ResendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const ResendButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Didn\'t get the code?'),
        TextButton(
          onPressed: onPressed,
          child: const Text('Resend OTP'),
        ),
      ],
    );
  }
}

class NumberVerificationHeader extends StatelessWidget {
  const NumberVerificationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppDefaults.padding),
        Text(
          'Enter Your 6 digit code',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDefaults.padding),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: const AspectRatio(
            aspectRatio: 1 / 1,
            child: NetworkImageWithLoader(
              AppImages.numberVerfication,
            ),
          ),
        ),
        const SizedBox(height: AppDefaults.padding * 3),
      ],
    );
  }
}
