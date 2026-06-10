import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'src/core/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: RestaurantBookingApp()));
}

class RestaurantBookingApp extends ConsumerWidget {
  const RestaurantBookingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const Color brandPurple = Color(0xFF6C2DDC);

    return MaterialApp.router(
      title: 'Restaurant Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandPurple,
        primary: brandPurple,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: brandPurple.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: brandPurple);
            }
            return const IconThemeData(color: Colors.black54);
          }),
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
