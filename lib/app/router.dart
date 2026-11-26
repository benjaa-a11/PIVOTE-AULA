import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/design_system/app_colors.dart';
import '../core/design_system/app_motion.dart';
import '../core/design_system/app_radius.dart';
import '../core/design_system/app_spacing.dart';
import '../core/design_system/app_typography.dart';
import '../core/design_system/components/app_button.dart';
import '../core/design_system/components/aula_logo.dart';
import '../core/design_system/components/quick_capture_sheet.dart';
import '../core/design_system/responsive.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/subjects/presentation/subjects_screen.dart';
import '../features/subjects/presentation/subject_detail_screen.dart';
import '../features/exams/presentation/exam_detail_screen.dart';
import '../features/grades/presentation/grades_screen.dart';
import '../features/search/presentation/global_search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({required bool hasProfile}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: hasProfile ? '/home' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _animatedPage(context, state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) =>
            _animatedPage(context, state, const GlobalSearchScreen()),
      ),
      GoRoute(
        path: '/subjects/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _animatedPage(
            context,
            state,
            SubjectDetailScreen(subjectId: id),
          );
        },
      ),
      GoRoute(
        path: '/exams/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _animatedPage(context, state, ExamDetailScreen(examId: id));
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/subjects',
                builder: (context, state) => const SubjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/grades',
                builder: (context, state) => const GradesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage<void> _animatedPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: reduceMotion ? Duration.zero : AppMotion.routeDuration,
    reverseTransitionDuration:
        reduceMotion ? Duration.zero : AppMotion.routeReverseDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(curved);

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: slide,
          child: child,
        ),
      );
    },
  );
}

class _NavDestinationSpec {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavDestinationSpec({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const List<_NavDestinationSpec> _destinations = [
  _NavDestinationSpec(
    icon: Icons.space_dashboard_outlined,
    activeIcon: Icons.space_dashboard_rounded,
    label: 'Inicio',
  ),
  _NavDestinationSpec(
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Agenda',
  ),
  _NavDestinationSpec(
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories_rounded,
    label: 'Materias',
  ),
  _NavDestinationSpec(
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics_rounded,
    label: 'Notas',
  ),
  _NavDestinationSpec(
    icon: Icons.tune_outlined,
    activeIcon: Icons.tune_rounded,
    label: 'Ajustes',
  ),
];

class _ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _ScaffoldWithNavBar({required this.navigationShell});

  void _selectBranch(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surface(context);
    final border = AppColors.border(context);

    if (context.useNavigationRail) {
      final expandedSidebar = context.isExpanded;
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: expandedSidebar ? 240 : 88,
              decoration: BoxDecoration(
                color: surface,
                border: Border(right: BorderSide(color: border, width: 1)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: expandedSidebar ? AppSpacing.md : AppSpacing.sm,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: expandedSidebar
                        ? CrossAxisAlignment.stretch
                        : CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: expandedSidebar ? AppSpacing.xs : 0,
                        ),
                        child: expandedSidebar
                            ? const AulaBrandLockup(
                                markSize: 36,
                                showTagline: true,
                              )
                            : const AulaLogoMark(size: 38),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (expandedSidebar)
                        AppButton(
                          label: 'Registrar',
                          icon: Icons.add_rounded,
                          isExpanded: true,
                          onPressed: () => QuickCaptureSheet.show(context),
                        )
                      else
                        IconButton.filled(
                          tooltip: 'Registrar nuevo',
                          onPressed: () => QuickCaptureSheet.show(context),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      for (int i = 0; i < _destinations.length; i++) ...[
                        _SidebarItem(
                          spec: _destinations[i],
                          isSelected: navigationShell.currentIndex == i,
                          expanded: expandedSidebar,
                          onTap: () => _selectBranch(i),
                        ),
                        const SizedBox(height: 4),
                      ],
                      const Spacer(),
                      if (expandedSidebar)
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () => context.push('/search'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle(context),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary(context),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Buscar todo...',
                                    style: AppTypography.label.copyWith(
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        IconButton(
                          tooltip: 'Buscar',
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search_rounded),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: Row(
              children: [
                for (int i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _NavBarItem(
                      icon: _destinations[i].icon,
                      activeIcon: _destinations[i].activeIcon,
                      label: _destinations[i].label,
                      isSelected: navigationShell.currentIndex == i,
                      onTap: () => _selectBranch(i),
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

class _SidebarItem extends StatelessWidget {
  final _NavDestinationSpec spec;
  final bool isSelected;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.spec,
    required this.isSelected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final fg = isSelected
        ? AppColors.readableAccent(primary, isDark: isDark)
        : AppColors.textSecondary(context);
    final bg = isSelected
        ? primary.withValues(alpha: isDark ? 0.18 : 0.10)
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? AppSpacing.md : 0,
            vertical: 11,
          ),
          child: expanded
              ? Row(
                  children: [
                    Icon(
                      isSelected ? spec.activeIcon : spec.icon,
                      size: 21,
                      color: fg,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        spec.label,
                        style: AppTypography.titleSmall.copyWith(
                          color: fg,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? spec.activeIcon : spec.icon,
                      size: 22,
                      color: fg,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spec.label,
                      style: AppTypography.caption.copyWith(
                        color: fg,
                        fontSize: 10.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final selectedColor = AppColors.readableAccent(primary, isDark: isDark);
    final idleColor = AppColors.textSecondary(context);
    final color = isSelected ? selectedColor : idleColor;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withValues(alpha: isDark ? 0.20 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
