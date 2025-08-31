import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/themes/app_themes.dart';
import '../../../core/utils/validators.dart';
import 'login_button.dart';
import '../number_verification_page.dart';

class LoginPageForm extends StatefulWidget {
  const LoginPageForm({
    super.key,
  });

  @override
  State<LoginPageForm> createState() => _LoginPageFormState();
}

class _LoginPageFormState extends State<LoginPageForm> {
  final _key = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = false;

  bool isPasswordShown = false;
  void onPassShowClicked() {
    isPasswordShown = !isPasswordShown;
    setState(() {});
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _verifyCredentials(String phoneNumber, String password) async {
    try {
      // Query Firestore to find user with matching phone number
      QuerySnapshot querySnapshot = await _firestore
          .collection("users")
          .where("phone", isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false; // User not found
      }

      DocumentSnapshot userDoc = querySnapshot.docs.first;
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Check if password matches
      return userData['password'] == password;
    } catch (e) {
      print("Error verifying credentials: $e");
      return false;
    }
  }

  void loginWithPassword() async {
    final bool isFormOkay = _key.currentState?.validate() ?? false;
    if (!isFormOkay) return;

    String phoneNumber = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your password")),
      );
      return;
    }

    // Format phone number
    if (!phoneNumber.startsWith('+')) {
      if (phoneNumber.startsWith('0')) {
        phoneNumber = "+92${phoneNumber.substring(1)}";
      } else {
        phoneNumber = "+92$phoneNumber";
      }
    }

    setState(() => _loading = true);

    // Verify credentials against Firestore
    bool credentialsValid = await _verifyCredentials(phoneNumber, password);
    
    if (credentialsValid) {
      // Credentials are valid, proceed with OTP verification
      loginWithPhone();
    } else {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wrong credentials. Please check your phone number and password.")),
        );
      }
    }
  }

  void loginWithPhone() async {
    final bool isFormOkay = _key.currentState?.validate() ?? false;
    if (!isFormOkay) return;

    String phoneNumber = _phoneController.text.trim();
    // String password = _passwordController.text; // Password not directly used for OTP login

    // Ensure phone number format is E.164 (e.g., +923001234567)
    if (!phoneNumber.startsWith('+')) {
      // This is a common default; consider a country code picker for robustness
      if (phoneNumber.startsWith('0')) {
          phoneNumber = "+92${phoneNumber.substring(1)}";
      } else {
          phoneNumber = "+92$phoneNumber";
      }
    } else if (phoneNumber.length < 11) { // Basic check for valid length with +
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid phone number format.")),
        );
        return;
    }

    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          setState(() => _loading = false);
          if (mounted) {
             // TODO: Navigate to your app's home/entry point after successful login
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.entryPoint, (route) => false);
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Login successful!")),
            );
          }
        } catch (e) {
          setState(() => _loading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Login failed: ${e.toString()}")),
            );
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Phone verification failed: ${e.message}")),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          // _verificationId = verificationId; // Not storing in state anymore
          _loading = false;
        });
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NumberVerificationPage(
                verificationId: verificationId, // Pass directly
                phoneNumber: phoneNumber,
                // name and password are not needed for login flow, will be null by default
              ),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("OTP sent to $phoneNumber")),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // _verificationId = verificationId; // Not storing in state
        // Handle timeout if needed, e.g., allow resend
        if (mounted && _loading) { // Check mounted and if loading was true
            setState(() => _loading = false);
        }
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP auto-retrieval timed out.")),
        );
      },
    );
  }

  void onLogin() {
    // Check if password is provided for credential-based login
    if (_passwordController.text.trim().isNotEmpty) {
      loginWithPassword(); // Verify credentials first, then OTP
    } else {
      loginWithPhone(); // Direct OTP login without password verification
    }
  }


  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.defaultTheme.copyWith(
        inputDecorationTheme: AppTheme.secondaryInputDecorationTheme,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDefaults.padding),
        child: Form(
          key: _key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phone Field
              const Text("Phone Number"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: Validators.requiredWithFieldName('Phone').call,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
              ),
              const SizedBox(height: AppDefaults.padding),

              // Password Field
              const Text("Password"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                validator: Validators.password.call,
                onFieldSubmitted: (v) => _loading ? null : onLogin(),
                textInputAction: TextInputAction.done,
                obscureText: !isPasswordShown,
                decoration: InputDecoration(
                  hintText: "Enter your password",
                  suffixIcon: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      onPressed: onPassShowClicked,
                      icon: SvgPicture.asset(
                        AppIcons.eye, // Ensure AppIcons.eye is defined and is an SVG path
                        width: 24,
                         colorFilter: ColorFilter.mode( // Added for SVG theming
                            Theme.of(context).iconTheme.color ?? Colors.grey,
                            BlendMode.srcIn,
                          ),
                      ),
                    ),
                  ),
                ),
                enabled: !_loading,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : () {
                    // TODO: Implement password recovery if not using OTP for everything
                    // Navigator.pushNamed(context, AppRoutes.forgotPassword);
                     ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Forgot Password? Use OTP login.")),
                    );
                  },
                  child: const Text('Forget Password?'),
                ),
              ),

              // Login Button
              LoginButton(
                onPressed: _loading ? null : onLogin, 
                // You might want to change button text e.g. "Login / Send OTP"
              ),
            ],
          ),
        ),
      ),
    );
  }
}
