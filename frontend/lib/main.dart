import "dart:async";
import "dart:convert";
import "dart:io" show Platform;

import "package:flutter/material.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:geolocator/geolocator.dart";
import "package:intl/intl.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

import "models/admin.dart";
import "models/asset.dart";
import "models/auth.dart";
import "services/api_service.dart";

void main() {
  runApp(const AMSApp());
}

class AppSession {
  final String accessToken;
  final UserProfile user;

  const AppSession({
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
        final payload = jsonDecode(userJson) as Map<String, dynamic>;
        final user = UserProfile.fromJson(payload);
        ApiService.setAccessToken(token);
        if (!mounted) return;
        setState(() {
          _session = AppSession(accessToken: token, user: user);
        });
      }
    } catch (_) {
      await ApiService.clearSession();
    } finally {
      if (mounted) {
        setState(() => _restoringSession = false);
      }
    }
  }

  void _onLoggedIn(LoginResponse login) {
    unawaited(ApiService.saveSession(login.accessToken, login.user));
    setState(() {
      _session = AppSession(accessToken: login.accessToken, user: login.user);
    });
  }

  void _onLogout() {
    unawaited(ApiService.clearSession());
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "GoAgile AMS",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D4ED8)),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      ),
      home: _restoringSession
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
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

class _AuthFlowState extends State<AuthFlow> {
  bool _showLogin = false;

  @override
  Widget build(BuildContext context) {
    if (!_showLogin) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2, size: 68, color: Color(0xFF1D4ED8)),
                const SizedBox(height: 20),
                const Text(
                  "Welcome to AMS By GoAgile",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Manage, scan, and track your assets securely.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => setState(() => _showLogin = true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(220, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("Login"),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return LoginScreen(
      onBack: () => setState(() => _showLogin = false),
      onLoggedIn: widget.onLoggedIn,
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<LoginResponse> onLoggedIn;

  const LoginScreen({
    super.key,
    required this.onBack,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: "admin@goagile.com");
  final _passwordController = TextEditingController(text: "goagile123");
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final login = await ApiService.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onLoggedIn(login);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    try {
      await ApiService.forgotPassword(_usernameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset instructions sent.")),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text("Sign in to manage your assets"),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text("Forgot password?"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Sign In"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final showScan = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
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
          page: AdminScreen(session: widget.session),
        ),
      );
    }

    final resolvedIndex = _index.clamp(0, tabs.length - 1);
    if (resolvedIndex != _index) {
      _index = resolvedIndex;
    }

    return Scaffold(
      body: IndexedStack(
        index: resolvedIndex,
        children: tabs.map((e) => e.page).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: resolvedIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
        ],
      ),
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
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF3730A3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back, ${session.user.fullName}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<AssetStats>(
                    future: ApiService.fetchStats(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text(
                          "Unable to load stats",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                        );
                      }
                      final stats = snapshot.data ??
                          const AssetStats(
                            totalAssets: 0,
                            activeAssets: 0,
                            archivedAssets: 0,
                            unassignedAssets: 0,
                          );
                      return Row(
                        children: [
                          Expanded(
                            child: _StatCard(title: "Total Assets", value: "${stats.totalAssets}"),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(title: "Active", value: "${stats.activeAssets}"),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (showScan) ...[
              ElevatedButton.icon(
                onPressed: onOpenScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text("Scan Asset QR Code"),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: onOpenAssets,
              icon: const Icon(Icons.search),
              label: const Padding(
                padding: EdgeInsets.all(10),
                child: Text("Search Assets"),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onOpenAssets,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Padding(
                padding: EdgeInsets.all(10),
                child: Text("View All Assets"),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
  String _status = "ALL";
  Timer? _debounce;
  List<Asset> _assets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);
    try {
      final assets = await ApiService.fetchAssets(
        query: _searchController.text,
        status: _status,
      );
      if (!mounted) return;
      setState(() => _assets = assets);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openAsset(Asset asset) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          session: widget.session,
          initialAsset: asset,
        ),
      ),
    );
    await _loadAssets();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF3730A3)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "All Assets",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), _loadAssets);
                  },
                  decoration: InputDecoration(
                    hintText: "Search by name, QR token, serial, assignee...",
                    fillColor: Colors.white,
                    filled: true,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ["ALL", "ACTIVE", "UNASSIGNED", "ARCHIVED"].map((status) {
              final selected = _status == status;
              return ChoiceChip(
                selected: selected,
                label: Text(status),
                onSelected: (_) {
                  setState(() => _status = status);
                  _loadAssets();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAssets,
                    child: _assets.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  "No assets found",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _assets.length,
                            itemBuilder: (context, index) {
                              final asset = _assets[index];
                              final title = asset.assetName?.trim().isNotEmpty == true
                                  ? asset.assetName!
                                  : asset.serialNumber;
                              return Card(
                                child: ListTile(
                                  title: Text(title),
                                  subtitle: Text(
                                    "${asset.status}  •  ${asset.serialNumber}\n"
                                    "${asset.assignedTo ?? "Unassigned"}",
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openAsset(asset),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
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

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final TextEditingController _manualController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isResolving = false;
  String? _lastToken;
  bool _scannerRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (!widget.isActive) {
      _stopScanner();
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _stopScanner();
      return;
    }
    _startScanner();
  }

  Future<void> _startScanner() async {
    if (_scannerRunning) return;
    _scannerRunning = true;
    try {
      await _scannerController.start();
    } catch (_) {
      _scannerRunning = false;
    }
  }

  Future<void> _stopScanner() async {
    if (!_scannerRunning) return;
    _scannerRunning = false;
    try {
      await _scannerController.stop();
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualController.dispose();
    _scannerController.dispose();
    super.dispose();
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
      final asset = await ApiService.fetchAssetByQr(trimmed);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssetDetailScreen(
            session: widget.session,
            initialAsset: asset,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _lastToken = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Scan Asset",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Position QR code within the frame",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final barcode =
                      capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                  final value = barcode?.rawValue;
                  if (value != null) {
                    _resolveToken(value);
                  }
                },
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
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _resolveToken(_manualController.text),
            child: const Text("Find Asset"),
          ),
          if (_isResolving) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class AssetDetailScreen extends StatefulWidget {
  final AppSession session;
  final Asset initialAsset;

  const AssetDetailScreen({
    super.key,
    required this.session,
    required this.initialAsset,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late Asset _asset;
  bool _loading = true;
  List<DepartmentFieldDefinition> _fields = [];
  List<AssetEvent> _events = [];
  final Map<String, TextEditingController> _attributeControllers = {};
  bool _savingAttributes = false;

  @override
  void initState() {
    super.initState();
    _asset = widget.initialAsset;
    _syncAttributeControllers(_asset.attributes);
    _refresh();
  }

  @override
  void dispose() {
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _displayValue(String key) {
    switch (key) {
      case "asset_name":
        return _asset.assetName ?? "";
      case "assigned_to":
        return _asset.assignedTo ?? "";
      case "location_text":
        return _asset.locationText ?? "";
      case "valid_till":
        return _asset.validTill != null
            ? DateFormat("yyyy-MM-dd").format(_asset.validTill!)
            : "";
      case "latitude":
        return _asset.latitude?.toString() ?? "";
      case "longitude":
        return _asset.longitude?.toString() ?? "";
      default:
        final value = _asset.attributes[key];
        return value?.toString() ?? "";
    }
  }

  void _syncAttributeControllers(Map<String, dynamic> attributes) {
    final keys = attributes.keys.map((e) => e.toString()).toSet();
    final existing = _attributeControllers.keys.toSet();
    final removedKeys = existing.difference(keys);
    for (final key in removedKeys) {
      _attributeControllers[key]?.dispose();
      _attributeControllers.remove(key);
    }
    for (final key in keys) {
      final controller = _attributeControllers.putIfAbsent(
        key,
        () => TextEditingController(),
      );
      final value = attributes[key];
      final text = value?.toString() ?? "";
      if (controller.text != text) {
        controller.text = text;
      }
    }
  }

  List<String> _missingFieldsFromDetail(String detail) {
    const prefix = "Missing required fields:";
    if (detail.startsWith(prefix)) {
      final suffix = detail.substring(prefix.length).trim();
      if (suffix.isEmpty) {
        return [detail];
      }
      return suffix
          .split(",")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [detail];
  }

  Future<void> _showMissingFieldsDialog(List<String> fields) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Missing required fields"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final field in fields) Text("- $field"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  bool _isFieldVisible(DepartmentFieldDefinition field) {
    final value = _displayValue(field.fieldKey);
    if (value.isNotEmpty) return true;
    if (widget.session.user.isAdmin) return true;
    return field.visibleWhenBlank;
  }

  bool _canEditField(DepartmentFieldDefinition field) {
    if (widget.session.user.isAdmin) return true;
    return field.editableByRoles.contains(widget.session.user.role);
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final asset = await ApiService.fetchAsset(_asset.id);
      final fields = await ApiService.fetchAssetFields(_asset.id);
      final events = await ApiService.fetchAssetEvents(_asset.id);
      if (!mounted) return;
      _syncAttributeControllers(asset.attributes);
      setState(() {
        _asset = asset;
        _fields = fields;
        _events = events;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _activate() async {
    try {
      await ApiService.activateAsset(_asset.id);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 409) {
        final fields = _missingFieldsFromDetail(error.message);
        await _showMissingFieldsDialog(fields);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _archive() async {
    try {
      await ApiService.archiveAsset(_asset.id);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _saveAttributes() async {
    if (!widget.session.user.hasPermission("edit_assets")) return;
    setState(() => _savingAttributes = true);
    try {
      final attrs = <String, dynamic>{};
      _attributeControllers.forEach((key, controller) {
        attrs[key] = controller.text.trim();
      });
      await ApiService.updateAsset(
        assetId: _asset.id,
        attributes: attrs,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _savingAttributes = false);
      }
    }
  }

  Widget _buildAttributesCard() {
    final entries = _asset.attributes.entries
        .map((entry) => MapEntry(entry.key.toString(), entry.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final canEdit = widget.session.user.hasPermission("edit_assets");
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Custom Attributes",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text("No custom attributes set."),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Custom Attributes",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: canEdit
                          ? TextField(
                              controller: _attributeControllers[entry.key],
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            )
                          : Text(
                              entry.value?.toString().trim().isEmpty == true
                                  ? "-"
                                  : entry.value.toString(),
                            ),
                    ),
                  ],
                ),
              ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _savingAttributes ? null : _saveAttributes,
                  child: Text(_savingAttributes ? "Saving..." : "Save Attributes"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openMap() async {
    final url = _asset.mapsUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<Position> _fetchCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception("Location permission denied.");
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied.");
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _editAsset() async {
    final nameController = TextEditingController(text: _asset.assetName ?? "");
    final assignedController = TextEditingController(text: _asset.assignedTo ?? "");
    final locationController = TextEditingController(text: _asset.locationText ?? "");
    double? latitude = _asset.latitude;
    double? longitude = _asset.longitude;
    bool isUpdatingGps = false;
    final dynamicControllers = <String, TextEditingController>{};
    for (final field in _fields) {
      if (_canEditField(field)) {
        dynamicControllers[field.fieldKey] = TextEditingController(
          text: _displayValue(field.fieldKey),
        );
      }
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Edit Asset",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Asset name"),
                  ),
                  TextField(
                    controller: assignedController,
                    decoration: const InputDecoration(labelText: "Assigned to"),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: "Location"),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Lat: ${latitude?.toStringAsFixed(6) ?? "-"}",
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Lng: ${longitude?.toStringAsFixed(6) ?? "-"}",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isUpdatingGps
                        ? null
                        : () async {
                            setLocal(() => isUpdatingGps = true);
                            try {
                              final position = await _fetchCurrentPosition();
                              setLocal(() {
                                latitude = position.latitude;
                                longitude = position.longitude;
                              });
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            } finally {
                              if (context.mounted) {
                                setLocal(() => isUpdatingGps = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.my_location_outlined),
                    label: Text(
                      isUpdatingGps
                          ? "Fetching coordinates..."
                          : "Update Coordinates from GPS",
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final field in _fields)
                    if (_canEditField(field) &&
                        !{
                          "asset_name",
                          "assigned_to",
                          "location_text",
                          "latitude",
                          "longitude",
                        }.contains(field.fieldKey))
                      TextField(
                        controller: dynamicControllers[field.fieldKey],
                        decoration: InputDecoration(labelText: field.label),
                      ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final attrs = <String, dynamic>{};
                        dynamicControllers.forEach((key, controller) {
                          if (!{
                            "asset_name",
                            "assigned_to",
                            "location_text",
                            "latitude",
                            "longitude",
                          }.contains(key)) {
                            attrs[key] = controller.text.trim();
                          }
                        });
                        await ApiService.updateAsset(
                          assetId: _asset.id,
                          assetName: nameController.text.trim(),
                          assignedTo: assignedController.text.trim(),
                          locationText: locationController.text.trim(),
                          latitude: latitude,
                          longitude: longitude,
                          attributes: attrs,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context, true);
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    assignedController.dispose();
    locationController.dispose();
    for (final controller in dynamicControllers.values) {
      controller.dispose();
    }

    if (saved == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _asset.assetName?.trim().isNotEmpty == true
        ? _asset.assetName!
        : _asset.serialNumber;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(label: Text(_asset.status)),
                            Text(
                              _asset.serialNumber,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText("QR Token: ${_asset.assetToken}"),
                        if (_asset.mapsUrl != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _openMap,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text("Open in Google Maps"),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (widget.session.user.hasPermission("edit_assets"))
                              OutlinedButton.icon(
                                onPressed: _editAsset,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text("Edit"),
                              ),
                            if (_asset.status == "UNASSIGNED" &&
                                widget.session.user.hasPermission("edit_assets"))
                              ElevatedButton.icon(
                                onPressed: _activate,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text("Activate"),
                              ),
                            if (_asset.status != "ARCHIVED" &&
                                widget.session.user.hasPermission("edit_assets"))
                              OutlinedButton.icon(
                                onPressed: _archive,
                                icon: const Icon(Icons.archive_outlined),
                                label: const Text("Archive"),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildAttributesCard(),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Asset Information",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        if (_fields.isEmpty) ...[
                          const Text("No field template assigned to this asset."),
                        ] else ...[
                          for (final field in _fields)
                            if (_isFieldVisible(field))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        field.label,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(_displayValue(field.fieldKey).isEmpty
                                          ? "-"
                                          : _displayValue(field.fieldKey)),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "History",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (final event in _events)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(event.eventType),
                            subtitle: Text(
                              "${event.userRole} • ${DateFormat("yyyy-MM-dd HH:mm").format(event.createdAt)}",
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final AppSession session;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Profile",
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.user.fullName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(session.user.email),
                  const SizedBox(height: 6),
                  Chip(label: Text(session.user.role)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}

class AdminScreen extends StatefulWidget {
  final AppSession session;

  const AdminScreen({
    super.key,
    required this.session,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<RoleType> _roles = [];
  List<AdminUser> _users = [];
  List<Department> _departments = [];
  List<DepartmentFieldDefinition> _fields = [];
  Department? _selectedDepartment;
  QRBatch? _latestBatch;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final roles = await ApiService.fetchRoles();
      final users = await ApiService.fetchUsers();
      final departments = await ApiService.fetchDepartments();
      List<DepartmentFieldDefinition> fields = [];
      Department? selectedDepartment;
      if (departments.isNotEmpty) {
        selectedDepartment = departments.first;
        fields = await ApiService.fetchDepartmentFields(selectedDepartment.id);
      }
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _users = users;
        _departments = departments;
        _selectedDepartment = selectedDepartment;
        _fields = fields;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createRole() async {
    final nameController = TextEditingController();
    final perms = <String, bool>{
      "is_admin": false,
      "manage_roles": false,
      "manage_users": false,
      "manage_templates": false,
      "generate_qr": false,
      "view_assets": true,
      "edit_assets": true,
      "scan_assets": true,
    };
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Create Role"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Role name"),
                ),
                const SizedBox(height: 8),
                for (final entry in perms.entries)
                  CheckboxListTile(
                    value: entry.value,
                    onChanged: (value) {
                      setLocal(() => perms[entry.key] = value ?? false);
                    },
                    title: Text(entry.key),
                    dense: true,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.createRole(
                    name: nameController.text.trim(),
                    permissions: perms,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (created == true) {
      _loadAll();
    }
  }

  Future<void> _deleteRole(RoleType role) async {
    if (role.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("System roles cannot be deleted.")),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete role"),
        content: Text("Delete role '${role.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteRole(role.id);
        if (!mounted) return;
        _loadAll();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _createUser() async {
    if (_roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Create a role first.")),
      );
      return;
    }
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    int roleTypeId = _roles.first.id;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Create User"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: "Full name"),
                ),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: "Username"),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: "Password"),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: roleTypeId,
                  items: _roles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role.id,
                          child: Text(role.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setLocal(() => roleTypeId = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: "Role"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.createUser(
                    fullName: fullNameController.text.trim(),
                    username: usernameController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                    roleTypeId: roleTypeId,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              },
              child: const Text("Create"),
            ),
          ],
        ),
      ),
    );

    fullNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    if (created == true) {
      _loadAll();
    }
  }

  Future<void> _deleteUser(AdminUser user) async {
    if (user.id == widget.session.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot delete your own account.")),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete user"),
        content: Text("Delete user '${user.fullName}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteUser(user.id);
        if (!mounted) return;
        _loadAll();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  Future<void> _createDepartment() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Department"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Department name"),
            ),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: "Department code"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ApiService.createDepartment(
                  name: nameController.text.trim(),
                  code: codeController.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(context, true);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
    nameController.dispose();
    codeController.dispose();
    if (created == true) {
      _loadAll();
    }
  }

  Future<void> _addTemplateField() async {
    if (_selectedDepartment == null) return;
    final keyController = TextEditingController();
    final labelController = TextEditingController();
    bool required = false;
    bool visibleWhenBlank = false;
    String fieldType = "text";

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Add Field"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: "field_key"),
                ),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: "Label"),
                ),
                DropdownButtonFormField<String>(
                  initialValue: fieldType,
                  items: const [
                    DropdownMenuItem(value: "text", child: Text("Text")),
                    DropdownMenuItem(value: "number", child: Text("Number")),
                    DropdownMenuItem(value: "date", child: Text("Date")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setLocal(() => fieldType = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: "Field Type"),
                ),
                CheckboxListTile(
                  value: required,
                  onChanged: (value) => setLocal(() => required = value ?? false),
                  title: const Text("Required"),
                ),
                CheckboxListTile(
                  value: visibleWhenBlank,
                  onChanged: (value) =>
                      setLocal(() => visibleWhenBlank = value ?? false),
                  title: const Text("Visible when blank"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
    if (shouldSave == true) {
      final updated = List<DepartmentFieldDefinition>.from(_fields);
      updated.add(
        DepartmentFieldDefinition(
          id: -DateTime.now().microsecondsSinceEpoch,
          departmentId: _selectedDepartment!.id,
          fieldKey: keyController.text.trim(),
          label: labelController.text.trim(),
          fieldType: fieldType,
          required: required,
          visibleWhenBlank: visibleWhenBlank,
          editableByRoles: _roles.map((e) => e.name).toList(),
          displayOrder: updated.length + 1,
        ),
      );
      await ApiService.updateDepartmentFields(
        departmentId: _selectedDepartment!.id,
        fields: updated,
      );
      _fields = await ApiService.fetchDepartmentFields(_selectedDepartment!.id);
      if (mounted) {
        setState(() {});
      }
    }
    keyController.dispose();
    labelController.dispose();
  }

  Future<void> _generateBatch() async {
    if (_departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Create a department first.")),
      );
      return;
    }

    final quantityController = TextEditingController(text: "10");
    int departmentId = _departments.first.id;
    bool includePdf = true;
    bool includeZip = true;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text("Generate QR Batch"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Quantity"),
              ),
              DropdownButtonFormField<int>(
                initialValue: departmentId,
                items: _departments
                    .map(
                      (dept) => DropdownMenuItem(
                        value: dept.id,
                        child: Text("${dept.name} (${dept.code})"),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocal(() => departmentId = value);
                  }
                },
                decoration: const InputDecoration(labelText: "Department"),
              ),
              CheckboxListTile(
                value: includePdf,
                onChanged: (value) => setLocal(() => includePdf = value ?? false),
                title: const Text("PDF"),
              ),
              CheckboxListTile(
                value: includeZip,
                onChanged: (value) => setLocal(() => includeZip = value ?? false),
                title: const Text("ZIP"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final formats = <String>[
                    if (includePdf) "pdf",
                    if (includeZip) "zip",
                  ];
                  final batch = await ApiService.createQrBatch(
                    quantity: int.tryParse(quantityController.text) ?? 0,
                    departmentId: departmentId,
                    exportFormats: formats,
                  );
                  _latestBatch = batch;
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString())),
                  );
                }
              },
              child: const Text("Generate"),
            ),
          ],
        ),
      ),
    );
    quantityController.dispose();
    if (created == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openBatchDownload(String format) async {
    if (_latestBatch == null) return;
    final url = ApiService.qrBatchDownloadUrl(
      batchId: _latestBatch!.id,
      format: format,
    );
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: "Roles"),
                      Tab(text: "Users"),
                      Tab(text: "Templates"),
                      Tab(text: "QR"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            ElevatedButton.icon(
                              onPressed: _createRole,
                              icon: const Icon(Icons.add),
                              label: const Text("Create Role"),
                            ),
                            const SizedBox(height: 12),
                            for (final role in _roles)
                              Card(
                                child: ListTile(
                                  title: Text(role.name),
                                  subtitle: Text(
                                    role.permissions.entries
                                        .where((entry) => entry.value == true)
                                        .map((entry) => entry.key)
                                        .join(", "),
                                  ),
                                  trailing: IconButton(
                                    onPressed: role.isSystem ? null : () => _deleteRole(role),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            ElevatedButton.icon(
                              onPressed: _createUser,
                              icon: const Icon(Icons.person_add),
                              label: const Text("Create User"),
                            ),
                            const SizedBox(height: 12),
                            for (final user in _users)
                              Card(
                                child: ListTile(
                                  title: Text(user.fullName),
                                  subtitle: Text("${user.username} • ${user.email}"),
                                  trailing: IconButton(
                                    onPressed: user.id == widget.session.user.id
                                        ? null
                                        : () => _deleteUser(user),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _createDepartment,
                                  icon: const Icon(Icons.apartment),
                                  label: const Text("Create Department"),
                                ),
                                if (_selectedDepartment != null)
                                  ElevatedButton.icon(
                                    onPressed: _addTemplateField,
                                    icon: const Icon(Icons.add_box_outlined),
                                    label: const Text("Add Field"),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_departments.isNotEmpty)
                              DropdownButtonFormField<int>(
                                initialValue: _selectedDepartment?.id,
                                items: _departments
                                    .map(
                                      (dept) => DropdownMenuItem(
                                        value: dept.id,
                                        child: Text("${dept.name} (${dept.code})"),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  final selected = _departments.firstWhere((e) => e.id == value);
                                  final fields = await ApiService.fetchDepartmentFields(value);
                                  if (!mounted) return;
                                  setState(() {
                                    _selectedDepartment = selected;
                                    _fields = fields;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: "Department",
                                ),
                              ),
                            const SizedBox(height: 12),
                            for (final field in _fields)
                              Card(
                                child: ListTile(
                                  title: Text(field.label),
                                  subtitle: Text(
                                    "${field.fieldKey} • required=${field.required}",
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            ElevatedButton.icon(
                              onPressed: _generateBatch,
                              icon: const Icon(Icons.qr_code_2),
                              label: const Text("Generate QR Batch"),
                            ),
                            if (_latestBatch != null) ...[
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Batch #${_latestBatch!.id}",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text("Quantity: ${_latestBatch!.quantity}"),
                                      Text(
                                        "Created: ${DateFormat("yyyy-MM-dd HH:mm").format(_latestBatch!.createdAt)}",
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (_latestBatch!.exportFormats.contains("pdf"))
                                            OutlinedButton(
                                              onPressed: () => _openBatchDownload("pdf"),
                                              child: const Text("Download PDF"),
                                            ),
                                          if (_latestBatch!.exportFormats.contains("zip"))
                                            OutlinedButton(
                                              onPressed: () => _openBatchDownload("zip"),
                                              child: const Text("Download ZIP"),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
