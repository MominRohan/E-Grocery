import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String? _verificationId;
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

  void loginWithPhone() async {
    final bool isFormOkay = _key.currentState?.validate() ?? false;
    if (!isFormOkay) return;

    String phoneNumber = _phoneController.text.trim();

    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+92' + phoneNumber; // Automatically add country code
    }

    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          setState(() => _loading = false);
          Navigator.pushNamed(context, AppRoutes.entryPoint);
        } catch (e) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login failed: $e")),
          );
        }
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
          _loading = false;
        });
        
        // Navigate to NumberVerification screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NumberVerificationPage()),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP sent to $phoneNumber")),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void onLogin() {
    loginWithPhone();
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
                keyboardType: TextInputType.number,
                validator: Validators.requiredWithFieldName('Phone').call,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDefaults.padding),

              // Password Field
              const Text("Password"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                validator: Validators.password.call,
                onFieldSubmitted: (v) => onLogin(),
                textInputAction: TextInputAction.done,
                obscureText: !isPasswordShown,
                decoration: InputDecoration(
                  suffixIcon: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      onPressed: onPassShowClicked,
                      icon: SvgPicture.asset(
                        AppIcons.eye,
                        width: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // Forget Password labelLarge
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.forgotPassword);
                  },
                  child: const Text('Forget Password?'),
                ),
              ),

              // Login Button
              LoginButton(onPressed: _loading ? null : onLogin),
            ],
          ),
        ),
      ),
    );
  }
}
