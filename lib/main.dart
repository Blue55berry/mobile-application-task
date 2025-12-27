import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/task_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/enhanced_onboarding_screen.dart';
import 'screens/lead_details_screen.dart';
import 'screens/companies_screen.dart';
import 'screens/quotations_screen.dart';
import 'screens/create_quotation_screen.dart';
import 'screens/quotation_details_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/create_invoice_screen.dart';
import 'screens/business_menu_screen.dart';
import 'models/lead_model.dart';
import 'services/leads_service.dart';
import 'services/task_service.dart';
import 'services/label_service.dart';
import 'services/enhanced_call_service.dart';
import 'services/call_overlay_service.dart';
import 'services/lead_broadcast_receiver.dart';
import 'services/auth_service.dart';
import 'services/team_service.dart';
import 'services/quotation_service.dart';
import 'services/invoice_service.dart';
import 'services/subscription_service.dart';
import 'services/company_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/theme.dart';

// Check if onboarding is complete
Future<bool> _checkOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_complete') ?? false;
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Helper function to get page widget from route name
Widget _getPageForRoute(String routeName) {
  switch (routeName) {
    case '/onboarding':
      return const OnboardingScreen();
    case '/login':
      return const LoginScreen();
    case '/dashboard':
      return const DashboardScreen();
    case '/leads':
      return const LeadsScreen();
    case '/tasks':
      return const TasksScreen();
    case '/settings':
      return const SettingsScreen();
    case '/quotations':
      return const QuotationsScreen();
    case '/create_quotation':
      return const CreateQuotationScreen();
    case '/invoices':
      return const InvoicesScreen();
    case '/create_invoice':
      return const CreateInvoiceScreen();
    case '/business_menu':
      return const BusinessMenuScreen();
    case '/enhanced_onboarding':
      return const EnhancedOnboardingScreen();
    default:
      return const DashboardScreen();
  }
}

// MethodChannel for native Android communication
const methodChannel = MethodChannel('com.example.sbs/call_methods');

void main() async {
  // Ensure Flutter is initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST and wait for it
  try {
    debugPrint('🔥 Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    // If we're on a platform that requires options (like Windows/Web without config),
    // it will fail here. But on Android with google-services.json it should work.
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Request necessary permissions
  try {
    await [Permission.notification, Permission.phone].request();
  } catch (e) {
    debugPrint('⚠️ Error requesting permissions: $e');
  }

  // Setup MethodChannel listener
  _setupNativeCallListener();

  // Start native monitoring
  await _startNativeCallMonitoring();

  runApp(const MyApp());
}

/// Setup listener for native Android call events
void _setupNativeCallListener() {
  methodChannel.setMethodCallHandler((call) async {
    debugPrint('📱 Main app received method call: ${call.method}');

    switch (call.method) {
      case 'getContactPhoto':
        // Android requesting photo path for phone number
        final phoneNumber = call.arguments as String?;
        if (phoneNumber != null) {
          // This will be called from Android overlay service
          // Return cached photo path if available
          debugPrint('📸 Android requesting photo for: $phoneNumber');
          // Will be handled after app is built
          return null; // Placeholder for now
        }
        return null;

      case 'onIncomingCall':
        debugPrint('📞 Native incoming call event');
        // Events are now handled by overlay service
        break;

      case 'onOutgoingCall':
        debugPrint('📞 Native outgoing call event');
        break;

      case 'onCallStarted':
        debugPrint('📞 Native call started event');
        break;

      case 'onCallEnded':
        debugPrint('📞 Native call ended event');
        break;

      case 'onNewLeadSaved':
        debugPrint('✅ New lead saved broadcast received');
        // Forward to broadcast receiver - will be handled by LeadBroadcastReceiver
        break;

      case 'onLeadUpdated':
        debugPrint('🔄 Lead updated broadcast received');
        // Forward to broadcast receiver - will be handled by LeadBroadcastReceiver
        break;

      default:
        debugPrint('⚠️ Unknown method: ${call.method}');
    }
  });
}

/// Start native call monitoring (Android side)
Future<void> _startNativeCallMonitoring() async {
  try {
    await methodChannel.invokeMethod('startCallMonitoring');
    debugPrint('✅ Native call monitoring started');
  } catch (e) {
    debugPrint('❌ Error starting native call monitoring: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CallOverlayService()),
        ChangeNotifierProvider(create: (_) => EnhancedCallService()),
        ChangeNotifierProxyProvider<EnhancedCallService, CallOverlayService>(
          create: (context) => context.read<CallOverlayService>(),
          update: (context, callService, overlayService) {
            // Connect call service with overlay service
            callService.setOverlayService(overlayService!);
            return overlayService;
          },
        ),
        ChangeNotifierProvider(create: (_) => TaskService()),
        ChangeNotifierProvider(create: (_) => LabelService()),
        ChangeNotifierProvider(create: (_) => TeamService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        ChangeNotifierProvider(create: (_) => CompanyService()),
        ChangeNotifierProvider(create: (_) => QuotationService()),
        ChangeNotifierProvider(create: (_) => InvoiceService()),
        ChangeNotifierProxyProvider<TaskService, LeadsService>(
          create: (context) => LeadsService(context.read<TaskService>()),
          update: (context, taskService, leadsService) =>
              leadsService!..update(taskService),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Initialize overlay after first frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (navigatorKey.currentState != null) {
              final overlay = navigatorKey.currentState!.overlay;
              if (overlay != null) {
                context.read<CallOverlayService>().initialize(
                  overlay,
                  context: navigatorKey.currentContext,
                );
              }

              // Initialize broadcast receiver for lead sync
              final leadsService = context.read<LeadsService>();
              final broadcastReceiver = LeadBroadcastReceiver(
                leadsService: leadsService,
                navigatorKey: navigatorKey,
              );
              broadcastReceiver.initialize();

              // Initialize AuthService to restore user session
              final authService = context.read<AuthService>();
              authService.initialize();

              // Initialize TeamService
              final teamService = context.read<TeamService>();
              teamService.initialize();

              // Initialize SubscriptionService
              final subscriptionService = context.read<SubscriptionService>();
              subscriptionService.initialize();

              // Initialize CompanyService
              final companyService = context.read<CompanyService>();
              companyService.initialize();
            }
          });

          return Consumer<AuthService>(
            builder: (context, authService, child) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                title: 'SBS CRM',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeMode.system,
                debugShowCheckedModeBanner: false,
                showPerformanceOverlay: false,
                showSemanticsDebugger: false,
                debugShowMaterialGrid: false,
                // Show onboarding if first launch, login if not signed in, otherwise dashboard
                home: FutureBuilder<bool>(
                  future: _checkOnboardingComplete(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        authService.isLoading) {
                      return const Scaffold(
                        backgroundColor: Color(0xFF1A1A2E),
                        body: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6C5CE7),
                          ),
                        ),
                      );
                    }

                    final onboardingComplete = snapshot.data ?? false;
                    if (!onboardingComplete) {
                      return const OnboardingScreen();
                    }

                    return authService.isSignedIn
                        ? const DashboardScreen()
                        : const LoginScreen();
                  },
                ),
                onGenerateRoute: (settings) {
                  // Handle routes with arguments
                  if (settings.name == '/quotation_details') {
                    final quotationId = settings.arguments as int;
                    return PageRouteBuilder(
                      settings: settings,
                      pageBuilder: (context, animation, _) =>
                          QuotationDetailsScreen(quotationId: quotationId),
                      transitionDuration: const Duration(milliseconds: 300),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            const begin = Offset(0.05, 0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOutCubic;
                            var slideTween = Tween(
                              begin: begin,
                              end: end,
                            ).chain(CurveTween(curve: curve));
                            var fadeTween = Tween<double>(
                              begin: 0.0,
                              end: 1.0,
                            ).chain(CurveTween(curve: curve));
                            return FadeTransition(
                              opacity: animation.drive(fadeTween),
                              child: SlideTransition(
                                position: animation.drive(slideTween),
                                child: child,
                              ),
                            );
                          },
                    );
                  } else if (settings.name == '/create_quotation') {
                    final quotationId = settings.arguments as int?;
                    return PageRouteBuilder(
                      settings: settings,
                      pageBuilder: (context, animation, _) =>
                          CreateQuotationScreen(quotationId: quotationId),
                      transitionDuration: const Duration(milliseconds: 300),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            const begin = Offset(0.05, 0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOutCubic;
                            var slideTween = Tween(
                              begin: begin,
                              end: end,
                            ).chain(CurveTween(curve: curve));
                            var fadeTween = Tween<double>(
                              begin: 0.0,
                              end: 1.0,
                            ).chain(CurveTween(curve: curve));
                            return FadeTransition(
                              opacity: animation.drive(fadeTween),
                              child: SlideTransition(
                                position: animation.drive(slideTween),
                                child: child,
                              ),
                            );
                          },
                    );
                  }
                  // Custom page transitions for all routes
                  Widget page;

                  if (settings.name == '/lead_details') {
                    final lead = settings.arguments as Lead;
                    page = LeadDetailScreen(lead: lead);
                  } else if (settings.name == '/companies') {
                    page = const CompaniesScreen();
                  } else {
                    // Handle named routes
                    page = _getPageForRoute(settings.name ?? '/dashboard');
                  }

                  // Return custom animated page transition
                  return PageRouteBuilder(
                    settings: settings,
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        page,
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 250,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          // Smooth fade + slide transition
                          const begin = Offset(0.05, 0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOutCubic;

                          var slideTween = Tween(
                            begin: begin,
                            end: end,
                          ).chain(CurveTween(curve: curve));
                          var fadeTween = Tween<double>(
                            begin: 0.0,
                            end: 1.0,
                          ).chain(CurveTween(curve: curve));

                          return FadeTransition(
                            opacity: animation.drive(fadeTween),
                            child: SlideTransition(
                              position: animation.drive(slideTween),
                              child: child,
                            ),
                          );
                        },
                  );
                },
                routes: {
                  '/dashboard': (context) => const DashboardScreen(),
                  '/leads': (context) => const LeadsScreen(),
                  '/tasks': (context) => const TasksScreen(),
                  '/settings': (context) => const SettingsScreen(),
                  '/quotations': (context) => const QuotationsScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}
