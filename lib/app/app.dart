import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design_system/app_colors.dart';
import '../core/services/security_service.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/security/presentation/lock_screen.dart';
import 'router.dart';
import 'theme.dart';

class AulaScrollBehavior extends MaterialScrollBehavior {
  const AulaScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const ClampingScrollPhysics();
    }
    return super.getScrollPhysics(context);
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return child;
    }
    return super.buildOverscrollIndicator(context, child, details);
  }
}

class AulaApp extends ConsumerStatefulWidget {
  final bool hasProfile;
  const AulaApp({super.key, required this.hasProfile});

  @override
  ConsumerState<AulaApp> createState() => _AulaAppState();
}

class _AulaAppState extends ConsumerState<AulaApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  bool _isLocked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createRouter(hasProfile: widget.hasProfile);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLock() async {
    final lockEnabled = await SecurityService.instance.isLockEnabled();
    final hasPin = await SecurityService.instance.hasPin();
    if (lockEnabled && hasPin && widget.hasProfile && mounted) {
      setState(() => _isLocked = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final hasProfileNow =
          ref.read(profileStreamProvider).value != null || widget.hasProfile;
      if (_pausedAt != null && hasProfileNow) {
        final diff = DateTime.now().difference(_pausedAt!).inSeconds;
        if (diff > 15) {
          Future.wait([
            SecurityService.instance.isLockEnabled(),
            SecurityService.instance.hasPin(),
          ]).then((results) {
            if (results[0] && results[1] && mounted) {
              setState(() => _isLocked = true);
            }
          });
        }
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileStreamProvider);
    final profile = profileAsync.value;

    final accentColor = profile != null
        ? Color(profile.accentColorValue)
        : const Color(AppColors.defaultAccentValue);

    final themeMode = switch (profile?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final reduceMotion = profile?.reduceMotion ?? false;

    return MaterialApp.router(
      title: 'Pivote Aula',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AulaScrollBehavior(),
      theme: AppTheme.light(accentColor: accentColor),
      darkTheme: AppTheme.dark(accentColor: accentColor),
      themeMode: themeMode,
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('es', ''),
        Locale('en', ''),
      ],
      locale: const Locale('es', 'AR'),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final effectiveMedia = reduceMotion
            ? media.copyWith(disableAnimations: true)
            : media;

        return MediaQuery(
          data: effectiveMedia,
          child: Stack(
            children: [
              if (child != null) child,
              if (_isLocked)
                Positioned.fill(
                  child: LockScreen(
                    onUnlocked: () => setState(() => _isLocked = false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
