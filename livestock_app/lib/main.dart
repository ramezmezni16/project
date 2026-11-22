

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'alerts_screen.dart';
import 'chat_contacts_screen.dart';



import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;

import 'package:flutter/material.dart';



import 'services/auth_service.dart';

import 'services/api_service.dart';

import 'services/shepherd_location_service.dart';

import 'map_screen.dart';

import 'shepherd_management_screen.dart';
import 'invitation_scan_screen.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  }

  // Display the app first.
  runApp(const LivestockApp());

  // Initialize notifications only on Android, without blocking the UI.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    notificationService.initialize().catchError((error) {
      debugPrint('Notification initialization failed: $error');
    });
  }
}



const String apiUrl = kIsWeb
    ? 'http://localhost:8000'
    : String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000',
      );



final AuthService authService = AuthService(baseUrl: apiUrl);



final ApiService apiService = ApiService(

  baseUrl: apiUrl,

  auth: authService,

);

final NotificationService notificationService = NotificationService();



const Color navy = Color(0xFF17243A);

const Color blue = Color(0xFF3867D6);

const Color background = Color(0xFFF5F7FB);

const Color muted = Color(0xFF8290A5);

const Color border = Color(0xFFE8EDF4);

const Color green = Color(0xFF16865B);

const Color red = Color(0xFFD94C4C);



class LivestockApp extends StatelessWidget {

  const LivestockApp({super.key});



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'Livestock Monitor',

      theme: ThemeData(

        useMaterial3: true,

        scaffoldBackgroundColor: background,

        fontFamily: 'Arial',

        colorScheme: ColorScheme.fromSeed(

          seedColor: blue,

          brightness: Brightness.light,

        ),

      ),

      home: const AuthGate(),

    );

  }

}



// ============================================================

// AUTHENTICATION GATE

// ============================================================



class AuthGate extends StatefulWidget {

  const AuthGate({super.key});



  @override

  State<AuthGate> createState() => _AuthGateState();

}



class _AuthGateState extends State<AuthGate> {

  Map<String, dynamic>? user;
  StreamSubscription<String>? _installationSubscription;

  bool checking = true;
  Future<void> _registerCurrentDevice() async {
    final token = notificationService.fcmToken;
    if (token == null) return;

    await _registerDevice(token);
  }

  Future<void> _registerDevice(String token) async {
    try {
      await apiService.post(
        '/api/auth/devices/register/',
        {
          'fcm_token': token,
          'platform': 'android',
        },
      );

      debugPrint('FCM device registered with backend.');
    } catch (error) {
      debugPrint('FCM device registration failed: $error');
    }
  }



  @override
  void initState() {
    super.initState();

    // Catch the Firebase ID whenever it becomes available.
    _installationSubscription =
        notificationService.onTokenRefresh.listen((token) {
      if (user != null) {
        _registerDevice(token);
      }
    });

    _restoreSession();
  }
  @override
  void dispose() {
    _installationSubscription?.cancel();
    super.dispose();
  }



  Future<void> _restoreSession() async {

    try {

      if (await authService.isLoggedIn()) {

        user = await authService.getCurrentUser();
        unawaited(_registerCurrentDevice());

      }

    } catch (_) {

      await authService.logout();

    }



    if (mounted) {

      setState(() => checking = false);

    }

  }



  void _onLogin(Map<String, dynamic> loggedInUser) {
    setState(() => user = loggedInUser);

    unawaited(_registerCurrentDevice());
  }



  Future<void> _logout() async {

    await authService.logout();



    if (mounted) {

      setState(() => user = null);

    }

  }



  @override

  Widget build(BuildContext context) {

    if (checking) {

      return const Scaffold(

        body: Center(

          child: CircularProgressIndicator(),

        ),

      );

    }



    if (user == null) {

      return LoginScreen(onLogin: _onLogin);

    }



    return DashboardPage(

      user: user!,

      onLogout: _logout,

    );

  }

}



// ============================================================

// LOGIN SCREEN

// ============================================================



class LoginScreen extends StatefulWidget {

  final ValueChanged<Map<String, dynamic>> onLogin;



  const LoginScreen({

    super.key,

    required this.onLogin,

  });



  @override

  State<LoginScreen> createState() => _LoginScreenState();

}



class _LoginScreenState extends State<LoginScreen> {

  final usernameController = TextEditingController();

  final passwordController = TextEditingController();



  bool loading = false;

  bool obscurePassword = true;

  String? error;



  @override

  void dispose() {

    usernameController.dispose();

    passwordController.dispose();

    super.dispose();

  }



  Future<void> _login() async {

    if (usernameController.text.trim().isEmpty ||

        passwordController.text.isEmpty) {

      setState(() {

        error = 'Enter your username and password.';

      });

      return;

    }



    setState(() {

      loading = true;

      error = null;

    });



    try {

      final loggedInUser = await authService.login(

        usernameController.text.trim(),

        passwordController.text,

      );



      if (mounted) {

        widget.onLogin(loggedInUser);

      }

    } catch (e) {

      if (mounted) {

        setState(() {

          error = e.toString().replaceFirst('Exception: ', '');

        });

      }

    } finally {

      if (mounted) {

        setState(() => loading = false);

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      body: Center(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(24),

          child: ConstrainedBox(

            constraints: const BoxConstraints(maxWidth: 420),

            child: Card(

              elevation: 0,

              color: Colors.white,

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(16),

                side: const BorderSide(color: border),

              ),

              child: Padding(

                padding: const EdgeInsets.all(30),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    const Icon(

                      Icons.pets,

                      size: 48,

                      color: blue,

                    ),

                    const SizedBox(height: 18),

                    const Text(

                      'LIVESTOCK MONITOR',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: navy,

                        fontSize: 21,

                        fontWeight: FontWeight.w800,

                      ),

                    ),

                    const SizedBox(height: 8),

                    const Text(

                      'Sign in to your farm account',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: muted,

                        fontSize: 13,

                      ),

                    ),

                    const SizedBox(height: 30),

                    TextField(

                      controller: usernameController,

                      decoration: const InputDecoration(

                        labelText: 'Username',

                        prefixIcon: Icon(Icons.person_outline),

                        border: OutlineInputBorder(),

                      ),

                      onSubmitted: (_) => _login(),

                    ),

                    const SizedBox(height: 16),

                    TextField(

                      controller: passwordController,

                      obscureText: obscurePassword,

                      decoration: InputDecoration(

                        labelText: 'Password',

                        prefixIcon: const Icon(Icons.lock_outline),

                        border: const OutlineInputBorder(),

                        suffixIcon: IconButton(

                          onPressed: () {

                            setState(() {

                              obscurePassword = !obscurePassword;

                            });

                          },

                          icon: Icon(

                            obscurePassword

                                ? Icons.visibility_outlined

                                : Icons.visibility_off_outlined,

                          ),

                        ),

                      ),

                      onSubmitted: (_) => _login(),

                    ),

                    if (error != null) ...[

                      const SizedBox(height: 16),

                      Text(

                        error!,

                        style: const TextStyle(

                          color: red,

                          fontSize: 12,

                        ),

                      ),

                    ],

                    const SizedBox(height: 24),

                    SizedBox(

                      height: 48,

                      child: ElevatedButton(

                        onPressed: loading ? null : _login,

                        style: ElevatedButton.styleFrom(

                          backgroundColor: blue,

                          foregroundColor: Colors.white,

                        ),

                        child: loading

                            ? const SizedBox(

                                height: 20,

                                width: 20,

                                child: CircularProgressIndicator(

                                  strokeWidth: 2,

                                  color: Colors.white,

                                ),

                              )

                            : const Text('SIGN IN'),

                      ),

                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InvitationScanScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('JOIN A FARM'),
                    ),

                  ],

                ),

              ),

            ),

          ),

        ),

      ),

    );

  }

}



// ============================================================

// DASHBOARD

// ============================================================



class DashboardPage extends StatefulWidget {

  final Map<String, dynamic> user;

  final Future<void> Function() onLogout;



  const DashboardPage({

    super.key,

    required this.user,

    required this.onLogout,

  });



  @override

  State<DashboardPage> createState() => _DashboardPageState();

}



class _DashboardPageState extends State<DashboardPage> {

  List<dynamic> trackers = [];

  List<dynamic> zones = [];

  List<dynamic> shepherds = [];



  bool zonesRefreshing = false;

  bool shepherdsRefreshing = false;



  bool loading = true;

  bool refreshing = false;

  bool connected = false;



  bool sharingLocation = false;

  bool locationBusy = false;



  int page = 0;



  String? error;

  String? locationError;



  DateTime? lastUpdated;

  Timer? refreshTimer;



  late final ShepherdLocationService locationService =

      ShepherdLocationService(apiService: apiService);



  bool get isShepherd => widget.user['role'] == 'SHEPHERD';



  bool get isOwner => widget.user['role'] == 'OWNER';



  @override

  void initState() {

    super.initState();



    fetchTrackers(showLoading: true);

    fetchZones();



    if (isOwner) {

      fetchShepherds();

    }



    refreshTimer = Timer.periodic(

      const Duration(seconds: 5),

      (_) {

        fetchTrackers();

        fetchZones();



        if (isOwner) {

          fetchShepherds();

        }

      },

    );

  }



  @override

  void dispose() {

    refreshTimer?.cancel();

    locationService.stop();

    super.dispose();

  }



  Future<void> fetchTrackers({bool showLoading = false}) async {

    if (refreshing) return;



    refreshing = true;



    if (showLoading && mounted) {

      setState(() {

        loading = true;

        error = null;

      });

    }



    try {

      final data = await apiService.get(

        '/api/analytics/anomalies/',

      ) as Map<String, dynamic>;



      if (!mounted) return;



      setState(() {

        trackers = data['results'] ?? [];

        connected = true;

        loading = false;

        error = null;

        lastUpdated = DateTime.now();

      });

    } catch (e) {

      if (!mounted) return;



      setState(() {

        connected = false;

        loading = false;

        error = e.toString();

      });

    } finally {

      refreshing = false;

    }

  }



  Future<void> fetchZones() async {

    if (zonesRefreshing) return;



    zonesRefreshing = true;



    try {

      final data = await apiService.get(

        '/api/analytics/clusters/',

      ) as Map<String, dynamic>;



      if (!mounted) return;



      setState(() {

        zones = data['habitual_zones'] ?? [];

      });

    } catch (e) {

      debugPrint('Could not load grazing zones: $e');

    } finally {

      zonesRefreshing = false;

    }

  }



  // ==========================================================

  // OWNER: FETCH LATEST SHEPHERD POSITIONS

  // ==========================================================



  Future<void> fetchShepherds() async {

    if (shepherdsRefreshing || !isOwner) return;



    shepherdsRefreshing = true;



    try {

      final data = await apiService.get(

        '/api/shepherds/locations/',

      );



      if (!mounted) return;



      if (data is List) {

        setState(() {

          shepherds = data;

        });

      }

    } catch (e) {

      debugPrint('Could not load shepherd locations: $e');

    } finally {

      shepherdsRefreshing = false;

    }

  }



  // ==========================================================

  // SHEPHERD: START / STOP LOCATION SHARING

  // ==========================================================



  Future<void> toggleLocationSharing(bool enabled) async {

    if (!isShepherd || locationBusy) return;



    if (enabled) {

      setState(() {

        locationBusy = true;

        locationError = null;

      });



      try {

        await locationService.start(

          onError: (message) {

            if (!mounted) return;



            setState(() {

              locationError = message;

            });



            debugPrint(message);

          },

        );



        if (!mounted) {

          await locationService.stop();

          return;

        }



        setState(() {

          sharingLocation = true;

        });

      } catch (e) {

        if (mounted) {

          setState(() {

            locationError =

                e.toString().replaceFirst('Exception: ', '');

          });



          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(content: Text(locationError!)),

          );

        }

      } finally {

        if (mounted) {

          setState(() {

            locationBusy = false;

          });

        }

      }

    } else {

      await locationService.stop();



      if (mounted) {

        setState(() {

          sharingLocation = false;

          locationError = null;

        });

      }

    }

  }



  @override

  Widget build(BuildContext context) {

    final anomalies = trackers.where(

      (t) => t['is_anomaly'] == true,

    ).length;



    final normal = trackers.length - anomalies;



    return LayoutBuilder(

      builder: (context, constraints) {

        final wide = constraints.maxWidth >= 900;



        return Scaffold(

          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page,
                  onDestinationSelected: (i) {
                    setState(() => page = i);
                  },
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: 'Overview',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      label: 'Map',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.notifications_outlined),
                      label: 'Alerts',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      label: 'Chats',
                    ),
                    if (isOwner)
                      const NavigationDestination(
                        icon: Icon(Icons.people_outline),
                        label: 'Shepherds',
                      ),
                  ],
                ),
          body: Row(

            children: [

              if (wide)

                Sidebar(

                  selected: page,

                  isOwner: isOwner,

                  onSelect: (i) => setState(() => page = i),

                ),

              Expanded(

                child: Column(

                  children: [

                    buildTopBar(),

                    Expanded(

                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : page == 1
                              ? MapScreen(
                                  trackers: trackers,
                                  zones: zones,
                                  shepherds: shepherds,
                                )
                              : page == 2
                                  ? AlertsScreen(apiService: apiService)
                                  : page == 3
                                      ? ChatContactsScreen(apiService: apiService)
                                      : page == 4 && isOwner
                                          ? ShepherdManagementScreen(
                                              apiService: apiService,
                                            )
                                          : buildOverview(
                                              wide,
                                              anomalies,
                                              normal,
                                            ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        );

      },

    );

  }



  Widget buildOverview(bool wide, int anomalies, int normal) {

    return SingleChildScrollView(

      padding: EdgeInsets.all(wide ? 32 : 18),

      child: Center(

        child: ConstrainedBox(

          constraints: const BoxConstraints(maxWidth: 1400),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              buildHeading(),

              const SizedBox(height: 28),

              buildMetrics(anomalies, normal),

              const SizedBox(height: 30),

              buildSectionHeader(),

              const SizedBox(height: 14),

              if (error != null && trackers.isEmpty)

                buildError()

              else

                buildTrackerSection(wide),

              const SizedBox(height: 24),

              buildModelInfo(),

              const SizedBox(height: 24),

              buildFooter(),

            ],

          ),

        ),

      ),

    );

  }



  
  
  Widget buildTopBar() {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              page == 0
                  ? (compact ? 'OVERVIEW' : 'LIVESTOCK / OVERVIEW')
                  : page == 1
                      ? (compact ? 'MAP' : 'LIVESTOCK / MAP')
                      : page == 2
                          ? (compact ? 'ALERTS' : 'LIVESTOCK / ALERTS')
                          : page == 3
                              ? (compact ? 'CHATS' : 'LIVESTOCK / CHATS')
                              : (compact ? 'SHEPHERDS' : 'LIVESTOCK / SHEPHERDS'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(width: 8),

          if (isShepherd) ...[
            if (!compact)
              Text(
                sharingLocation ? 'LOCATION ON' : 'LOCATION OFF',
                style: TextStyle(
                  color: sharingLocation ? green : muted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),

            Switch.adaptive(
              value: sharingLocation,
              onChanged: locationBusy ? null : toggleLocationSharing,
              activeThumbColor: green,
            ),

            if (locationBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
          ],

          if (compact)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: connected ? green : red,
                shape: BoxShape.circle,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0xFFEAF7F0)
                    : const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: connected ? green : red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connected ? 'API CONNECTED' : 'API DISCONNECTED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: connected ? green : red,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(width: compact ? 2 : 14),

          IconButton(
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            padding: EdgeInsets.zero,
            onPressed: () {
              fetchTrackers(showLoading: true);
              fetchZones();

              if (isOwner) {
                fetchShepherds();
              }
            },
            tooltip: 'Refresh data',
            icon: const Icon(
              Icons.refresh_rounded,
              color: navy,
            ),
          ),

          IconButton(
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            padding: EdgeInsets.zero,
            onPressed: () async {
              await locationService.stop();
              await widget.onLogout();
            },
            tooltip: 'Logout',
            icon: const Icon(
              Icons.logout_rounded,
              color: navy,
            ),
          ),
        ],
      ),
    );
  }





  Widget buildHeading() {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(

          'Farm Overview',

          style: TextStyle(

            fontSize: 28,

            fontWeight: FontWeight.w800,

            color: navy,

            letterSpacing: -0.8,

          ),

        ),

        const SizedBox(height: 7),

        const Text(

          'Monitor your livestock, telemetry and AI-detected anomalies.',

          style: TextStyle(

            fontSize: 13,

            color: muted,

          ),

        ),

        const SizedBox(height: 12),

        Row(

          children: [

            const Icon(

              Icons.sync,

              size: 14,

              color: blue,

            ),

            const SizedBox(width: 6),

            Text(

              lastUpdated == null

                  ? 'Waiting for data'

                  : 'Last updated: ${lastUpdated!.toLocal().toString().substring(11, 19)}',

              style: const TextStyle(

                color: muted,

                fontSize: 11,

              ),

            ),

            const SizedBox(width: 8),

            const Text(

              '•',

              style: TextStyle(color: muted),

            ),

            const SizedBox(width: 8),

            const Text(

              '5-second refresh interval',

              style: TextStyle(

                color: muted,

                fontSize: 11,

              ),

            ),

          ],

        ),

      ],

    );

  }



  Widget buildMetrics(int anomalies, int normal) {

    return LayoutBuilder(

      builder: (context, constraints) {

        final width = constraints.maxWidth;

        final columns = width > 900 ? 4 : width > 550 ? 2 : 1;

        final spacing = 14.0;

        final cardWidth = (width - spacing * (columns - 1)) / columns;



        return Wrap(

          spacing: spacing,

          runSpacing: spacing,

          children: [

            SizedBox(

              width: cardWidth,

              child: MetricCard(

                title: 'TOTAL TRACKERS',

                value: '${trackers.length}',

                icon: Icons.pets_outlined,

                color: blue,

                description: 'Registered devices',

              ),

            ),

            SizedBox(

              width: cardWidth,

              child: MetricCard(

                title: 'NORMAL',

                value: '$normal',

                icon: Icons.check_circle_outline,

                color: green,

                description: 'Normal predictions',

              ),

            ),

            SizedBox(

              width: cardWidth,

              child: MetricCard(

                title: 'ANOMALIES',

                value: '$anomalies',

                icon: Icons.warning_amber_rounded,

                color: red,

                description: 'Unusual readings',

              ),

            ),

            SizedBox(

              width: cardWidth,

              child: MetricCard(

                title: 'AI ENGINE',

                value: 'ACTIVE',

                icon: Icons.memory_outlined,

                color: const Color(0xFF8058C7),

                description: 'Isolation Forest',

                isText: true,

              ),

            ),

          ],

        );

      },

    );

  }



  Widget buildSectionHeader() {

    return Row(

      children: [

        const Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                'Tracker Monitoring',

                style: TextStyle(

                  color: navy,

                  fontWeight: FontWeight.bold,

                  fontSize: 18,

                ),

              ),

              SizedBox(height: 5),

              Text(

                'Latest telemetry and anomaly predictions',

                style: TextStyle(

                  color: muted,

                  fontSize: 12,

                ),

              ),

            ],

          ),

        ),

        if (connected)

          const StatusPill(

            label: 'MONITORING',

            color: green,

          ),

      ],

    );

  }



  Widget buildTrackerSection(bool wide) {

    if (trackers.isEmpty) {

      return const EmptyState();

    }



    if (wide) {

      return Container(

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: border),

        ),

        child: Column(

          children: [

            Container(

              padding: const EdgeInsets.symmetric(

                horizontal: 22,

                vertical: 16,

              ),

              decoration: const BoxDecoration(

                border: Border(

                  bottom: BorderSide(color: border),

                ),

              ),

              child: const Row(

                children: [

                  Expanded(flex: 2, child: TableLabel('TRACKER')),

                  Expanded(child: TableLabel('SPEED')),

                  Expanded(child: TableLabel('ACTIVITY')),

                  Expanded(child: TableLabel('AI STATUS')),

                  Expanded(child: TableLabel('DECISION SCORE')),

                ],

              ),

            ),

            ...trackers.map(

              (tracker) => TrackerTableRow(

                tracker: tracker,

              ),

            ),

          ],

        ),

      );

    }



    return Column(

      children: trackers.map((tracker) {

        return Padding(

          padding: const EdgeInsets.only(bottom: 12),

          child: TrackerMobileCard(tracker: tracker),

        );

      }).toList(),

    );

  }



  Widget buildError() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: border),

      ),

      child: Column(

        children: [

          const Icon(

            Icons.cloud_off_outlined,

            size: 35,

            color: red,

          ),

          const SizedBox(height: 12),

          const Text(

            'Unable to load tracker data',

            style: TextStyle(

              color: navy,

              fontWeight: FontWeight.bold,

            ),

          ),

          const SizedBox(height: 8),

          Text(

            error ?? 'Unknown error',

            style: const TextStyle(color: muted),

            textAlign: TextAlign.center,

          ),

          const SizedBox(height: 16),

          ElevatedButton(

            onPressed: () => fetchTrackers(showLoading: true),

            child: const Text('Retry connection'),

          ),

        ],

      ),

    );

  }



  Widget buildModelInfo() {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: const Color(0xFFEDF2FC),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(

          color: const Color(0xFFDCE6FA),

        ),

      ),

      child: const Row(

        children: [

          Icon(

            Icons.psychology_outlined,

            color: blue,

            size: 28,

          ),

          SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  'AI Anomaly Detection',

                  style: TextStyle(

                    fontWeight: FontWeight.bold,

                    color: navy,

                    fontSize: 13,

                  ),

                ),

                SizedBox(height: 5),

                Text(

                  'Tracker readings are analyzed using the Isolation Forest model. '

                  'An anomaly indicates unusual data, not necessarily an emergency.',

                  style: TextStyle(

                    color: Color(0xFF62738F),

                    fontSize: 11,

                    height: 1.5,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget buildFooter() {

    return Row(

      children: [

        const Text(

          'LIVESTOCK MONITOR',

          style: TextStyle(

            color: muted,

            fontWeight: FontWeight.bold,

            fontSize: 10,

            letterSpacing: 1,

          ),

        ),

        const Spacer(),

        const Text(

          'IoT Monitoring Platform',

          style: TextStyle(

            color: muted,

            fontSize: 10,

          ),

        ),

      ],

    );

  }

}



// ============================================================

// SIDEBAR

// ============================================================



class Sidebar extends StatelessWidget {

  final int selected;

  final bool isOwner;

  final ValueChanged<int> onSelect;



  const Sidebar({

    super.key,

    required this.selected,

    required this.isOwner,

    required this.onSelect,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      width: 245,

      color: navy,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(24, 27, 20, 35),

            child: Row(

              children: [

                Container(

                  width: 38,

                  height: 38,

                  decoration: BoxDecoration(

                    color: blue,

                    borderRadius: BorderRadius.circular(10),

                  ),

                  child: const Icon(

                    Icons.pets,

                    color: Colors.white,

                    size: 21,

                  ),

                ),

                const SizedBox(width: 12),

                const Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'LIVESTOCK',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 14,

                        fontWeight: FontWeight.w800,

                        letterSpacing: 1,

                      ),

                    ),

                    Text(

                      'MONITORING SYSTEM',

                      style: TextStyle(

                        color: Color(0xFF9DAEC7),

                        fontSize: 8,

                        letterSpacing: 1,

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

          const Padding(

            padding: EdgeInsets.only(left: 24, bottom: 12),

            child: Text(

              'WORKSPACE',

              style: TextStyle(

                color: Color(0xFF8295B1),

                fontSize: 10,

                fontWeight: FontWeight.bold,

                letterSpacing: 1.2,

              ),

            ),

          ),

          SidebarItem(

            icon: Icons.dashboard_outlined,

            label: 'Overview',

            active: selected == 0,

            onTap: () => onSelect(0),

          ),

          SidebarItem(

            icon: Icons.map_outlined,

            label: 'Map',

            active: selected == 1,

            onTap: () => onSelect(1),

          ),

          SidebarItem(
            icon: Icons.notifications_outlined,
            label: 'Alerts',
            active: selected == 2,
            onTap: () => onSelect(2),
          ),

          SidebarItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chats',
            active: selected == 3,
            onTap: () => onSelect(3),
          ),

          if (isOwner)

            SidebarItem(

              icon: Icons.people_outline,

              label: 'Shepherds',

              active: selected == 4,

              onTap: () => onSelect(4),

            ),

          const Spacer(),

          Container(

            margin: const EdgeInsets.all(16),

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(

              color: const Color(0xFF22334E),

              borderRadius: BorderRadius.circular(9),

            ),

            child: const Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  'SYSTEM',

                  style: TextStyle(

                    color: Color(0xFF9DAEC7),

                    fontSize: 9,

                    fontWeight: FontWeight.bold,

                    letterSpacing: 1,

                  ),

                ),

                SizedBox(height: 12),

                Row(

                  children: [

                    Icon(

                      Icons.circle,

                      color: Color(0xFF46C78A),

                      size: 8,

                    ),

                    SizedBox(width: 8),

                    Text(

                      'Monitoring service',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 10,

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

          const Padding(

            padding: EdgeInsets.fromLTRB(24, 0, 24, 22),

            child: Text(

              'PROJECT VERSION 1.0',

              style: TextStyle(

                color: Color(0xFF8295B1),

                fontSize: 9,

              ),

            ),

          ),

        ],

      ),

    );

  }

}



class SidebarItem extends StatelessWidget {

  final IconData icon;

  final String label;

  final bool active;

  final VoidCallback onTap;



  const SidebarItem({

    super.key,

    required this.icon,

    required this.label,

    required this.active,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        horizontal: 12,

        vertical: 2,

      ),

      child: Material(

        color: active

            ? const Color(0xFF293D5D)

            : Colors.transparent,

        borderRadius: BorderRadius.circular(8),

        child: InkWell(

          borderRadius: BorderRadius.circular(8),

          onTap: onTap,

          child: Padding(

            padding: const EdgeInsets.symmetric(

              horizontal: 13,

              vertical: 13,

            ),

            child: Row(

              children: [

                Icon(

                  icon,

                  color: active

                      ? Colors.white

                      : const Color(0xFF9DAEC7),

                  size: 19,

                ),

                const SizedBox(width: 12),

                Text(

                  label,

                  style: TextStyle(

                    color: active

                        ? Colors.white

                        : const Color(0xFF9DAEC7),

                    fontWeight: FontWeight.w600,

                    fontSize: 12,

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



// ============================================================

// METRIC CARD

// ============================================================



class MetricCard extends StatelessWidget {

  final String title;

  final String value;

  final String description;

  final IconData icon;

  final Color color;

  final bool isText;



  const MetricCard({

    super.key,

    required this.title,

    required this.value,

    required this.description,

    required this.icon,

    required this.color,

    this.isText = false,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: border),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Text(

                title,

                style: const TextStyle(

                  color: muted,

                  fontSize: 10,

                  fontWeight: FontWeight.bold,

                  letterSpacing: 0.7,

                ),

              ),

              Icon(

                icon,

                color: color,

                size: 21,

              ),

            ],

          ),

          const SizedBox(height: 17),

          Text(

            value,

            style: TextStyle(

              color: navy,

              fontSize: isText ? 23 : 29,

              fontWeight: FontWeight.w800,

              letterSpacing: -0.7,

            ),

          ),

          const SizedBox(height: 7),

          Text(

            description,

            style: const TextStyle(

              color: muted,

              fontSize: 11,

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================

// TRACKER TABLE

// ============================================================



class TableLabel extends StatelessWidget {

  final String text;



  const TableLabel(this.text, {super.key});



  @override

  Widget build(BuildContext context) {

    return Text(

      text,

      style: const TextStyle(

        color: muted,

        fontSize: 9,

        fontWeight: FontWeight.bold,

        letterSpacing: 0.6,

      ),

    );

  }

}



class TrackerTableRow extends StatelessWidget {

  final Map<String, dynamic> tracker;



  const TrackerTableRow({

    super.key,

    required this.tracker,

  });



  @override

  Widget build(BuildContext context) {

    final anomaly = tracker['is_anomaly'] == true;

    final color = anomaly ? red : green;

    final score = tracker['decision_score'];



    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 22,

        vertical: 20,

      ),

      decoration: const BoxDecoration(

        border: Border(

          bottom: BorderSide(color: border),

        ),

      ),

      child: Row(

        children: [

          Expanded(

            flex: 2,

            child: Row(

              children: [

                Container(

                  width: 34,

                  height: 34,

                  decoration: BoxDecoration(

                    color: const Color(0xFFF0F3F9),

                    borderRadius: BorderRadius.circular(8),

                  ),

                  child: const Icon(

                    Icons.pets,

                    size: 17,

                    color: blue,

                  ),

                ),

                const SizedBox(width: 12),

                Text(

                  '${tracker['tracker_id']}',

                  style: const TextStyle(

                    color: navy,

                    fontSize: 12,

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ],

            ),

          ),

          Expanded(

            child: DataValue('${tracker['speed']} km/h'),

          ),

          Expanded(

            child: DataValue('${tracker['activity']}'),

          ),

          Expanded(

            child: StatusPill(

              label: anomaly ? 'ANOMALY' : 'NORMAL',

              color: color,

            ),

          ),

          Expanded(

            child: DataValue(

              score is num ? score.toStringAsFixed(4) : 'N/A',

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================

// MOBILE TRACKER CARD

// ============================================================



class TrackerMobileCard extends StatelessWidget {

  final Map<String, dynamic> tracker;



  const TrackerMobileCard({

    super.key,

    required this.tracker,

  });



  @override

  Widget build(BuildContext context) {

    final anomaly = tracker['is_anomaly'] == true;

    final color = anomaly ? red : green;

    final score = tracker['decision_score'];



    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: border),

      ),

      child: Column(

        children: [

          Row(

            children: [

              Text(

                '${tracker['tracker_id']}',

                style: const TextStyle(

                  color: navy,

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                ),

              ),

              const Spacer(),

              StatusPill(

                label: anomaly ? 'ANOMALY' : 'NORMAL',

                color: color,

              ),

            ],

          ),

          const Divider(height: 25),

          InfoLine('Speed', '${tracker['speed']} km/h'),

          InfoLine('Activity', '${tracker['activity']}'),

          InfoLine('Latitude', '${tracker['lat']}'),

          InfoLine('Longitude', '${tracker['lon']}'),

          InfoLine(

            'Decision score',

            score is num ? score.toStringAsFixed(4) : 'N/A',

          ),

        ],

      ),

    );

  }

}



// ============================================================

// SMALL UI COMPONENTS

// ============================================================



class InfoLine extends StatelessWidget {

  final String label;

  final String value;



  const InfoLine(this.label, this.value, {super.key});



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 6),

      child: Row(

        children: [

          Text(

            label,

            style: const TextStyle(

              color: muted,

              fontSize: 11,

            ),

          ),

          const Spacer(),

          Text(

            value,

            style: const TextStyle(

              color: navy,

              fontSize: 11,

              fontWeight: FontWeight.w600,

            ),

          ),

        ],

      ),

    );

  }

}



class DataValue extends StatelessWidget {

  final String value;



  const DataValue(this.value, {super.key});



  @override

  Widget build(BuildContext context) {

    return Text(

      value,

      style: const TextStyle(

        color: navy,

        fontSize: 11,

        fontWeight: FontWeight.w600,

      ),

    );

  }

}



class StatusPill extends StatelessWidget {

  final String label;

  final Color color;



  const StatusPill({

    super.key,

    required this.label,

    required this.color,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 9,

        vertical: 6,

      ),

      decoration: BoxDecoration(

        color: color.withValues(alpha: 0.09),

        borderRadius: BorderRadius.circular(5),

      ),

      child: Text(

        label,

        style: TextStyle(

          color: color,

          fontSize: 9,

          fontWeight: FontWeight.w800,

          letterSpacing: 0.4,

        ),

      ),

    );

  }

}



class EmptyState extends StatelessWidget {

  const EmptyState({super.key});



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(35),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: border),

      ),

      child: const Column(

        children: [

          Icon(

            Icons.sensors_off_outlined,

            size: 35,

            color: muted,

          ),

          SizedBox(height: 12),

          Text(

            'No tracker data available',

            style: TextStyle(

              color: navy,

              fontWeight: FontWeight.bold,

            ),

          ),

        ],

      ),

    );

  }

}
