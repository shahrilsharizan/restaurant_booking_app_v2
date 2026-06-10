import 'package:go_router/go_router.dart';

import '../features/admin/ui/admin_dashboard_screen.dart';
import '../features/admin/ui/admin_booking_screens.dart';
import '../features/admin/ui/admin_package_screens.dart';
import '../features/admin/ui/admin_user_screens.dart';
import '../features/auth/ui/admin_login_screen.dart';
import '../features/auth/ui/sign_up_screen.dart';
import '../features/auth/ui/user_login_screen.dart';
import '../features/bookings/ui/booking_screens.dart';
import '../features/home/ui/userdashboard.dart';
import '../features/onboarding/ui/initial_screen.dart';
import '../features/packages/ui/package_list_screen.dart';
import '../features/profile/ui/user_profile_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const InitialScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) => const UserLoginScreen(),
    ),
    GoRoute(
      path: '/admin-login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/sign-up',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/packages',
      builder: (context, state) => const PackageListScreen(),
    ),
    GoRoute(
      path: '/user-dashboard',
      builder: (context, state) => const UserDashboardScreen(),
    ),
    GoRoute(
      path: '/user-profile',
      builder: (context, state) => const UserProfileScreen(),
    ),
    GoRoute(
      path: '/packages/:packageId',
      builder: (context, state) => PackageDetailsScreen(
        packageId: state.pathParameters['packageId']!,
        backRoute: state.extra is String ? state.extra as String : '/packages',
      ),
    ),
    GoRoute(
      path: '/bookings/new/:packageId',
      builder: (context, state) =>
          BookingFormScreen(packageId: state.pathParameters['packageId']!),
    ),
    GoRoute(
      path: '/bookings',
      builder: (context, state) => const BookingListScreen(),
    ),
    GoRoute(
      path: '/bookings/:bookingId/edit',
      builder: (context, state) {
        final extra = state.extra is Map<String, String>
            ? state.extra as Map<String, String>
            : const <String, String>{};
        return ModifyBookingScreen(
          bookingId: state.pathParameters['bookingId']!,
          backRoute: extra['backRoute'] ?? '/bookings',
          successHomeRoute: extra['successHomeRoute'] ?? '/packages',
          successDoneRoute: extra['successDoneRoute'] ?? '/bookings',
        );
      },
    ),
    GoRoute(
      path: '/bookings/:bookingId',
      builder: (context, state) =>
          BookingInfoScreen(bookingId: state.pathParameters['bookingId']!),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchResultsScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/packages',
      builder: (context, state) => const AdminPackageListScreen(),
    ),
    GoRoute(
      path: '/admin/packages/new',
      builder: (context, state) => const AdminCreatePackageScreen(),
    ),
    GoRoute(
      path: '/admin/packages/:packageId/edit',
      builder: (context, state) =>
          AdminEditPackageScreen(packageId: state.pathParameters['packageId']!),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const AdminUserDirectoryScreen(),
    ),
    GoRoute(
      path: '/admin/users/new',
      builder: (context, state) => const AdminAddUserScreen(),
    ),
    GoRoute(
      path: '/admin/users/:uid/edit',
      builder: (context, state) =>
          AdminEditUserScreen(uid: state.pathParameters['uid']!),
    ),
    GoRoute(
      path: '/admin/bookings',
      builder: (context, state) => const AdminBookingsScreen(),
    ),
    GoRoute(
      path: '/admin/bookings/:bookingId',
      builder: (context, state) =>
          AdminBookingInfoScreen(bookingId: state.pathParameters['bookingId']!),
    ),
  ],
);
