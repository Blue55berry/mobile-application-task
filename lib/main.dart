import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leads_screen.dart';
import 'screens/task_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/lead_details_screen.dart';
import 'models/lead_model.dart';
import 'services/leads_service.dart';
import 'services/task_service.dart';
import 'services/label_service.dart';
import 'services/enhanced_call_service.dart';
import 'services/call_overlay_service.dart';
import 'services/background_service.dart';
import 'services/lead_broadcast_receiver.dart';
import 'services/auth_service.dart';
import 'services/team_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'utils/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Helper function to get page widget from route name
Widget _getPageForRoute(String routeName) {
  switch (routeName) {
    case '/dashboard':
      return const DashboardScreen();
    case '/leads':
      return const LeadsScreen();
    case '/tasks':
      return const TasksScreen();
    case '/settings':
      return const SettingsScreen();
    default:
      return const DashboardScreen();
  }
}

// MethodChannel for native Android communication
const methodChannel = MethodChannel('com.example.sbs/call_methods');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request necessary permissions
  await Permission.notification.request();
  await Permission.phone.request();

  // Initialize Background Service (keep existing for compatibility)
  await initializeBackgroundService();

  // Setup MethodChannel listener for native Android events
  _setupNativeCallListener();

  // Start native call monitoring service
  await _startNativeCallMonitoring();

  runApp(const MyApp());
}

/// Setup listener for native Android call events
void _setupNativeCallListener() {
  methodChannel.setMethodCallHandler((call) async {
    debugPrint('📱 Main app received method call: ${call.method}');

    switch (call.method) {
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
        // Authentication Service (must be first for other services to use)
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
            }
          });

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'SBS CRM',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system, // Follow system theme
            debugShowCheckedModeBanner: false,
            home: const DashboardScreen(),
            onGenerateRoute: (settings) {
              // Custom page transitions for all routes
              Widget page;

              if (settings.name == '/lead_details') {
                final lead = settings.arguments as Lead;
                page = LeadDetailScreen(lead: lead);
              } else {
                // Handle named routes
                page = _getPageForRoute(settings.name ?? '/dashboard');
              }

              // Return custom animated page transition
              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (context, animation, secondaryAnimation) => page,
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 250),
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
            },
          );
        },
      ),
    );
  }
}
