/// GoAgile Asset Management System (AMS) - Frontend Entry Point
/// 
/// This module orchestrates the entire client-side experience, including:
/// - Organizational authentication flows.
/// - Multi-tenant state management via [AppSession].
/// - Dynamic UI rendering based on organizational department templates.
/// - Real-time QR hardware integration.
/// 
/// Developed by GoAgile Technologies.
/// © 2026 GoAgile Solutions.

import "dart:async";
import "dart:convert";
import "dart:ui" show ImageFilter;

import "package:http/http.dart" as http;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:geocoding/geocoding.dart";
import "package:geolocator/geolocator.dart";
import "package:google_fonts/google_fonts.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "models/admin.dart";
import "models/asset.dart";
import "models/auth.dart";
import "services/api_service.dart";
import "widgets/error_boundary.dart";
import "widgets/asset_edit_sheet.dart";

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class AppTheme {
  static const Color glassBackground = Color(0x1AFFFFFF); // softer opacity
  static const Color glassBorder = Color(0x4DFFFFFF); // slightly stronger border
  static const double glassBlur = 20.0; // deeper blur

  static BoxDecoration glassDecoration({double radius = 20}) => BoxDecoration(
    color: glassBackground,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: glassBorder, width: 0.5),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0x2AFFFFFF), Color(0x0AFFFFFF)],
    ),
  );

  static TextStyle headingStyle = const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static TextStyle bodyStyle = const TextStyle(color: Colors.white70, height: 1.5);

  static ButtonStyle glassButtonStyle({EdgeInsets padding = const EdgeInsets.all(16)}) => ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withOpacity(0.15),
    foregroundColor: Colors.white,
    padding: padding,
    shadowColor: Colors.black26,
    elevation: 4,
    side: const BorderSide(color: glassBorder, width: 0.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint("CRITICAL ERROR: ${details.exception}");
  };
  runApp(
    const GlobalErrorBoundary(
      child: AMSApp(),
    ),
  );
}

class AppSession {
  final String accessToken;
  UserProfile user;

  AppSession({
    required this.accessToken,
    required this.user,
  });
}

class AMSApp extends StatefulWidget {
  const AMSApp({super.key});

  @override
  State<AMSApp> createState() => _AMSAppState();
}

class _AMSAppState extends State<AMSApp> {
  AppSession? _session;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

    Future<void> _loadSession() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(ApiService.sessionTokenKey);
        final userJson = prefs.getString(ApiService.sessionUserKey);
        
        if (token != null && userJson != null) {
          ApiService.setAccessToken(token);
          try {
            // Validate token with backend
            final user = await ApiService.fetchMe();
            if (!mounted) return;
            setState(() {
              _session = AppSession(accessToken: token, user: user);
            });
          } catch (e) {
            // Token is invalid/expired
            await ApiService.clearSession();
            if (!mounted) return;
            setState(() {
              _session = null;
            });
          }
        } else {
          if (!mounted) return;
          setState(() {
            _session = null;
          });
        }
      } catch (_) {
        await ApiService.clearSession();
        if (!mounted) return;
        setState(() {
          _session = null;
        });
      } finally {
        if (mounted) {
          setState(() => _restoringSession = false);
        }
      }
    }
  

  Future<void> _onLoggedIn(LoginResponse login) async {
    await ApiService.saveSession(login.accessToken, login.user);
    if (!mounted) return;
    setState(() {
      _session = AppSession(accessToken: login.accessToken, user: login.user);
    });
  }

  Future<void> _onLogout() async {
    await ApiService.clearSession();
    if (!mounted) return;
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "GoAgile AMS",
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B),
          brightness: Brightness.dark,
          primary: Colors.white,
          surface: const Color(0xFF1E293B),
        ),
        primaryColor: Colors.white,
        textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppTheme.glassBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppTheme.glassButtonStyle(),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF1E293B).withOpacity(0.8),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.glassBorder)),
          textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.glassBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.glassBorder),
          ),
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      home: _restoringSession
          ? const Scaffold(
              backgroundColor: Color(0xFF0F172A),
              body: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          : _session == null
              ? AuthFlow(onLoggedIn: _onLoggedIn)
              : AppShell(
                  session: _session!,
                  onLogout: _onLogout,
                ),
    );
  }
}

class AuthFlow extends StatefulWidget {
  final ValueChanged<LoginResponse> onLoggedIn;

  const AuthFlow({
    super.key,
    required this.onLoggedIn,
  });

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

enum AuthState { landing, login, forgotPassword, scheduleDemo }

class _AuthFlowState extends State<AuthFlow> {
  AuthState _state = AuthState.landing;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case AuthState.landing:
        return _buildLanding();
      case AuthState.login:
        return LoginScreen(
          onBack: () => setState(() => _state = AuthState.landing),
          onLoggedIn: widget.onLoggedIn,
          onForgotPassword: () => setState(() => _state = AuthState.forgotPassword),
        );
      case AuthState.forgotPassword:
        return ForgotPasswordScreen(
          onBack: () => setState(() => _state = AuthState.login),
        );
      case AuthState.scheduleDemo:
        return ScheduleDemoScreen(
          onBack: () => setState(() => _state = AuthState.landing),
        );
    }
  }

  Widget _buildLanding() {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "data/snowy_mountains.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.6),
          ),
          SafeArea(
            child: Center(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2, size: 100, color: Colors.white),
                    const SizedBox(height: 40),
                    const TypewriterText(
                      text: "Welcome to AMS By GoAgile",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 2),
                      builder: (context, value, child) => Opacity(opacity: value, child: child),
                      child: const Text(
                        """Precision. Visibility. Control.
Your inventory, redefined.""",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 20, height: 1.6, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text("v1.0.5 - Data Overhaul", style: TextStyle(fontSize: 10, color: Colors.white24)),
                    const SizedBox(height: 40),
                    
                    // PRIMARY CTA
                    ElevatedButton(
                      onPressed: () => setState(() => _state = AuthState.login),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(300, 68),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 15,
                        shadowColor: Colors.black.withOpacity(0.5),
                      ),
                      child: const Text(
                        "Enter Dashboard",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    
                    const SizedBox(height: 80),
                    
                    // BENTO GRID FEATURES
                    const Text("Why choose GoAgile?", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildBentoTile(Icons.bolt, "Instant Scanning", "High-speed QR recognition for rapid inventory updates.", width: 200),
                        _buildBentoTile(Icons.public, "Global Reach", "Track assets across multiple cities and international locations.", width: 240),
                        _buildBentoTile(Icons.security, "Role-Based Access", "Secure permissions for admins, workers, and super-users.", width: 220),
                        _buildBentoTile(Icons.analytics_outlined, "Real-time Stats", "Live insights into your global asset distribution.", width: 200),
                      ],
                    ),

                    const SizedBox(height: 80),
                    
                    // FINAL DEMO CTA
                    Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      padding: const EdgeInsets.all(32),
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        children: [
                          const Text(
                            "Ready to transform your workflow?",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Join industry leaders who trust GoAgile for their critical asset infrastructure.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 15),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: () => setState(() => _state = AuthState.scheduleDemo),
                            style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18)),
                            child: const Text("Schedule a Free Demo", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildBentoTile(IconData icon, String title, String desc, {double width = 200}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class ScheduleDemoScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ScheduleDemoScreen({super.key, required this.onBack});

  @override
  State<ScheduleDemoScreen> createState() => _ScheduleDemoScreenState();
}

class _ScheduleDemoScreenState extends State<ScheduleDemoScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final companyCtrl = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back))),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset("data/snowy_mountains.jpg", fit: BoxFit.cover)),
          Container(color: Colors.black.withOpacity(0.6)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _sent ? _buildSuccess() : _buildForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Schedule a Demo", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text("Fill in your details and we'll be in touch.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 32),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
        const SizedBox(height: 16),
        TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Work Email")),
        const SizedBox(height: 16),
        TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: "Company Name")),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => setState(() => _sent = true),
            style: AppTheme.glassButtonStyle(),
            child: const Text("Request Demo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent),
        const SizedBox(height: 24),
        const Text("Request Sent!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text("Thank you for your interest. A GoAgile representative will contact you shortly to schedule your personalized demo.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 32),
        TextButton(onPressed: widget.onBack, child: const Text("Back to Home")),
      ],
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.duration, (timer) {
      if (_index < widget.text.length) {
        if (mounted) {
          setState(() {
            _displayedText += widget.text[_index];
            _index++;
          });
          // Play a subtle click sound
          try { 
            SystemSound.play(SystemSoundType.click); 
          } catch (_) {}
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
      textAlign: TextAlign.center,
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onForgotPassword;
  final ValueChanged<LoginResponse> onLoggedIn;

  const LoginScreen({
    super.key,
    required this.onBack,
    required this.onForgotPassword,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  int _failedCount = 0;

  bool _showPassword = false;
  String? _userFullName;
  String? _userAvatar;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_usernameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.checkUser(_usernameController.text);
      if (res["exists"] == true) {
        setState(() {
          _showPassword = true;
          _userFullName = res["full_name"];
          _userAvatar = res["profile_picture"];
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (!_showPassword) {
      _handleNext();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final login = await ApiService.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _failedCount = 0;
      widget.onLoggedIn(login);
    } catch (error) {
      if (!mounted) return;
      _failedCount++;
      
      String msg = error.toString();
      if (_failedCount >= 3) {
        final reset = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Multiple Failed Attempts"),
            content: const Text("It looks like you're having trouble logging in. Would you like to reset your password?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Try Again")),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Reset Password"), style: AppTheme.glassButtonStyle(padding: const EdgeInsets.all(12))),
            ],
          ),
        );
        if (reset == true) {
          widget.onForgotPassword();
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (_showPassword) {
              setState(() {
                _showPassword = false;
                _passwordController.clear();
              });
            } else {
              widget.onBack();
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "data/snowy_mountains.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showPassword) ...[
                            _buildAvatar(),
                            const SizedBox(height: 16),
                            Text(
                              _userFullName ?? "Welcome Back",
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(_usernameController.text, style: const TextStyle(color: Colors.white60)),
                          ] else ...[
                            const Icon(Icons.inventory_2, size: 60, color: Colors.white),
                            const SizedBox(height: 24),
                            const Text(
                              "Welcome Back",
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text("Sign in to manage your assets", style: TextStyle(color: Colors.white70)),
                          ],
                          const SizedBox(height: 32),
                          
                          if (!_showPassword)
                            TextField(
                              controller: _usernameController,
                              onSubmitted: (_) => _handleNext(),
                              decoration: const InputDecoration(
                                labelText: "Username or Email",
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                          
                          if (_showPassword)
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              onSubmitted: (_) => _login(),
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                ),
                              ),
                            ),
                          
                          if (_showPassword) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: widget.onForgotPassword,
                                child: const Text("Forgot password?", style: TextStyle(color: Colors.white70)),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : (_showPassword ? _login : _handleNext),
                              style: AppTheme.glassButtonStyle(padding: EdgeInsets.zero),
                              child: _isLoading && !_showPassword
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Text(_showPassword ? "Sign In" : "Next", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isLoading && _showPassword)
          SizedBox(
            width: 90, height: 90,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        if (_userAvatar != null && _userAvatar!.isNotEmpty)
          _buildAvatarFromUrl(_userAvatar!)
        else
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.1),
            child: const Icon(Icons.person, size: 40, color: Colors.white),
          ),
      ],
    );
  }

  Widget _buildAvatarFromUrl(String url) {
    if (url.startsWith("data:image")) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return CircleAvatar(radius: 40, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    return CircleAvatar(radius: 40, backgroundImage: NetworkImage(url));
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ForgotPasswordScreen({super.key, required this.onBack});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.forgotPassword(_emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("If an account matches your entry, recovery instructions have been sent to the registered email.")),
      );
      widget.onBack();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, color: Colors.white))),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset("data/snowy_mountains.jpg", fit: BoxFit.cover)),
          Container(color: Colors.black.withOpacity(0.3)),
          Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_reset, size: 60, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text("Forgot Password", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text("Enter your registered email or username to receive recovery instructions.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 24),
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email or Username")),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E293B)),
                        child: _isLoading ? const CircularProgressIndicator() : const Text("Recover Account", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
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

class AppShell extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;

  const AppShell({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<AssetsScreenState> _assetsKey = GlobalKey<AssetsScreenState>();
  int _index = 0;
  bool _showWalkthrough = false;
  int _walkthroughStep = 0;

  @override
  void initState() {
    super.initState();
    _checkWalkthrough();
  }

  Future<void> _checkWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool("seen_walkthrough") ?? false;
    if (!seen) {
      if (mounted) setState(() => _showWalkthrough = true);
    }
  }

  Future<void> _finishWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("seen_walkthrough", true);
    if (mounted) setState(() => _showWalkthrough = false);
  }

  Widget _buildWalkthrough() {
    final steps = [
      {"t": "Home Dashboard", "d": "Your summary of total assets and city-wise distribution.", "idx": 0, "align": Alignment.topCenter},
      {"t": "Inventory Management", "d": "View, filter by date, and sort your boxes by city.", "idx": 1, "align": Alignment.bottomCenter},
      {"t": "Quick Scan", "d": "Tap here to instantly register a new asset with QR.", "idx": 2, "align": Alignment.bottomCenter},
      {"t": "Admin Panel", "d": "Manage roles, users, and custom field templates.", "idx": 4, "align": Alignment.bottomCenter},
    ];

    final step = steps[_walkthroughStep];
    
    // Auto-navigate to the relevant tab
    if (_index != step["idx"] && (step["idx"] as int) < 5) {
      Future.microtask(() => setState(() => _index = step["idx"] as int));
    }

    return Stack(
      children: [
        Positioned(
          bottom: 100, // Above the bottom bar
          left: 20,
          right: 20,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Container(
                decoration: AppTheme.glassDecoration(radius: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.tips_and_updates, color: Colors.amber, size: 24),
                              const SizedBox(width: 10),
                              Expanded(child: Text(step["t"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                              IconButton(onPressed: _finishWalkthrough, icon: const Icon(Icons.close, color: Colors.white54, size: 20)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(step["d"] as String, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${_walkthroughStep + 1} / ${steps.length}", style: const TextStyle(color: Colors.white30, fontSize: 12)),
                              ElevatedButton(
                                onPressed: () {
                                  if (_walkthroughStep < steps.length - 1) {
                                    setState(() => _walkthroughStep++);
                                  } else {
                                    _finishWalkthrough();
                                  }
                                },
                                style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                                child: Text(_walkthroughStep < steps.length - 1 ? "Next Tip" : "Done", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // TEMPORARY: Enabled Web for QR testing
    final showScan = !kIsWeb || kIsWeb; 
    final scanIndex = showScan ? 2 : null;
    final tabs = <_TabEntry>[
      _TabEntry(
        label: "Home",
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        page: HomeDashboardScreen(
          session: widget.session,
          showScan: showScan,
          onOpenScan: scanIndex == null
              ? () {}
              : () => setState(() => _index = scanIndex),
          onOpenAssets: () => setState(() => _index = 1),
        ),
      ),
      _TabEntry(
        label: "Assets",
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        page: AssetsScreen(
          key: _assetsKey,
          session: widget.session,
        ),
      ),
      if (showScan)
        _TabEntry(
          label: "Scan",
          icon: Icons.qr_code_scanner_outlined,
          activeIcon: Icons.qr_code_scanner,
          page: ScanScreen(
            session: widget.session,
            isActive: _index == scanIndex,
          ),
        ),
      _TabEntry(
        label: "Profile",
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        page: ProfileScreen(
          session: widget.session,
          onLogout: widget.onLogout,
        ),
      ),
    ];

    if (widget.session.user.isAdmin) {
      tabs.add(
              _TabEntry(
                label: "Admin",
                icon: Icons.admin_panel_settings_outlined,
                activeIcon: Icons.admin_panel_settings,
                        page: AdminScreen(
                          session: widget.session,
                        ),              ),      );
    }

    final resolvedIndex = _index.clamp(0, tabs.length - 1);
    if (resolvedIndex != _index) {
      _index = resolvedIndex;
    }

    return Column(
      children: [
        Expanded(
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    "data/snowy_mountains.jpg",
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(color: Colors.black.withOpacity(0.25)),
                  ),
                ),
                SafeArea(
                  child: IndexedStack(
                    index: resolvedIndex,
                    children: tabs.map((e) => e.page).toList(),
                  ),
                ),
                if (_showWalkthrough) _buildWalkthrough(),
              ],
            ),
            bottomNavigationBar: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: NavigationBar(
                    backgroundColor: const Color(0xFF1E293B).withOpacity(0.4),
                    indicatorColor: Colors.white.withOpacity(0.1),
                    selectedIndex: resolvedIndex,
                    onDestinationSelected: (value) => setState(() => _index = value),
                    destinations: [
                      for (final tab in tabs)
                        NavigationDestination(
                          icon: Icon(tab.icon, color: Colors.white70),
                          selectedIcon: Icon(tab.activeIcon, color: Colors.white),
                          label: tab.label,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabEntry {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _TabEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}

class HomeDashboardScreen extends StatelessWidget {
  final AppSession session;
  final bool showScan;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenAssets;

  const HomeDashboardScreen({
    super.key,
    required this.session,
    required this.showScan,
    required this.onOpenScan,
    required this.onOpenAssets,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        // Reduced heights further to eliminate any possible 6px overflow
        const double headerH = 70;
        const double statsH = 85;
        const double footerH = 110;
        
        return Container(
          width: constraints.maxWidth,
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // HEADER
              SizedBox(
                height: headerH,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Welcome back,", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                        Text(session.user.fullName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      radius: 18,
                      child: Text(session.user.fullName[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              
              // STATS
              SizedBox(
                height: statsH,
                child: FutureBuilder<AssetStats>(
                  future: ApiService.fetchStats(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? const AssetStats(totalAssets: 0, cities: [], projectNames: []);
                    return Row(
                      children: [
                        Expanded(child: _StatCard(title: "Assets", value: "${stats.totalAssets}")),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(title: "Cities", value: "${stats.cities.length}")),
                      ],
                    );
                  },
                ),
              ),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: Opacity(
                        opacity: 0.45, // Significantly increased opacity for visibility
                        child: Image.asset(
                          "data/world_map.png",
                          fit: BoxFit.contain, 
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.public, color: Colors.white10, size: 80),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // FOOTER / ACTIONS
              SizedBox(
                height: footerH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Quick Actions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (showScan) ...[
                          Expanded(child: _QuickActionButton(onPressed: onOpenScan, icon: Icons.qr_code_scanner, label: "Scan")),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: _QuickActionButton(onPressed: onOpenAssets, icon: Icons.search, label: "Search")),
                        const SizedBox(width: 8),
                        Expanded(child: _QuickActionButton(onPressed: onOpenAssets, icon: Icons.inventory_2_outlined, label: "All")),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10), // Bottom padding
            ],
          ),
        );
      },
    );
  }
}

// DASHBOARD HELPER WIDGETS

class _QuickActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _QuickActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddressData {
  final String? city;
  final String? street;
  final String? locality;
  final String? postalCode;
  AddressData({this.city, this.street, this.locality, this.postalCode});
}

class AssetsScreen extends StatefulWidget {
  final AppSession session;

  const AssetsScreen({
    super.key,
    required this.session,
  });

  @override
  State<AssetsScreen> createState() => AssetsScreenState();
}

class AssetsScreenState extends State<AssetsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _city = "ALL";
  String _projectName = "ALL";
  List<String> _cities = [];
  List<String> _projectNames = [];
  List<Department> _departments = [];
  int? _selectedDeptId;
  Timer? _debounce;
  List<Asset> _assets = [];
  bool _isLoading = true;
  
  String _sortBy = "newest"; // newest, oldest
  String _durationLabel = "All Time";
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ApiService.fetchStats();
      final depts = await ApiService.fetchDepartments();
      if (!mounted) return;
      setState(() {
        _cities = stats.cities;
        _projectNames = stats.projectNames;
        _departments = depts;
      });
    } catch (_) {}
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    try {
      var assets = await ApiService.fetchAssets(
        query: _searchController.text,
        city: _city == "ALL" ? null : _city,
        departmentId: _selectedDeptId,
        projectName: _projectName == "ALL" ? null : _projectName,
        attributes: _attributeFilters,
        startDate: _startDate,
        endDate: _endDate,
        sortBy: _sortBy,
      );

      if (!mounted) return;
      setState(() => _assets = assets);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        Navigator.of(context).popUntil((route) => route.isFirst); 
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickCustomRange() async {
    DateTime? start = _startDate ?? DateTime.now();
    DateTime? end = _endDate ?? DateTime.now();

    final range = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF1E293B),
            surface: Color(0xFF0F172A),
          ),
        ),
        child: StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            title: const Text("Select Range", style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Start Date", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(
                    height: 200,
                    child: CalendarDatePicker(
                      initialDate: start!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      onDateChanged: (d) => setLocal(() => start = d),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  const Text("End Date", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(
                    height: 200,
                    child: CalendarDatePicker(
                      initialDate: end!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      onDateChanged: (d) => setLocal(() => end = d),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, DateTimeRange(start: start!, end: end!)),
                child: const Text("Apply"),
              ),
            ],
          ),
        ),
      ),
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _durationLabel = "${DateFormat('MM/dd').format(range.start.toLocal())} - ${DateFormat('MM/dd').format(range.end.toLocal())}";
      });
      _loadAssets();
    }
  }

  List<String> _enabledFilters = ["City", "Department", "project_name", "Date"]; 
  Map<String, String> _attributeFilters = {}; // Key -> Value
  List<DepartmentFieldDefinition> _allPossibleFields = [];

  @override
  void initState() {
    super.initState();
    _loadFilterSettings();
    _loadStats();
    _loadAssets();
    _loadAllFields();
  }

  Future<void> _loadAllFields() async {
    try {
      final depts = await ApiService.fetchDepartments();
      final all = <DepartmentFieldDefinition>[];
      final seenKeys = <String>{};
      for (final d in depts) {
        final fields = await ApiService.fetchDepartmentFields(d.id);
        for (final f in fields) {
          if (!{"asset_name", "city", "building", "floor", "room", "street", "locality", "postal_code", "project_name"}.contains(f.fieldKey)) {
            if (!seenKeys.contains(f.fieldKey)) {
              all.add(f);
              seenKeys.add(f.fieldKey);
            }
          }
        }
      }
      if (mounted) setState(() => _allPossibleFields = all);
    } catch (_) {}
  }

  Future<void> _loadFilterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList("enabled_filters");
    if (saved != null && mounted) {
      // Migrate "Project" to "project_name" and remove duplicates
      final migrated = saved.map((e) => e == "Project" ? "project_name" : e).toSet().toList();
      setState(() => _enabledFilters = migrated);
    }
  }

  Future<void> _saveFilterSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("enabled_filters", _enabledFilters);
  }

  Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {}
    return null;
  }

  Future<AddressData?> _getCityFromPos(Position pos) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return AddressData(
          city: place.locality ?? place.subAdministrativeArea ?? place.administrativeArea,
          street: place.street,
          locality: place.subLocality ?? place.locality,
          postalCode: place.postalCode,
        );
      }
    } catch (_) {}
    return null;
  }

  Widget _buildSearchableDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    required ValueChanged<String> onChanged,
    InputDecoration? decoration,
    bool enabled = true,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: FocusNode(),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == "") return options;
          return options.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        onSelected: (String selection) {
          controller.text = selection;
          onChanged(selection);
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            enabled: enabled,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: decoration ?? InputDecoration(labelText: label),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return ListTile(
                      title: Text(option, style: const TextStyle(color: Colors.white)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600), // Desktop constrained
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Filter Assets", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (widget.session.user.isSuperadmin) // Disabled for others for now
                    TextButton.icon(
                      onPressed: () => _showEditFiltersDialog(),
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text("Edit Filters"),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final fKey in _enabledFilters) ...[
                        if (fKey == "City") ...[
                          const Text("City", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<String>(
                            value: _city,
                            items: ["ALL", ..._cities],
                            onChanged: (v) { setState(() => _city = v!); _loadAssets(); Navigator.pop(context); },
                          ),
                          const SizedBox(height: 16),
                        ] else if (fKey == "Department") ...[
                          const Text("Department", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<int?>(
                            value: _selectedDeptId,
                            items: [null, ..._departments.where((d) => d.name.trim().isNotEmpty).map((d) => d.id)],
                            labelBuilder: (v) {
                              if (v == null) return "All Departments";
                              try {
                                return _departments.firstWhere((d) => d.id == v).name;
                              } catch (_) {
                                return "Unknown";
                              }
                            },
                            onChanged: (v) { setState(() => _selectedDeptId = v); _loadAssets(); Navigator.pop(context); },
                          ),
                          const SizedBox(height: 16),
                        ] else if (fKey == "project_name") ...[
                          const Text("Project", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<String>(
                            value: _projectName,
                            items: ["ALL", ..._projectNames],
                            onChanged: (v) { setState(() => _projectName = v!); _loadAssets(); Navigator.pop(context); },
                          ),
                          const SizedBox(height: 16),
                        ] else if (fKey == "Date") ...[
                          const Text("Date Range", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today, color: Colors.white),
                            title: Text(_durationLabel, style: const TextStyle(color: Colors.white)),
                            onTap: () {
                              Navigator.pop(context);
                              _showDateSelector();
                            },
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          // DYNAMIC FIELD
                          Text(fKey.replaceAll("_", " ").toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            style: const TextStyle(color: Colors.white),
                            onChanged: (v) { 
                              setState(() => _attributeFilters[fKey] = v); 
                              _debounce?.cancel();
                              _debounce = Timer(const Duration(milliseconds: 1000), _loadAssets);
                            },
                            decoration: InputDecoration(
                              hintText: "Filter by ${fKey.replaceAll("_", " ")}...",
                              fillColor: Colors.white.withOpacity(0.05),
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _city = "ALL";
                      _projectName = "ALL";
                      _selectedDeptId = null;
                      _startDate = null;
                      _endDate = null;
                      _durationLabel = "All Time";
                      _attributeFilters.clear();
                    });
                    _loadAssets();
                    Navigator.pop(context);
                  },
                  child: const Text("Clear All Filters", style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDateSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Select Date Range", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            ListTile(title: const Text("All Time"), onTap: () { _updateDateFilter("all"); Navigator.pop(context); }),
            ListTile(title: const Text("This Week"), onTap: () { _updateDateFilter("week"); Navigator.pop(context); }),
            ListTile(title: const Text("This Month"), onTap: () { _updateDateFilter("month"); Navigator.pop(context); }),
            ListTile(title: const Text("This Year"), onTap: () { _updateDateFilter("year"); Navigator.pop(context); }),
            ListTile(title: const Text("Custom Range..."), onTap: () { Navigator.pop(context); _pickCustomRange(); }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _updateDateFilter(String res) {
    setState(() {
      if (res == "year") {
        _startDate = DateTime(DateTime.now().year, 1, 1);
        _durationLabel = "This Year";
      } else {
        _startDate = res == "week" ? DateTime.now().subtract(const Duration(days: 7)) : (res == "month" ? DateTime.now().subtract(const Duration(days: 30)) : null);
        _durationLabel = res == "all" ? "All Time" : (res == "week" ? "This Week" : "This Month");
      }
      _endDate = null;
    });
    _loadAssets();
  }

  Future<void> _registerNewAsset(String token) async {
    final depts = await ApiService.fetchDepartments();
    if (depts.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No departments configured. Contact admin.")));
      return;
    }

    final pos = await _getCurrentPosition();
    AddressData? addr;
    if (pos != null) addr = await _getCityFromPos(pos);

    Department? selectedDept;
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: addr?.city?.toUpperCase() ?? "");
    final bldCtrl = TextEditingController(text: (addr?.locality ?? addr?.street ?? "").toUpperCase());
    final projectCtrl = TextEditingController();
    final dropdowns = await ApiService.fetchDropdowns();
    
    final savedAsset = await showModalBottomSheet<Asset>(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600), // Desktop constrained
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Container(
          decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Register Asset", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedDept?.id,
                  dropdownColor: const Color(0xFF1E293B),
                  items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setLocal(() => selectedDept = depts.firstWhere((d) => d.id == v)),
                  decoration: const InputDecoration(labelText: "Department *"),
                ),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Asset Name *")),
                _buildSearchableDropdown(label: "City", controller: cityCtrl, options: dropdowns.cities, decoration: const InputDecoration(labelText: "City *"), onChanged: (v) => setLocal((){})),
                _buildSearchableDropdown(label: "Building", controller: bldCtrl, options: dropdowns.buildings, decoration: const InputDecoration(labelText: "Building *"), onChanged: (v) => setLocal((){})),
                _buildSearchableDropdown(label: "Project", controller: projectCtrl, options: dropdowns.projectNames, decoration: const InputDecoration(labelText: "Project"), onChanged: (v) => setLocal((){})),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (selectedDept == null || nameCtrl.text.isEmpty) ? null : () async {
                    final attrs = projectCtrl.text.isNotEmpty ? {"project_name": projectCtrl.text.trim()} : <String, dynamic>{};
                    final a = await ApiService.createAsset(
                      token: token, 
                      departmentId: selectedDept!.id, 
                      assetName: nameCtrl.text.trim(), 
                      city: cityCtrl.text.trim().toUpperCase(), 
                      building: bldCtrl.text.trim().toUpperCase(),
                      attributes: attrs,
                    );
      if (!mounted) return;
      Navigator.pop(context, a);
                  },
                  child: const Text("Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (savedAsset != null && mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(session: widget.session, initialAsset: savedAsset, autoOpenEdit: true)));
      _loadStats();
      _loadAssets();
    }
  }

  void _showEditFiltersDialog() {
    final baseFields = ["City", "Department", "Date", "project_name"];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Edit Filters"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text("Base Fields", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                ...baseFields.map((f) => CheckboxListTile(
                  title: Text(f == "project_name" ? "Project" : f),
                  value: _enabledFilters.contains(f),
                  onChanged: (v) {
                    setLocal(() { if (v == true) _enabledFilters.add(f); else _enabledFilters.remove(f); });
                    setState(() {});
                    _saveFilterSettings();
                  },
                )),
                const Divider(),
                const Text("Custom Fields", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                ..._allPossibleFields.map((f) => CheckboxListTile(
                  title: Text(f.label),
                  value: _enabledFilters.contains(f.fieldKey),
                  onChanged: (v) {
                    setLocal(() { if (v == true) _enabledFilters.add(f.fieldKey); else _enabledFilters.remove(f.fieldKey); });
                    setState(() {});
                    _saveFilterSettings();
                  },
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T)? labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E293B),
        items: items.map((i) => DropdownMenuItem<T>(
          value: i,
          child: Text(labelBuilder != null ? labelBuilder(i) : i.toString(), style: const TextStyle(color: Colors.white)),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: AppTheme.glassBlur, sigmaY: AppTheme.glassBlur),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Inventory", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 30),
                          onPressed: _manualRegister,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 400), _loadAssets);
                      },
                      decoration: InputDecoration(
                        hintText: "Search items...",
                        hintStyle: const TextStyle(color: Colors.white70),
                        fillColor: Colors.white.withOpacity(0.05),
                        filled: true,
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showFilterMenu,
                          icon: const Icon(Icons.filter_list, size: 18),
                          label: const Text("Filter by"),
                          style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(_sortBy == "newest" ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white70),
                          onPressed: () {
                            setState(() => _sortBy = (_sortBy == "newest" ? "oldest" : "newest"));
                            _loadAssets();
                          },
                          tooltip: _sortBy == "newest" ? "Newest First" : "Oldest First",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Showing ${_assets.length} assets", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              if (_city != "ALL" || _durationLabel != "All Time")
                Chip(
                  label: const Text("Filtered", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)), 
                  backgroundColor: const Color(0xFF1E293B).withOpacity(0.6),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async { await _loadStats(); await _loadAssets(); },
                  child: _assets.isEmpty
                      ? ListView(children: const [SizedBox(height: 100), Center(child: Text("No matches found", style: TextStyle(color: Colors.white54)))])
                                              : ListView.builder(
                                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                                                  itemCount: _assets.length,
                                                  itemBuilder: (context, index) {
                                                    final asset = _assets[index];
                                                    return TweenAnimationBuilder<double>(
                                                      duration: Duration(milliseconds: 300 + (index.clamp(0, 10) * 100)),
                                                      tween: Tween(begin: 0.0, end: 1.0),
                                                      builder: (context, value, child) {
                                                        return Opacity(
                                                          opacity: value,
                                                          child: Transform.translate(
                                                            offset: Offset(0, 30 * (1 - value)),
                                                            child: child,
                                                          ),
                                                        );
                                                      },
                                                                                                              child: Card(
                                                                                                                margin: const EdgeInsets.only(bottom: 12),
                                                                                                                elevation: 4,
                                                                                                                shadowColor: Colors.black45,
                                                                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                                                                color: const Color(0xFF1E293B).withOpacity(0.8),
                                                                                                                child: InkWell(
                                                                                                                  borderRadius: BorderRadius.circular(16),
                                                                                                                  onTap: () => _openAsset(asset),
                                                                                                                  child: Padding(
                                                                                                                    padding: const EdgeInsets.all(12),
                                                                                                                    child: Row(
                                                                                                                      children: [
                                                                                                                        Hero(tag: "asset_img_${asset.id}", child: _buildImageThumbnail(asset.imageUrl)),
                                                                                                                        const SizedBox(width: 16),
                                                                                                                        Expanded(
                                                                                                                          child: Column(
                                                                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                                            children: [
                                                                                                                              Row(
                                                                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                                                children: [
                                                                                                                                  Expanded(child: Text(asset.assetName ?? "Unnamed Asset", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis)),
                                                                                                                                  Container(
                                                                                                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                                                                                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                                                                                                                    child: Text(_departments.firstWhere((d) => d.id == asset.departmentId, orElse: () => Department(id: 0, tenantId: 0, name: "-", code: "??")).code, style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                                                                                                  ),
                                                                                                                                ],
                                                                                                                              ),
                                                                                                                              const SizedBox(height: 6),
                                                                                                                              Row(
                                                                                                                                children: [
                                                                                                                                  const Icon(Icons.location_on, size: 14, color: Colors.white54),
                                                                                                                                  const SizedBox(width: 4),
                                                                                                                                  Expanded(child: Text("${asset.city ?? 'Unknown'} • ${asset.building ?? ''}", style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                                                                                                                ],
                                                                                                                              ),
                                                                                                                              const SizedBox(height: 6),
                                                                                                                              Text(DateFormat('MMM d, yyyy').format(asset.createdAt.toLocal()), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                                                                                                            ],
                                                                                                                          ),
                                                                                                                        ),
                                                                                                                        const SizedBox(width: 8),
                                                                                                                        const Icon(Icons.chevron_right, size: 24, color: Colors.white30),
                                                                                                                      ],
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ),                                                    );
                                                  },
                                                ),
                      
                ),
        ),
      ],
    );
  }

  Future<void> _openAsset(Asset asset) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(session: widget.session, initialAsset: asset)));
    await _loadStats();
    await _loadAssets();
  }

  Future<void> _manualRegister() async {
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text("Manual Register"),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Enter unique token")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), 
              style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text("Register", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
    if (token != null && token.isNotEmpty) {
      try {
        final res = await ApiService.fetchAssetByQr(token);
        if (!mounted) return;
        if (!res.isNew) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR already exists. Opening asset details...")));
        }
        await Navigator.push(context, MaterialPageRoute(builder: (_) => AssetDetailScreen(session: widget.session, initialAsset: res.asset, autoOpenEdit: res.isNew)));
        _loadStats();
        _loadAssets();
      } catch (e) {
        if (mounted) {
          if (e is ApiException && e.statusCode == 404) {
            await _registerNewAsset(token);
            _loadStats();
            _loadAssets();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      }
    }
  }

  Widget _buildImageThumbnail(String? url) {
    if (url == null || url.isEmpty) return const CircleAvatar(child: Icon(Icons.inventory_2, size: 20));
    if (url.startsWith("data:image")) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return CircleAvatar(backgroundImage: MemoryImage(bytes));
      } catch (_) { return const CircleAvatar(child: Icon(Icons.broken_image)); }
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}

class ScanScreen extends StatefulWidget {
  final AppSession session;
  final bool isActive;

  const ScanScreen({
    super.key,
    required this.session,
    required this.isActive,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver, RouteAware {
  final TextEditingController _manualController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isResolving = false;
  String? _lastToken;
  bool _scannerRunning = false;
  bool _isTransitioning = false;
  bool _hasCameraError = false;
  CameraFacing _facing = CameraFacing.back;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  void _initController() {
    setState(() => _hasCameraError = false);
    _scannerController = MobileScannerController(
      autoStart: false,
      torchEnabled: false,
      facing: _facing,
    );
    _updateScannerState();
  }

  void _toggleCamera() async {
    setState(() {
      _facing = _facing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
    });
    await _stopScanner();
    _scannerController?.dispose();
    _initController();
  }

  Future<void> _pickImageAndScan() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null && _scannerController != null) {
        final result = await _scannerController!.analyzeImage(image.path);
        if (result != null && result.barcodes.isNotEmpty) {
           final val = result.barcodes.first.rawValue;
           if (val != null) _resolveToken(val);
        } else {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No QR code found in image.")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _stopScanner();
  }

  @override
  void didPopNext() {
    _updateScannerState();
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _updateScannerState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _startScanner();
    } else {
      _stopScanner();
    }
  }

  void _updateScannerState() {
    debugPrint("DEBUG: _updateScannerState called. isActive: ${widget.isActive}");
    if (!widget.isActive) {
      debugPrint("DEBUG: Stopping scanner because widget is not active.");
      _stopScanner();
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    debugPrint("DEBUG: App lifecycle state: $lifecycle");
    // On Desktop, lifecycle can be null. We should allow it to proceed to start.
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      debugPrint("DEBUG: Stopping scanner because app is not resumed.");
      _stopScanner();
      return;
    }
    _startScanner();
  }

  Future<void> _startScanner() async {
    debugPrint("DEBUG: _startScanner triggered. Running: $_scannerRunning, Transitioning: $_isTransitioning");
    if (_scannerController == null || _scannerRunning || _isTransitioning || !mounted) return;
    _isTransitioning = true;
    try {
      debugPrint("DEBUG: Calling _scannerController!.start()");
      await _scannerController!.start();
      if (mounted) setState(() {
        _scannerRunning = true;
        _hasCameraError = false;
      });
      debugPrint("DEBUG: Scanner started successfully.");
    } catch (e) {
      debugPrint("DEBUG: Scanner Start Error: $e");
      // Force clean state on error to prevent "already running" issues
      if (mounted) setState(() {
        _scannerRunning = false;
        _hasCameraError = true;
      });
      try { await _scannerController?.stop(); } catch (_) {}
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _stopScanner() async {
    debugPrint("DEBUG: _stopScanner triggered. Running: $_scannerRunning, Transitioning: $_isTransitioning");
    if (_scannerController == null || !_scannerRunning || _isTransitioning) return;
    _isTransitioning = true;
    try {
      debugPrint("DEBUG: Calling _scannerController!.stop()");
      await _scannerController!.stop();
      if (mounted) setState(() => _scannerRunning = false);
      debugPrint("DEBUG: Scanner stopped successfully.");
    } catch (e) {
      debugPrint("DEBUG: Scanner Stop Error: $e");
    } finally {
      _isTransitioning = false;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _manualController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }
  Future<AddressData?> _getCityFromPos(Position pos) async {
    try {
      if (kIsWeb) {
        final res = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18'
        ));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final addr = data['address'];
          return AddressData(
            city: addr?['city'] ?? addr?['town'] ?? addr?['village'] ?? addr?['suburb'],
            street: addr?['road'],
            locality: addr?['neighbourhood'] ?? addr?['suburb'],
            postalCode: addr?['postcode'],
          );
        }
        return null;
      }
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return AddressData(
          city: p.locality,
          street: p.street,
          locality: p.subLocality,
          postalCode: p.postalCode,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> _resolveToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty || _isResolving) return;
    if (_lastToken == trimmed) return;

    setState(() {
      _isResolving = true;
      _lastToken = trimmed;
    });

    try {
      // 1. Stop scanner immediately
      await _stopScanner();
      _scannerController?.dispose();
      _scannerController = null;
      if (mounted) setState(() => _scannerRunning = false);
      
      // Give hardware a breath
      await Future.delayed(const Duration(milliseconds: 300));

      final res = await ApiService.fetchAssetByQr(trimmed);
      
      if (!mounted) return;
      
      // Navigate to detail screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssetDetailScreen(
            session: widget.session,
            initialAsset: res.asset,
            autoOpenEdit: res.isNew, // Open edit modal only for new assets
          ),
        ),
      );
      
      // Restart scanner after return
      _initController();
      await Future.delayed(const Duration(milliseconds: 500));
      _updateScannerState();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 404) {
        // Start registration for new QR
        await _registerNewAsset(trimmed);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      _updateScannerState();
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _lastToken = null;
        });
      }
    }
  }

  Future<void> _registerNewAsset(String token) async {
    final depts = await ApiService.fetchDepartments();
    if (depts.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No departments configured. Contact admin.")));
      return;
    }

    final pos = await _getCurrentPosition();
    AddressData? addr;
    if (pos != null) addr = await _getCityFromPos(pos);

    if (!mounted) return;

    Department? selectedDept;
    final nameController = TextEditingController();
    final cityController = TextEditingController(text: addr?.city?.toUpperCase() ?? "");
    final bldController = TextEditingController(text: (addr?.locality ?? addr?.street ?? "").toUpperCase());
    final floorController = TextEditingController();
    final roomController = TextEditingController();
    final projectCtrl = TextEditingController();

    final dropdowns = await ApiService.fetchDropdowns();
    await _stopScanner();
    _scannerController?.dispose();
    _scannerController = null;
    if (mounted) setState(() => _scannerRunning = false);

    final savedAsset = await showModalBottomSheet<Asset>(
          context: context, 
          isScrollControlled: true, 
          backgroundColor: Colors.transparent,
          constraints: const BoxConstraints(maxWidth: 600), // Desktop constrained
          builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Register New Asset", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text("Token: $token", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 20),
                
                                 // Department selection
                                 DropdownButtonFormField<int>(
                                   value: selectedDept?.id,
                                   dropdownColor: const Color(0xFF1E293B),
                                   items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(color: Colors.white)))).toList(),
                                   onChanged: (v) => setLocal(() => selectedDept = depts.firstWhere((d) => d.id == v)),
                                   decoration: const InputDecoration(labelText: "Select Department *"),
                                 ),                const SizedBox(height: 16),

                // Dynamic Asset Name Dropdown
                _buildSearchableDropdown(
                  label: "Asset Name *",
                  controller: nameController,
                  options: dropdowns.assetNames,
                  onChanged: (v) => setLocal(() {}),
                ),
                const SizedBox(height: 16),

                _buildSearchableDropdown(
                  label: "City *",
                  controller: cityController,
                  options: dropdowns.cities,
                  onChanged: (v) => setLocal(() {}),
                ),
                const SizedBox(height: 16),

                _buildSearchableDropdown(
                  label: "Building/Site *",
                  controller: bldController,
                  options: dropdowns.buildings,
                  onChanged: (v) => setLocal(() {}),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: _buildSearchableDropdown(label: "Floor", controller: floorController, options: dropdowns.floors, onChanged: (v) => setLocal(() {}))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSearchableDropdown(label: "Room/Zone", controller: roomController, options: dropdowns.rooms, onChanged: (v) => setLocal(() {}))),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSearchableDropdown(label: "Project", controller: projectCtrl, options: dropdowns.projectNames, onChanged: (v) => setLocal(() {})),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (selectedDept == null || nameController.text.isEmpty || cityController.text.isEmpty || bldController.text.isEmpty)
                      ? null 
                      : () async {
                        try {
                          final attrs = projectCtrl.text.isNotEmpty ? {"project_name": projectCtrl.text.trim()} : <String, dynamic>{};
                          final a = await ApiService.createAsset(
                            token: token,
                            departmentId: selectedDept!.id,
                            assetName: nameController.text.trim(),
                            city: cityController.text.trim().toUpperCase(),
                            building: bldController.text.trim().toUpperCase(),
                            floor: floorController.text.trim().toUpperCase(),
                            room: roomController.text.trim().toUpperCase(),
                            attributes: attrs,
                          );
                          if (context.mounted) Navigator.pop(context, a);
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                    style: AppTheme.glassButtonStyle(),
                    child: const Text("Register Asset", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (savedAsset != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AssetDetailScreen(session: widget.session, initialAsset: savedAsset, autoOpenEdit: true)),
      );
    }
    _initController();
    await Future.delayed(const Duration(milliseconds: 500));
    _updateScannerState();
  }

  Widget _buildSearchableDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: FocusNode(),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == "") {
            return options;
          }
          return options.where((String option) {
            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
          });
        },
        onSelected: (String selection) {
          controller.text = selection;
          onChanged(selection);
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            onChanged: onChanged,
            decoration: InputDecoration(labelText: label),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return ListTile(
                      title: Text(option, style: const TextStyle(color: Colors.white)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: AppTheme.glassDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: AppTheme.glassBlur, sigmaY: AppTheme.glassBlur),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Scan Asset",
                          style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Position QR code within the frame",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_scannerController?.torchEnabled == true ? Icons.flashlight_on : Icons.flashlight_off, color: Colors.white),
                          onPressed: () => _scannerController?.toggleTorch(),
                        ),
                        IconButton(
                          icon: Icon(_facing == CameraFacing.back ? Icons.camera_front : Icons.camera_rear, color: Colors.white),
                          onPressed: _toggleCamera,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: Container(
            decoration: AppTheme.glassDecoration(radius: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _hasCameraError 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.no_photography_outlined, color: Colors.white24, size: 64),
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Live camera is blocked on insecure (non-HTTPS) connections.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickImageAndScan,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text("Take Photo / Upload QR"),
                          style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                        ),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _initController, child: const Text("Retry Live Camera")),
                      ],
                    ),
                  )
                : (_scannerController != null ? MobileScanner(
                    key: ValueKey("$_scannerRunning|$_facing"),
                    controller: _scannerController!,
                    onDetect: (capture) {
                      final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                      final value = barcode?.rawValue;
                      if (value != null && !_isResolving) {
                        _resolveToken(value);
                      }
                    },
                    errorBuilder: (context, error) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            const Text("Camera Error", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(error.errorCode.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _initController, child: const Text("Retry")),
                          ],
                        ),
                      );
                    },
                  ) : const Center(child: CircularProgressIndicator())),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _manualController,
          decoration: const InputDecoration(
            labelText: "Enter QR token manually",
            prefixIcon: Icon(Icons.keyboard),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _resolveToken(_manualController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.glassBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text("Find Asset", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        if (_isResolving) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(color: Colors.white24, backgroundColor: Colors.transparent),
        ],
      ],
    );
  }
}
class AssetDetailScreen extends StatefulWidget {
  final AppSession session;
  final Asset initialAsset;
  final bool autoOpenEdit;

  const AssetDetailScreen({
    super.key,
    required this.session,
    required this.initialAsset,
    this.autoOpenEdit = false,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late Asset _asset;
  bool _loading = true;
  List<DepartmentFieldDefinition> _fields = [];
  List<AssetEvent> _events = [];
  List<Department> _allDepts = [];
  AssetDropdowns? _dropdowns;
  XFile? _pickedXFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _asset = widget.initialAsset;
    final refreshFuture = _refresh();
    if (widget.autoOpenEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await refreshFuture;
        _editAsset();
      });
    }
  }

  String _displayValue(String key) {
    switch (key) {
      case "department":
        return _asset.departmentId != null ? _asset.departmentId.toString() : "-";
      case "asset_name": return _asset.assetName ?? "";
      case "city": return _asset.city ?? "";
      case "building": return _asset.building ?? "";
      case "floor": return _asset.floor ?? "";
      case "room": return _asset.room ?? "";
      case "street": return _asset.street ?? "";
      case "locality": return _asset.locality ?? "";
      case "postal_code": return _asset.postalCode ?? "";
      case "valid_till":
        return _asset.validTill != null ? DateFormat("yyyy-MM-dd").format(_asset.validTill!.toLocal()) : "";
      case "latitude": return _asset.latitude?.toString() ?? "";
      case "longitude": return _asset.longitude?.toString() ?? "";
      default:
        return _asset.attributes[key]?.toString() ?? "";
    }
  }

  String _buildLocationHierarchy() {
    final parts = [
      _asset.building,
      _asset.floor != null && _asset.floor!.isNotEmpty ? "Floor ${_asset.floor}" : null,
      _asset.room != null && _asset.room!.isNotEmpty ? "Room ${_asset.room}" : null,
      _asset.street,
      _asset.locality,
      _asset.city,
      _asset.postalCode,
    ].where((e) => e != null && e.trim().isNotEmpty).toList();
    
    if (parts.isEmpty) return "No address available";
    return parts.join(", ");
  }

  bool _canEditField(DepartmentFieldDefinition field) {
    if (widget.session.user.isAdmin) return true;
    return field.editableByRoles.contains(widget.session.user.role);
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  Future<AddressData?> _getCityFromPos(Position pos) async {
    try {
      if (kIsWeb) {
        final res = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18'
        ));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final addr = data['address'];
          return AddressData(
            city: addr?['city'] ?? addr?['town'] ?? addr?['village'] ?? addr?['suburb'],
            street: addr?['road'],
            locality: addr?['neighbourhood'] ?? addr?['suburb'],
            postalCode: addr?['postcode'],
          );
        }
        return null;
      }
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return AddressData(
          city: p.locality,
          street: p.street,
          locality: p.subLocality,
          postalCode: p.postalCode,
        );
      }
    } catch (_) {}
    return null;
  }

  Widget _buildSearchableDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required InputDecoration decoration,
    bool enabled = true,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<String>(
        textEditingController: controller,
        focusNode: FocusNode(),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == "") return options;
          return options.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        onSelected: (String selection) {
          controller.text = selection;
          onChanged(selection);
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            enabled: enabled,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: decoration,
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return ListTile(
                      title: Text(option, style: const TextStyle(color: Colors.white)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageWidget(String? url, {double height = 200, double width = double.infinity}) {
    if (url == null || url.isEmpty) {
      return Container(
        height: height, width: width,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.image, size: 50, color: Colors.white24),
      );
    }
    if (url.startsWith("data:image")) {
      try {
        final base64String = url.split(',').last;
        return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(base64String), height: height, width: width, fit: BoxFit.cover));
      } catch (_) { return const Center(child: Text("Invalid Image")); }
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, height: height, width: width, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)));
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final asset = await ApiService.fetchAsset(_asset.id);
      final fields = await ApiService.fetchAssetFields(_asset.id);
      final events = await ApiService.fetchAssetEvents(_asset.id);
      final dropdowns = await ApiService.fetchDropdowns();
      final depts = await ApiService.fetchDepartments();
      if (!mounted) return;
      setState(() { 
        _asset = asset; 
        _fields = fields; 
        _events = events; 
        _dropdowns = dropdowns; 
        _allDepts = depts;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAsset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete asset"),
        content: const Text("Permanently delete this asset?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete")),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteAsset(_asset.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pickImage(ImageSource source, StateSetter setLocal) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1024);
    if (picked != null) setLocal(() => _pickedXFile = picked);
  }

  Widget _buildFieldLabel(String label, bool required) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
      if (required) const Text(" *", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
    ]);
  }

  Future<void> _editAsset() async {
    final depts = await ApiService.fetchDepartments();
    int? selectedDeptId = _asset.departmentId;
    final nameController = TextEditingController(text: _asset.assetName);
    final cityController = TextEditingController(text: _asset.city);
    final buildingController = TextEditingController(text: _asset.building);
    final floorController = TextEditingController(text: _asset.floor);
    final roomController = TextEditingController(text: _asset.room);
    final streetController = TextEditingController(text: _asset.street);
    final localityController = TextEditingController(text: _asset.locality);
    final postalCodeController = TextEditingController(text: _asset.postalCode);
    double? latitude = _asset.latitude;
    double? longitude = _asset.longitude;
    bool isUpdatingGps = false;
    _pickedXFile = null;

    final dynamicControllers = <String, TextEditingController>{};
    List<DepartmentFieldDefinition> activeFields = List.from(_fields);

    void initializeControllers() {
      for (final field in activeFields) {
        if (_canEditField(field) && !{"asset_name", "city", "building", "floor", "room", "street", "locality", "postal_code", "latitude", "longitude"}.contains(field.fieldKey)) {
          if (!dynamicControllers.containsKey(field.fieldKey)) {
            dynamicControllers[field.fieldKey] = TextEditingController(text: _displayValue(field.fieldKey));
          }
        }
      }
    }
    initializeControllers();

    final saved = await showModalBottomSheet<bool>(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          void triggerGps() async {
            if (isUpdatingGps) return;
            setLocal(() => isUpdatingGps = true);
            final pos = await _getCurrentPosition();
            if (pos != null) {
              latitude = pos.latitude;
              longitude = pos.longitude;
              final addr = await _getCityFromPos(pos);
              if (addr != null && mounted) {
                setLocal(() {
                  if (addr.city != null) cityController.text = addr.city!.toUpperCase();
                  if (addr.street != null) streetController.text = addr.street!;
                  if (addr.locality != null) localityController.text = addr.locality!;
                  if (addr.postalCode != null) postalCodeController.text = addr.postalCode!;
                });
              }
            }
            if (mounted) setLocal(() => isUpdatingGps = false);
          }
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isUpdatingGps == false && latitude == _asset.latitude && longitude == _asset.longitude) {
              triggerGps();
            }
          });

          bool isFormValid() {
            if (selectedDeptId == null) return false;
            if (nameController.text.trim().isEmpty) return false;
            if (cityController.text.trim().isEmpty) return false;
            if (buildingController.text.trim().isEmpty) return false;
            return true;
          }

          InputDecoration decoration(String label, String key, String value, bool isRequired) {
            bool valid = !isRequired || value.trim().isNotEmpty;
            return InputDecoration(
              labelText: "$label${isRequired ? ' *' : ''}", 
              errorText: valid ? null : "Required",
              suffixIcon: (key == "city" && isUpdatingGps) ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
            );
          }

          return Container(
            decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Edit Asset", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (isUpdatingGps) const Text("Updating GPS...", style: TextStyle(fontSize: 12, color: Colors.white54)),
                    IconButton(onPressed: triggerGps, icon: const Icon(Icons.my_location, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 16),
                Center(child: Column(children: [
                  if (_pickedXFile != null) _buildImageWidget(_pickedXFile!.path, height: 120, width: 120) else _buildImageWidget(_asset.imageUrl, height: 120, width: 120),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(onPressed: () => _pickImage(ImageSource.camera, setLocal), icon: const Icon(Icons.camera_alt), label: const Text("Camera")),
                    TextButton.icon(onPressed: () => _pickImage(ImageSource.gallery, setLocal), icon: const Icon(Icons.photo_library), label: const Text("Library")),
                  ]),
                ])),
                const SizedBox(height: 16),
                _buildFieldLabel("Department", true),
                DropdownButtonFormField<int>(
                  value: selectedDeptId,
                  dropdownColor: const Color(0xFF1E293B),
                  items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) async {
                    if (v != null) {
                      final newFields = await ApiService.fetchDepartmentFields(v);
                      setLocal(() {
                        selectedDeptId = v;
                        activeFields = newFields;
                        initializeControllers();
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: "Select Department"),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel("Asset Name", true),
                _buildSearchableDropdown(label: "Name", controller: nameController, options: _dropdowns?.assetNames ?? [], decoration: decoration("Asset Name", "asset_name", nameController.text, true), onChanged: (v) => setLocal((){})),
                const SizedBox(height: 16),
                _buildFieldLabel("Location", true),
                _buildSearchableDropdown(label: "City", controller: cityController, options: _dropdowns?.cities ?? [], decoration: decoration("City", "city", cityController.text, true), onChanged: (v) => setLocal((){})),
                _buildSearchableDropdown(label: "Building", controller: buildingController, options: _dropdowns?.buildings ?? [], decoration: decoration("Building", "building", buildingController.text, true), onChanged: (v) => setLocal((){})),
                
                TextField(controller: streetController, style: const TextStyle(color: Colors.white), decoration: decoration("Street", "street", streetController.text, false), onChanged: (v) => setLocal((){})),
                TextField(controller: localityController, style: const TextStyle(color: Colors.white), decoration: decoration("Locality", "locality", localityController.text, false), onChanged: (v) => setLocal((){})),
                TextField(controller: postalCodeController, style: const TextStyle(color: Colors.white), decoration: decoration("Postal Code", "postal_code", postalCodeController.text, false), onChanged: (v) => setLocal((){})),

                Row(children: [
                  Expanded(child: _buildSearchableDropdown(label: "Floor", controller: floorController, options: _dropdowns?.floors ?? [], decoration: const InputDecoration(labelText: "Floor"), onChanged: (v) => setLocal((){}))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSearchableDropdown(label: "Room", controller: roomController, options: _dropdowns?.rooms ?? [], decoration: const InputDecoration(labelText: "Room"), onChanged: (v) => setLocal((){}))),
                ]),
                const SizedBox(height: 16),
                const Text("Custom Fields", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                for (final field in activeFields) if (_canEditField(field) && !{"asset_name", "city", "building", "floor", "room", "street", "locality", "postal_code", "latitude", "longitude"}.contains(field.fieldKey))
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 8),
                    _buildFieldLabel(field.label, field.required),
                    _buildSearchableDropdown(
                      label: field.label, 
                      controller: dynamicControllers[field.fieldKey]!, 
                      options: field.fieldKey == "project_name" 
                        ? (_dropdowns?.projectNames ?? []) 
                        : (field.fieldKey == "asset_status" 
                          ? (_dropdowns?.statuses ?? [])
                          : (field.fieldKey == "asset_condition"
                            ? (_dropdowns?.conditions ?? [])
                            : (_dropdowns?.customAttributes[field.fieldKey] ?? []))), 
                      decoration: decoration(field.label, field.fieldKey, dynamicControllers[field.fieldKey]!.text, field.required), 
                      onChanged: (v) => setLocal((){})
                    ),
                  ]),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isFormValid() ? () => Navigator.pop(context, true) : null, child: const Text("Save Changes"))),
              ]),
            ),
          );
        },
      ),
    );

    if (saved == true) {
      setState(() => _loading = true);
      try {
        String? imageBase64;
        if (_pickedXFile != null) {
          final bytes = await _pickedXFile!.readAsBytes();
          imageBase64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
        }
        
        final attrs = <String, dynamic>{};
        for (final field in activeFields) {
          final key = field.fieldKey;
          if (!{"asset_name", "city", "building", "floor", "room", "street", "locality", "postal_code", "latitude", "longitude"}.contains(key)) {
            if (dynamicControllers.containsKey(key)) {
              attrs[key] = dynamicControllers[key]!.text.trim();
            }
          }
        }

        await ApiService.updateAsset(
          assetId: _asset.id, 
          departmentId: selectedDeptId,
          assetName: nameController.text.trim(),
          city: cityController.text.trim().toUpperCase(), building: buildingController.text.trim().toUpperCase(),
          floor: floorController.text.trim().toUpperCase(), room: roomController.text.trim().toUpperCase(),
          street: streetController.text.trim(), locality: localityController.text.trim(), postalCode: postalCodeController.text.trim(),
          latitude: latitude, longitude: longitude, imageBase64: imageBase64, attributes: attrs,
        );
        await _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.session.user.isAdmin || _fields.any((f) => f.editableByRoles.contains(widget.session.user.role));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(_asset.assetName ?? "Asset Details"), actions: [if (widget.session.user.isAdmin) IconButton(onPressed: _deleteAsset, icon: const Icon(Icons.delete_outline, color: Colors.red))]),
      body: Stack(children: [
        Positioned.fill(child: Image.asset("data/snowy_mountains.jpg", fit: BoxFit.cover)),
        Container(color: Colors.black.withOpacity(0.4)),
        _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: kToolbarHeight + 20),
            _buildImageWidget(_asset.imageUrl),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Location", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (_asset.mapsUrl != null)
                    IconButton(
                      icon: const Icon(Icons.map_outlined, color: Colors.blueAccent),
                      onPressed: () => launchUrl(Uri.parse(_asset.mapsUrl!)),
                      tooltip: "Open in Google Maps",
                    ),
                ],
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.apartment, color: Colors.white70),
                title: Text(_allDepts.firstWhere((d) => d.id == _asset.departmentId, orElse: () => Department(id: 0, tenantId: 0, name: "Not Assigned", code: "-")).name),
                subtitle: const Text("Department"),
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Colors.white70), 
                title: Text(_buildLocationHierarchy()), 
                subtitle: const Text("Full Address"),
              ),
            ]))),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const Divider(color: Colors.white10),
              for (final field in _fields) if (_displayValue(field.fieldKey).isNotEmpty || field.visibleWhenBlank)
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                  Expanded(child: Text(field.label, style: const TextStyle(color: Colors.white70))),
                  Expanded(child: Text(_displayValue(field.fieldKey), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                ])),
            ]))),
          ]),
        ),
      ]),
      floatingActionButton: canEdit ? FloatingActionButton.extended(onPressed: _editAsset, label: const Text("Edit"), icon: const Icon(Icons.edit)) : null,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isUpdating = false;

  Future<void> _changeAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked != null) {
      setState(() => _isUpdating = true);
      try {
        final bytes = await picked.readAsBytes();
        final base64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
        final updated = await ApiService.updateProfile(profilePicture: base64);
        widget.session.user = updated;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: widget.session.user.fullName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Full Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (saved == true) {
      setState(() => _isUpdating = true);
      try {
        final updated = await ApiService.updateProfile(fullName: ctrl.text.trim());
        widget.session.user = updated;
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final confirmPass = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPass, obscureText: true, decoration: const InputDecoration(labelText: "Current Password")),
            const SizedBox(height: 12),
            TextField(controller: newPass, obscureText: true, decoration: const InputDecoration(labelText: "New Password")),
            const SizedBox(height: 12),
            TextField(controller: confirmPass, obscureText: true, decoration: const InputDecoration(labelText: "Confirm New Password")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (newPass.text != confirmPass.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New passwords do not match")));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text("Update", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (saved == true) {
      setState(() => _isUpdating = true);
      try {
        await ApiService.changePassword(oldPassword: oldPass.text, newPassword: newPass.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully!")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text("My Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 32),
        Center(
          child: Stack(
            children: [
              _buildAvatar(user.profilePicture),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _isUpdating ? null : _changeAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.camera_alt, size: 20, color: const Color(0xFF1E293B)),
                  ),
                ),
              ),
              if (_isUpdating)
                const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    IconButton(onPressed: _editName, icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(user.email, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Chip(
                  label: Text(user.role.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  side: BorderSide.none,
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                ListTile(
                  onTap: _changePassword,
                  leading: const Icon(Icons.lock_outline, color: Colors.white70),
                  title: Row(
                    children: [
                      const Text("Change Password", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                        child: const Text("NEW", style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.05),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            side: const BorderSide(color: AppTheme.glassBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? url) {
    if (url != null && url.isNotEmpty) {
      if (url.startsWith("data:image")) {
        try {
          final bytes = base64Decode(url.split(',').last);
          return CircleAvatar(radius: 60, backgroundImage: MemoryImage(bytes));
        } catch (_) {}
      }
      return CircleAvatar(radius: 60, backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white.withOpacity(0.1),
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }
}

class AdminScreen extends StatefulWidget {
  final AppSession session;

  const AdminScreen({super.key, required this.session});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RoleType> _roles = [];
  List<AdminUser> _users = [];
  List<Department> _departments = [];
  List<DepartmentFieldDefinition> _fields = [];
  List<Tenant> _tenants = [];
  Map<String, dynamic> _tenantConfig = {};
  Department? _selectedDepartment;
  bool _loading = true;
  bool _isConfigEditing = false;
  String _assetNamePrefix = "Box";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.session.user.isSuperadmin ? 6 : 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    // Preserve current tab index
    final currentTab = _tabController.index;
    
    setState(() => _loading = true);
    try {
      final roles = await ApiService.fetchRoles();
      final users = await ApiService.fetchUsers();
      final departments = await ApiService.fetchDepartments();
      final config = await ApiService.getTenantConfig();
      List<Tenant> tenants = [];
      if (widget.session.user.isSuperadmin) {
        tenants = await ApiService.fetchTenants();
      }

      List<DepartmentFieldDefinition> fields = [];
      Department? selectedDepartment;
      if (departments.isNotEmpty) {
        selectedDepartment = _selectedDepartment ?? departments.first;
        fields = await ApiService.fetchDepartmentFields(selectedDepartment.id);
      }
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _users = users;
        _departments = departments;
        _selectedDepartment = selectedDepartment;
        _fields = fields;
        _tenants = tenants;
        _tenantConfig = config;
        _tabController.index = currentTab < _tabController.length ? currentTab : 0;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveTenantConfig(Map<String, dynamic> config) async {
    setState(() => _loading = true);
    try {
      await ApiService.updateTenantConfig(config);
      await _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildConfigTab() {
    final prefixController = TextEditingController(text: _tenantConfig["asset_name_prefix"] ?? "");
    final hostController = TextEditingController(text: _tenantConfig["smtp_host"] ?? "");
    final portController = TextEditingController(text: (_tenantConfig["smtp_port"] ?? "").toString());
    final userController = TextEditingController(text: _tenantConfig["smtp_user"] ?? "");
    final passController = TextEditingController(text: _tenantConfig["smtp_pass"] ?? "");
    final fromAddrController = TextEditingController(text: _tenantConfig["smtp_from_address"] ?? "");
    final fromNameController = TextEditingController(text: _tenantConfig["smtp_from_name"] ?? "");
    final appUrlController = TextEditingController(text: _tenantConfig["app_url"] ?? "http://localhost:8080");
    String encryption = _tenantConfig["smtp_encryption"] ?? "ssl";

    final imapHostController = TextEditingController(text: _tenantConfig["imap_host"] ?? "");
    final imapPortController = TextEditingController(text: (_tenantConfig["imap_port"] ?? "").toString());
    final imapUserController = TextEditingController(text: _tenantConfig["imap_user"] ?? "");
    final imapPassController = TextEditingController(text: _tenantConfig["imap_pass"] ?? "");
    String imapEncryption = _tenantConfig["imap_encryption"] ?? "ssl";

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("General Configuration"),
            IconButton(
              onPressed: () => setState(() => _isConfigEditing = !_isConfigEditing),
              icon: Icon(_isConfigEditing ? Icons.lock_open : Icons.edit, color: Colors.white70),
              tooltip: _isConfigEditing ? "Lock" : "Edit Configuration",
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildConfigCard(
          title: "System Access & Email Links",
          child: Column(
            children: [
              TextField(
                controller: prefixController,
                enabled: _isConfigEditing,
                decoration: const InputDecoration(labelText: "Asset Name Prefix (e.g. Box, Item)"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: appUrlController,
                enabled: _isConfigEditing,
                decoration: const InputDecoration(
                  labelText: "App URL (Email Link DNS)",
                  hintText: "http://192.168.1.140:8080",
                  helperText: "This is the 'DNS' address used for links in automated emails.",
                  helperStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle("SMTP Email Configuration"),
        const SizedBox(height: 8),
        const Text("Configure your own SMTP server to enable automated emails for this tenant.", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        _buildConfigCard(
          title: "Server Details",
          child: Column(
            children: [
              TextField(controller: hostController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "SMTP Host (e.g. smtp.gmail.com)")),
              TextField(controller: portController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "SMTP Port (e.g. 465 or 587)"), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                value: encryption,
                items: const [
                  DropdownMenuItem(value: "ssl", child: Text("SSL (Port 465)")),
                  DropdownMenuItem(value: "starttls", child: Text("STARTTLS (Port 587)")),
                ],
                onChanged: _isConfigEditing ? (v) => encryption = v! : null,
                decoration: const InputDecoration(labelText: "Encryption"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildConfigCard(
          title: "Authentication",
          child: Column(
            children: [
              TextField(controller: userController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "SMTP Username")),
              TextField(controller: passController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "SMTP Password"), obscureText: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildConfigCard(
          title: "Sender Information",
          child: Column(
            children: [
              TextField(controller: fromAddrController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "From Email Address")),
              TextField(controller: fromNameController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "From Display Name")),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle("IMAP Support Configuration"),
        const SizedBox(height: 8),
        const Text("Configure IMAP to allow the system to read incoming support emails.", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        _buildConfigCard(
          title: "IMAP Server Details",
          child: Column(
            children: [
              TextField(controller: imapHostController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "IMAP Host (e.g. imap.gmail.com)")),
              TextField(controller: imapPortController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "IMAP Port (e.g. 993)"), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                value: imapEncryption,
                items: const [
                  DropdownMenuItem(value: "ssl", child: Text("SSL/TLS (Port 993)")),
                  DropdownMenuItem(value: "starttls", child: Text("STARTTLS")),
                ],
                onChanged: _isConfigEditing ? (v) => imapEncryption = v! : null,
                decoration: const InputDecoration(labelText: "IMAP Encryption"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildConfigCard(
          title: "IMAP Authentication",
          child: Column(
            children: [
              TextField(controller: imapUserController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "IMAP Username")),
              TextField(controller: imapPassController, enabled: _isConfigEditing, decoration: const InputDecoration(labelText: "IMAP Password"), obscureText: true),
            ],
          ),
        ),
        if (_isConfigEditing) ...[
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              final config = {
                "asset_name_prefix": prefixController.text.trim(),
                "smtp_host": hostController.text.trim(),
                "smtp_port": int.tryParse(portController.text.trim()),
                "smtp_user": userController.text.trim(),
                "smtp_pass": passController.text.trim(),
                "smtp_from_address": fromAddrController.text.trim(),
                "smtp_from_name": fromNameController.text.trim(),
                "smtp_encryption": encryption,
                "imap_host": imapHostController.text.trim(),
                "imap_port": int.tryParse(imapPortController.text.trim()),
                "imap_user": imapUserController.text.trim(),
                "imap_pass": imapPassController.text.trim(),
                "imap_encryption": imapEncryption,
                "app_url": appUrlController.text.trim(),
              };
              _saveTenantConfig(config);
              setState(() => _isConfigEditing = false);
            },
            style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text("Save Configuration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white));
  }

  Widget _buildConfigCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // --- SUPERADMIN TENANT ACTIONS ---

  Future<void> _addTenant() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final prefixCtrl = TextEditingController(text: "Box");
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Tenant"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Organization Name")),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Unique Code (e.g. GOA)")),
              TextField(controller: prefixCtrl, decoration: const InputDecoration(labelText: "Asset Serial Prefix")),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Initial Admin Email")),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Initial Admin Password")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await ApiService.createTenant(
          name: nameCtrl.text.trim(),
          code: codeCtrl.text.trim().toUpperCase(),
          assetNamePrefix: prefixCtrl.text.trim(),
          adminEmail: emailCtrl.text.trim(),
          adminPassword: passCtrl.text.trim(),
        );
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _deleteTenant(Tenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Tenant?"),
        content: Text("Are you sure you want to delete ${tenant.name}? All associated users and assets will be inaccessible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete Everything"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteTenant(tenant.id);
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showLogs(String type) async {
    final logs = await ApiService.fetchLogs(type);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${type.toUpperCase()} Server Logs"),
        content: Container(
          width: double.maxFinite,
          height: 500,
          color: Colors.black,
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: SelectableText(logs, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: "monospace")),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  Future<void> _showTableData(String tableName) async {
    final res = await ApiService.fetchTableData(tableName);
    if (!mounted) return;
    final cols = (res["columns"] as List).map((e) => e.toString()).toList();
    final data = (res["data"] as List).map((e) => e as Map<String, dynamic>).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Database Table: $tableName"),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: data.isEmpty 
            ? const Center(child: Text("No records found in this table."))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: cols.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    rows: data.map((row) => DataRow(
                      cells: cols.map((c) => DataCell(Text(row[c]?.toString() ?? "-"))).toList(),
                    )).toList(),
                  ),
                ),
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  Widget _buildPlatformTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Tenants", icon: Icon(Icons.business)),
              Tab(text: "Logs", icon: Icon(Icons.terminal)),
              Tab(text: "Database", icon: Icon(Icons.storage)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTenantsList(),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text("Diagnostic Logs", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: () => _showLogs("backend"), icon: const Icon(Icons.dns), label: const Text("View Backend Logs")),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(onPressed: () => _showLogs("frontend"), icon: const Icon(Icons.web), label: const Text("View Frontend Logs")),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text("Database Explorer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    FutureBuilder<List<String>>(
                      future: ApiService.fetchTables(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: snapshot.data!.map((t) => ActionChip(
                            label: Text(t),
                            onPressed: () => _showTableData(t),
                            backgroundColor: Colors.white.withOpacity(0.1),
                          )).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

          Future<void> _editTenantName(Tenant t) async {        final ctrl = TextEditingController(text: t.name);
        final newName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Rename ${t.name}"),
            content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "New Organization Name")),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text("Rename")),
            ],
          ),
        );
        if (newName != null && newName.isNotEmpty && newName != t.name) {
          try {
            await ApiService.updateTenant(t.id, newName);
            _loadAll();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      }
    
      Widget _buildTenantsList() {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Organizations", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ElevatedButton.icon(
                  onPressed: _addTenant,
                  icon: const Icon(Icons.add),
                  label: const Text("New Organization"),
                  style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._tenants.map((t) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          child: const Icon(Icons.business, color: Colors.white70),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white54),
                                    onPressed: () => _editTenantName(t),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              Text("CODE: ${t.code}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: t.id == 1 ? null : () => _deleteTenant(t),
                          icon: Icon(
                            Icons.delete_outline, 
                            color: t.id == 1 ? Colors.white24 : Colors.red
                          ),
                          tooltip: t.id == 1 ? "System Protected" : "Delete",
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        const Text("Primary Admin Credentials", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAdminCredentialRow(Icons.email_outlined, "Email", t.adminEmail ?? "N/A"),
                    const SizedBox(height: 8),
                    _buildAdminCredentialRow(Icons.person_outline, "Username", t.adminUsername ?? "N/A"),
                    const SizedBox(height: 8),
                    _buildAdminCredentialRow(Icons.lock_outline, "Password", t.adminPassword ?? "[NO PASS STORED]"),
                  ],
                ),
              ),
            )),
          ],
        );
      }

  Widget _buildAdminCredentialRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Expanded(child: SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }  Future<void> _createRole() async {
    final nameController = TextEditingController();
    final perms = Map<String, bool>.from({
      "is_admin": false, "manage_roles": false, "manage_users": false, 
      "manage_templates": false, "view_assets": true, "edit_assets": true, "scan_assets": true,
    });
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Create Role"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Role name")),
                const SizedBox(height: 8),
                for (final key in perms.keys)
                  CheckboxListTile(value: perms[key], onChanged: (v) => setLocal(() => perms[key] = v ?? false), title: Text(key), dense: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.createRole(name: nameController.text.trim(), permissions: perms);
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (created == true) _loadAll();
  }

  Future<void> _deleteRole(RoleType role) async {
    if (role.isSystem) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Role"),
        content: Text("Delete role '${role.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete")),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteRole(role.id);
        _loadAll();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _editRole(RoleType role) async {
    final nameController = TextEditingController(text: role.name);
    final perms = Map<String, bool>.from(role.permissions.map((k, v) => MapEntry(k, v == true)));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Edit Role"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Role name")),
                for (final key in perms.keys)
                  CheckboxListTile(value: perms[key], onChanged: (v) => setLocal(() => perms[key] = v ?? false), title: Text(key), dense: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateRole(roleId: role.id, name: nameController.text.trim(), permissions: perms);
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _loadAll();
  }

  Future<void> _createUser() async {
    if (_roles.isEmpty) return;
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    int roleTypeId = _roles.first.id;
    
    // For real-time check
    String? emailError;
    bool isCheckingEmail = false;
    Timer? debounceTimer;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          void checkEmail(String val) {
            if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
            if (val.isEmpty) {
              setLocal(() => emailError = null);
              return;
            }
            debounceTimer = Timer(const Duration(milliseconds: 500), () async {
              setLocal(() => isCheckingEmail = true);
              try {
                final res = await ApiService.checkUser(val);
                setLocal(() {
                  emailError = res["exists"] == true ? "Email/Username already taken" : null;
                  isCheckingEmail = false;
                });
              } catch (_) {
                setLocal(() => isCheckingEmail = false);
              }
            });
          }

          return AlertDialog(
            title: const Text("Create User"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: fullNameController, decoration: const InputDecoration(labelText: "Full name")),
                  TextField(
                    controller: usernameController, 
                    decoration: const InputDecoration(labelText: "Username"),
                    onChanged: checkEmail,
                  ),
                  TextField(
                    controller: emailController, 
                    decoration: InputDecoration(
                      labelText: "Email",
                      errorText: emailError,
                      suffixIcon: isCheckingEmail ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                    ),
                    onChanged: checkEmail,
                  ),
                  TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: roleTypeId,
                    items: _roles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                    onChanged: (v) => setLocal(() => roleTypeId = v!),
                    decoration: const InputDecoration(labelText: "Role"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: (emailError != null || isCheckingEmail) ? null : () async {
                  try {
                    await ApiService.createUser(
                      fullName: fullNameController.text.trim(), 
                      username: usernameController.text.trim(), 
                      email: emailController.text.trim(), 
                      password: passwordController.text.trim(), 
                      roleTypeId: roleTypeId
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
    if (created == true) _loadAll();
  }

  Future<void> _editUser(AdminUser user) async {
    final fullNameController = TextEditingController(text: user.fullName);
    final emailController = TextEditingController(text: user.email);
    int roleTypeId = user.roleTypeId;
    bool isActive = user.isActive;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Edit User"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fullNameController, decoration: const InputDecoration(labelText: "Full name")),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),
                DropdownButtonFormField<int>(
                  value: roleTypeId,
                  items: _roles.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                  onChanged: (v) => setLocal(() => roleTypeId = v!),
                  decoration: const InputDecoration(labelText: "Role"),
                ),
                SwitchListTile(title: const Text("Active"), value: isActive, onChanged: (v) => setLocal(() => isActive = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.updateUser(userId: user.id, fullName: fullNameController.text.trim(), email: emailController.text.trim(), roleTypeId: roleTypeId, isActive: isActive);
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _loadAll();
  }

  Future<void> _deleteUser(AdminUser user) async {
    if (user.id == widget.session.user.id) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User"),
        content: Text("Permanently delete user '${user.fullName}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Delete")),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteUser(user.id);
        _loadAll();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

    Future<void> _createDepartment() async {
      final nameController = TextEditingController();
      final codeController = TextEditingController();
      final newDept = await showDialog<Department?>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Create Department"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
              const SizedBox(height: 12),
              TextField(controller: codeController, decoration: const InputDecoration(labelText: "Unique Code (e.g. CVL)")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                try {
                  final d = await ApiService.createDepartment(name: nameController.text.trim(), code: codeController.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(context, d);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
  
      if (newDept != null) {
        // Reload everything but set the active selection to the new one
        await _loadAll();
        final fields = await ApiService.fetchDepartmentFields(newDept.id);
        setState(() {
          _selectedDepartment = newDept;
          _fields = fields;
        });
      }
    }
  Future<void> _deleteField(DepartmentFieldDefinition field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Field"),
        content: Text("Remove field '${field.label}' from template?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("Delete")),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteDepartmentField(_selectedDepartment!.id, field.id);
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addTemplateField() async {
    if (_selectedDepartment == null) return;
    final keyController = TextEditingController();
    final labelController = TextEditingController();
    String fieldType = "string";
    bool required = false;
    bool visibleWhenBlank = true;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Add Template Field"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: labelController, decoration: const InputDecoration(labelText: "Label (e.g. Serial Number)")),
                TextField(controller: keyController, decoration: const InputDecoration(labelText: "Key (e.g. serial_number)")),
                DropdownButtonFormField<String>(
                  value: fieldType,
                  items: const [
                    DropdownMenuItem(value: "string", child: Text("Text")),
                    DropdownMenuItem(value: "number", child: Text("Number")),
                    DropdownMenuItem(value: "date", child: Text("Date")),
                    DropdownMenuItem(value: "boolean", child: Text("Checkbox")),
                  ],
                  onChanged: (v) => setLocal(() => fieldType = v!),
                  decoration: const InputDecoration(labelText: "Field Type"),
                ),
                CheckboxListTile(
                  value: required, 
                  onChanged: (v) => setLocal(() => required = v ?? false), 
                  title: const Text("Required Field", style: TextStyle(color: Colors.white, fontSize: 14)),
                  dense: true,
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF1E293B),
                ),
                CheckboxListTile(
                  value: visibleWhenBlank, 
                  onChanged: (v) => setLocal(() => visibleWhenBlank = v ?? true), 
                  title: const Text("Visible when empty", style: TextStyle(color: Colors.white, fontSize: 14)),
                  dense: true,
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF1E293B),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), 
              style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (shouldSave == true) {
      final updated = List<DepartmentFieldDefinition>.from(_fields);
      updated.add(DepartmentFieldDefinition(
        id: -DateTime.now().microsecondsSinceEpoch,
        departmentId: _selectedDepartment!.id,
        fieldKey: keyController.text.trim(),
        label: labelController.text.trim(),
        fieldType: fieldType,
        required: required,
        visibleWhenBlank: visibleWhenBlank,
        editableByRoles: _roles.map((e) => e.name).toList(),
        displayOrder: updated.length + 1,
      ));
      await ApiService.updateDepartmentFields(departmentId: _selectedDepartment!.id, fields: updated);
      _loadAll();
    }
  }

  Future<void> _editTemplateField(DepartmentFieldDefinition field) async {
    final labelController = TextEditingController(text: field.label);
    String fieldType = field.fieldType;
    bool required = field.required;
    bool visibleWhenBlank = field.visibleWhenBlank;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text("Edit Field: ${field.fieldKey}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: labelController, decoration: const InputDecoration(labelText: "Label")),
                DropdownButtonFormField<String>(
                  value: fieldType,
                  items: const [
                    DropdownMenuItem(value: "string", child: Text("Text")),
                    DropdownMenuItem(value: "number", child: Text("Number")),
                    DropdownMenuItem(value: "date", child: Text("Date")),
                    DropdownMenuItem(value: "boolean", child: Text("Checkbox")),
                  ],
                  onChanged: (v) => setLocal(() => fieldType = v!),
                  decoration: const InputDecoration(labelText: "Field Type"),
                ),
                CheckboxListTile(
                  value: required, 
                  onChanged: (v) => setLocal(() => required = v ?? false), 
                  title: const Text("Required Field", style: TextStyle(color: Colors.white, fontSize: 14)),
                  dense: true,
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF1E293B),
                ),
                CheckboxListTile(
                  value: visibleWhenBlank, 
                  onChanged: (v) => setLocal(() => visibleWhenBlank = v ?? true), 
                  title: const Text("Visible when empty", style: TextStyle(color: Colors.white, fontSize: 14)),
                  dense: true,
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF1E293B),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), 
              style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (shouldSave == true) {
      final updated = _fields.map((f) {
        if (f.id == field.id) {
          return DepartmentFieldDefinition(
            id: f.id,
            departmentId: f.departmentId,
            fieldKey: f.fieldKey,
            label: labelController.text.trim(),
            fieldType: fieldType,
            required: required,
            visibleWhenBlank: visibleWhenBlank,
            editableByRoles: f.editableByRoles,
            displayOrder: f.displayOrder,
          );
        }
        return f;
      }).toList();
      await ApiService.updateDepartmentFields(departmentId: _selectedDepartment!.id, fields: updated);
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.white));
    final bool isSuper = widget.session.user.isSuperadmin;
    return DefaultTabController(
      length: isSuper ? 6 : 5,
      initialIndex: _tabController.index,
      child: Column(
        children: [
          Container(
            color: Colors.black.withOpacity(0.3),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                const Tab(text: "Users", icon: Icon(Icons.people_outline)), 
                const Tab(text: "Roles", icon: Icon(Icons.security_outlined)), 
                const Tab(text: "Email Setup", icon: Icon(Icons.email_outlined)),
                const Tab(text: "Templates", icon: Icon(Icons.assignment_outlined)), 
                const Tab(text: "Reports", icon: Icon(Icons.assessment_outlined)),
                if (isSuper) const Tab(text: "Platform", icon: Icon(Icons.business_outlined)),
              ],
              onTap: (val) => setState(() {}),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUsersList(),
                _buildRolesList(),
                _buildConfigTab(),
                _buildTemplatesList(),
                _buildReportsTab(),
                if (isSuper) _buildPlatformTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _reportStart;
  DateTime? _reportEnd;
  String _reportDuration = "all";
  bool _isDownloading = false;

  Widget _buildReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("System Reports", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Duration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _reportDuration,
                  dropdownColor: const Color(0xFF1E293B),
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("All Time", style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: "week", child: Text("Last 7 Days", style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: "month", child: Text("Last 30 Days", style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: "custom", child: Text("Custom Range...", style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) async {
                    if (v == "custom") {
                      final range = await showDateRangePicker(
                        context: context, 
                        firstDate: DateTime(2020), 
                        lastDate: DateTime.now(),
                        builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                      );
                      if (range != null) {
                        setState(() { _reportStart = range.start; _reportEnd = range.end; _reportDuration = "custom"; });
                      }
                    } else {
                      setState(() {
                        _reportDuration = v!;
                        _reportEnd = null;
                        if (v == "week") _reportStart = DateTime.now().subtract(const Duration(days: 7));
                        else if (v == "month") _reportStart = DateTime.now().subtract(const Duration(days: 30));
                        else _reportStart = null;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: "Report Timeframe"),
                ),
                if (_reportDuration == "custom" && _reportStart != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Range: ${DateFormat('yMMMd').format(_reportStart!.toLocal())} - ${DateFormat('yMMMd').format(_reportEnd!.toLocal())}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Export Asset Inventory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text("Download a full CSV list of all assets and their current locations.", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                if (_isDownloading)
                  const LinearProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: () => _downloadReport("assets"),
                    icon: const Icon(Icons.download),
                    label: const Text("Download Assets CSV"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Export Audit Logs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text("Download a full history of all system events and user actions.", style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                if (_isDownloading)
                  const LinearProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: () => _downloadReport("logs"),
                    icon: const Icon(Icons.history_edu),
                    label: const Text("Download Audit Logs CSV"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1), foregroundColor: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadReport(String type) async {
    setState(() => _isDownloading = true);
    try {
      String url = "${ApiService.baseUrl}/admin/reports/$type/?access_token=${widget.session.accessToken}";
      if (_reportStart != null) url += "&start_date=${_reportStart!.toIso8601String()}";
      if (_reportEnd != null) url += "&end_date=${(_reportEnd ?? DateTime.now()).toIso8601String()}";
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch $url";
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export failed: $e")));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Widget _buildRolesList() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ElevatedButton.icon(
          onPressed: _createRole, 
          icon: const Icon(Icons.add), 
          label: const Text("Create Role"),
          style: AppTheme.glassButtonStyle(),
        ),
        const SizedBox(height: 12),
        for (final role in _roles)
          Card(
            child: ListTile(
              title: Text(role.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => _editRole(role), icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
                  IconButton(
                    onPressed: role.isSystem ? null : () => _deleteRole(role), 
                    icon: Icon(
                      Icons.delete_outline, 
                      color: role.isSystem ? Colors.white24 : Colors.red
                    )
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersList() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ElevatedButton.icon(
          onPressed: _createUser, 
          icon: const Icon(Icons.person_add), 
          label: const Text("Create New User"),
          style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
        const SizedBox(height: 12),
        for (final user in _users)
          Card(
            child: ListTile(
              title: Text(user.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
              subtitle: Text("${user.email} • ${user.username}", style: const TextStyle(color: Colors.white70)), 
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => _editUser(user), icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
                  IconButton(
                    onPressed: (user.isPrimary || user.isSuperadmin) ? null : () => _deleteUser(user), 
                    icon: Icon(
                      Icons.delete_outline, 
                      color: (user.isPrimary || user.isSuperadmin) ? Colors.white24 : Colors.red
                    ),
                    tooltip: user.isPrimary ? "Primary Admin (Protected)" : (user.isSuperadmin ? "System Admin (Protected)" : "Delete User"),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

      Future<void> _deleteDepartment() async {
        if (_selectedDepartment == null) return;
        if (_selectedDepartment!.code == "GEN") {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("The General department is a system requirement and cannot be deleted.")));
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Department?"),
            content: Text("Delete '${_selectedDepartment!.name}' and all its associated field templates? This cannot be undone."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await ApiService.deleteDepartment(_selectedDepartment!.id);
            setState(() { _selectedDepartment = null; });
            await _loadAll();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      }
    
  Future<void> _editDepartmentName() async {
    if (_selectedDepartment == null) return;
    final ctrl = TextEditingController(text: _selectedDepartment!.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Rename ${_selectedDepartment!.name}"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "New Department Name")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text("Rename")),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != _selectedDepartment!.name) {
      try {
        final updated = await ApiService.updateDepartment(_selectedDepartment!.id, newName);
        setState(() { _selectedDepartment = updated; });
        await _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildTemplatesList() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ElevatedButton.icon(
          onPressed: _createDepartment,
          icon: const Icon(Icons.apartment),
          label: const Text("Create New Department", style: TextStyle(fontWeight: FontWeight.bold)),
          style: AppTheme.glassButtonStyle(padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
        const SizedBox(height: 20),
        if (_departments.isEmpty)
          const Center(child: Text("No departments found.", style: TextStyle(color: Colors.white54)))
        else ...[
          const Text("Manage Templates", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButton<int>(
                    value: _selectedDepartment?.id,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF1E293B),
                    items: _departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) async {
                      final dept = _departments.firstWhere((e) => e.id == v);
                      final f = await ApiService.fetchDepartmentFields(dept.id);
                      setState(() { _selectedDepartment = dept; _fields = f; });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _editDepartmentName,
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                tooltip: "Rename Department",
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedDepartment != null) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _addTemplateField,
                    icon: const Icon(Icons.add_box_outlined),
                    label: Text("Add Field to ${_selectedDepartment!.code}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: AppTheme.glassButtonStyle(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _deleteDepartment,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Delete Dept"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final field in _fields)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(field.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                  subtitle: Text("Key: ${field.fieldKey} | Type: ${field.fieldType}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: () => _editTemplateField(field), icon: const Icon(Icons.edit_outlined, color: Colors.white70)),
                      IconButton(onPressed: () => _deleteField(field), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
