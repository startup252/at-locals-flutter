import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/nearest_screen.dart';
import 'screens/property_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/staff_screen.dart';
import 'screens/host_dashboard_screen.dart';
import 'screens/broker_dashboard_screen.dart';
import 'screens/add_property_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_edit_screen.dart';

export 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const AtLocalsApp(),
    ),
  );
}

class AtLocalsApp extends StatelessWidget {
  const AtLocalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.loading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF2563EB),
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    final router = GoRouter(
      initialLocation: '/splash',
      redirect: (ctx, state) {
        final loggedIn = ctx.read<AuthProvider>().isLoggedIn;
        final loc = state.matchedLocation;
        if (loc == '/splash') return null;
        if (!loggedIn && loc != '/login' && loc != '/register') return '/login';
        if (loggedIn && (loc == '/login' || loc == '/register')) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/splash',   builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

        // Full-screen routes (no bottom nav)
        GoRoute(
          path: '/property/:id',
          builder: (_, s) => PropertyScreen(propertyId: s.pathParameters['id']!),
        ),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/profile/edit',  builder: (_, __) => const ProfileEditScreen()),
        GoRoute(path: '/add-property',  builder: (_, __) => const AddPropertyScreen()),

        // Shell with bottom nav
        ShellRoute(
          builder: (ctx, state, child) =>
              _Shell(child: child, location: state.matchedLocation),
          routes: [
            GoRoute(path: '/',         builder: (_, __)  => const HomeScreen()),
            GoRoute(path: '/search',   builder: (_, s)   => SearchScreen(initialType: s.uri.queryParameters['type'])),
            GoRoute(path: '/nearest',  builder: (_, __)  => const NearestScreen()),
            GoRoute(path: '/bookings', builder: (_, __)  => const BookingsScreen()),
            GoRoute(path: '/profile',  builder: (_, __)  => const ProfileScreen()),
            GoRoute(path: '/admin',    builder: (_, __)  => const AdminScreen()),
            GoRoute(path: '/staff',    builder: (_, __)  => const StaffScreen()),
            GoRoute(path: '/host',     builder: (_, __)  => const HostDashboardScreen()),
            GoRoute(path: '/broker',   builder: (_, __)  => const BrokerDashboardScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'At Locals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      ),
      routerConfig: router,
    );
  }
}

// ── Role helpers ──────────────────────────────────────────────────────────────

String _dashboardRoute(String role) {
  switch (role) {
    case 'ADMIN':
    case 'SUPER_ADMIN': return '/admin';
    case 'STAFF': return '/staff';
    case 'HOST': return '/host';
    case 'BROKER': return '/broker';
    default: return '/bookings';
  }
}

String _dashboardLabel(String role) {
  switch (role) {
    case 'ADMIN':
    case 'SUPER_ADMIN': return 'Admin';
    case 'STAFF': return 'Staff';
    case 'HOST': return 'My Properties';
    case 'BROKER': return 'Broker';
    default: return 'My Booking';
  }
}

IconData _dashboardIcon(String role) {
  switch (role) {
    case 'ADMIN':
    case 'SUPER_ADMIN': return Icons.admin_panel_settings_outlined;
    case 'STAFF': return Icons.support_agent_outlined;
    case 'HOST': return Icons.home_work_outlined;
    case 'BROKER': return Icons.handshake_outlined;
    default: return Icons.calendar_today_outlined;
  }
}

IconData _dashboardIconSelected(String role) {
  switch (role) {
    case 'ADMIN':
    case 'SUPER_ADMIN': return Icons.admin_panel_settings_rounded;
    case 'STAFF': return Icons.support_agent_rounded;
    case 'HOST': return Icons.home_work_rounded;
    case 'BROKER': return Icons.handshake_rounded;
    default: return Icons.calendar_today_rounded;
  }
}

// ── Shell with role-aware bottom nav ──────────────────────────────────────────

class _Shell extends StatelessWidget {
  final Widget child;
  final String location;
  const _Shell({required this.child, required this.location});

  int _getIndex(String role) {
    if (location.startsWith('/search'))  return 1;
    if (location.startsWith('/nearest')) return 2;
    final dashRoute = _dashboardRoute(role);
    if (location == dashRoute || location.startsWith(dashRoute)) return 3;
    if (location.startsWith('/bookings')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role ?? 'GUEST';
    final idx = _getIndex(role);
    final dashRoute = _dashboardRoute(role);
    final dashLabel = _dashboardLabel(role);
    final dashIcon = _dashboardIcon(role);
    final dashIconSel = _dashboardIconSelected(role);
    final activeColor = _roleNavColor(role);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
        ),
        child: NavigationBar(
          selectedIndex: idx,
          backgroundColor: Colors.white,
          indicatorColor: activeColor.withOpacity(0.12),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            switch (i) {
              case 0: context.go('/');
              case 1: context.go('/search');
              case 2: context.go('/nearest');
              case 3: context.go(dashRoute);
              case 4: context.go('/profile');
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: activeColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded, color: activeColor),
              label: 'Search',
            ),
            NavigationDestination(
              icon: const Icon(Icons.near_me_outlined),
              selectedIcon: Icon(Icons.near_me_rounded, color: activeColor),
              label: 'Nearest',
            ),
            NavigationDestination(
              icon: Icon(dashIcon),
              selectedIcon: Icon(dashIconSel, color: activeColor),
              label: dashLabel,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded, color: activeColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Color _roleNavColor(String role) {
    switch (role) {
      case 'ADMIN':
      case 'SUPER_ADMIN': return const Color(0xFF7C3AED);
      case 'STAFF': return const Color(0xFF0EA5E9);
      case 'HOST': return const Color(0xFF2563EB);
      case 'BROKER': return const Color(0xFF4F46E5);
      default: return const Color(0xFF2563EB);
    }
  }
}

// ── Reusable brand logo widget ─────────────────────────────────────────────────
class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/logo.svg',
    height: height,
    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
  );
}
