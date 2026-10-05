import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPassword = false;
  String _error = '';

  Future<void> _login() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      await SupabaseService.signIn(email: email, password: password);
      if (mounted) {
        context.go('/admin/dashboard');
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid email or password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient (Mirrors Vue's gradient)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8FAFC),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.44, 1.0],
              ),
            ),
          ),
          
          // Background Orbs
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x296C63FF), // 0.16 opacity
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 360,
              height: 360,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x24A78BFA), // 0.14 opacity
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          
          // Login Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x240F1722), // rgba(15, 23, 42, 0.14)
                      blurRadius: 70,
                      offset: Offset(0, 24),
                    ),
                    BoxShadow(
                      color: Color(0x1F6C63FF), // rgba(108, 99, 255, 0.12)
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.accentBorder),
                      ),
                      child: Text(
                        'PORTFOLIO ADMIN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    // Heading
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in to manage your portfolio content, projects, and articles.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    
                    // Form
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email address', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 18),
                        
                        Text('Password', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            suffixIcon: TextButton(
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                              child: Text(_showPassword ? 'Hide' : 'Show'),
                            ),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                      ],
                    ),
                    
                    // Error Message
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.errorBorder),
                        ),
                        width: double.infinity,
                        child: Text(
                          _error,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.errorText,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 22),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Handled by container gradient
                          padding: EdgeInsets.zero, // Remove padding for gradient container
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF818CF8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x526C63FF), // rgba(108, 99, 255, 0.32)
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ),
                      ),
                    ),
                    
                    // Footer
                    const SizedBox(height: 22),
                    const Divider(height: 1),
                    const SizedBox(height: 18),
                    Text(
                      'Protected area for portfolio administrators only.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
