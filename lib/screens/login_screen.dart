import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/firebase_navigation_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _userService = UserService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        // Check if user exists in Firestore
        final userExists = await _userService.userExists(userCredential.user!.uid);
        
        if (!userExists) {
          await _userService.ensureUserDocument(
            uid: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
          );
        }
        
        if (mounted) {
          await NavigationService.navigateBasedOnAuth(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (mounted) {
        // Navigate based on Firebase data
        await NavigationService.navigateBasedOnAuth(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildTopGlow(),
          SafeArea(
            child: SizedBox(
              height: screenHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenHeight * 0.02,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.01),
                    _buildLogo(),
                    SizedBox(height: screenHeight * 0.025),
                    _buildTitle(),
                    SizedBox(height: screenHeight * 0.035),
                    _buildEmailField(),
                    SizedBox(height: screenHeight * 0.015),
                    _buildPasswordField(),
                    SizedBox(height: screenHeight * 0.008),
                    _buildForgotPassword(),
                    SizedBox(height: screenHeight * 0.035),
                    _buildSignInButton(),
                    SizedBox(height: screenHeight * 0.025),
                    _buildDivider(),
                    SizedBox(height: screenHeight * 0.025),
                    _buildGoogleButton(),
                    const Spacer(),
                    _buildCreateAccount(),
                    SizedBox(height: screenHeight * 0.015),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopGlow() {
    return Positioned(
      top: -80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primaryContainer.withValues(alpha: 0.18),
                AppColors.background.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = screenHeight < 700 ? 70.0 : 80.0;
    
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonAccent.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/images/logo/domfix_logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = screenHeight < 700 ? 0.85 : 1.0;
    
    return Column(
      children: [
        Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28 * scaleFactor,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6 * scaleFactor),
        Text(
          'Sign in to continue',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14 * scaleFactor,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = screenHeight < 700 ? 0.9 : 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: GoogleFonts.inter(
            fontSize: 13 * scaleFactor,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        SizedBox(height: 6 * scaleFactor),
        Container(
          height: 52 * scaleFactor,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.inter(
              color: AppColors.onSurface,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'name@example.com',
              hintStyle: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primaryContainer,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = screenHeight < 700 ? 0.9 : 1.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: GoogleFonts.inter(
            fontSize: 13 * scaleFactor,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        SizedBox(height: 6 * scaleFactor),
        Container(
          height: 52 * scaleFactor,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.inter(
              color: AppColors.onSurface,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primaryContainer,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = screenHeight < 700 ? 0.9 : 1.0;
    
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {},
        child: Text(
          'Forgot Password?',
          style: GoogleFonts.inter(
            fontSize: 13 * scaleFactor,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = screenHeight < 700 ? 50.0 : 54.0;
    final scaleFactor = screenHeight < 700 ? 0.9 : 1.0;
    
    return GestureDetector(
      onTap: _isLoading ? null : _handleEmailSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: buttonHeight,
        decoration: BoxDecoration(
          color: _isLoading ? Colors.grey : AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(32),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign In',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16 * scaleFactor,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.onPrimary,
                      size: 20 * scaleFactor,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = screenHeight < 700 ? 0.9 : 1.0;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: GoogleFonts.inter(
              fontSize: 12 * scaleFactor,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = screenHeight < 700 ? 50.0 : 54.0;
    final scaleFactor = screenHeight < 700 ? 0.9 : 1.0;
    
    return GestureDetector(
      onTap: _isLoading ? null : _handleGoogleSignIn,
      child: Container(
        width: double.infinity,
        height: buttonHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google.png',
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 14 * scaleFactor,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAccount() {
    final screenHeight = MediaQuery.of(context).size.height;
    final scaleFactor = screenHeight < 700 ? 0.9 : 1.0;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
      },
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 13 * scaleFactor,
            color: AppColors.onSurfaceVariant,
          ),
          children: [
            const TextSpan(text: "Don't have an account? "),
            TextSpan(
              text: 'Create Account',
              style: TextStyle(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

