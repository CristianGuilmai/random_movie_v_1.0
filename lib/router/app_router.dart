import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/welcome_screen.dart';
import '../screens/home_screen.dart';
import '../screens/results_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart';
import '../models/movie.dart';
import '../screens/watched_screen.dart';
import '../screens/history_screen.dart';
import '../screens/advanced_search_screen.dart';
import '../screens/shared_list_screen.dart';
import '../state/app_state.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    // Verificar si es la primera vez del usuario
    final appState = context.read<AppState>();
    if (appState.isFirstTime && state.uri.path != '/welcome') {
      return '/welcome';
    } else if (!appState.isFirstTime && state.uri.path == '/welcome') {
      return '/';
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'results',
          name: 'results',
          builder: (context, state) => const ResultsScreen(),
        ),
        GoRoute(
          path: 'detail',
          name: 'detail',
          builder: (context, state) {
            final movie = state.extra as Movie;
            return DetailScreen(movie: movie);
          },
        ),
        GoRoute(
          path: 'favorites',
          name: 'favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: 'watched',
          name: 'watched',
          builder: (context, state) => const WatchedScreen(),
        ),
        GoRoute(
          path: 'history',
          name: 'history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: 'advanced-search',
          name: 'advanced-search',
          builder: (context, state) => const AdvancedSearchScreen(),
        ),
        GoRoute(
          path: 'shared-list',
          name: 'shared-list',
          builder: (context, state) {
            final sharedData = state.extra as Map<String, dynamic>;
            return SharedListScreen(sharedData: sharedData);
          },
        ),
      ],
    ),
  ],
);