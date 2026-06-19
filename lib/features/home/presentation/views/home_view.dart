import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_addis_app/core/utils/image_constant.dart';
import 'package:my_addis_app/features/home/presentation/viewmodels/home_viewmodel.dart';
import 'package:my_addis_app/features/map/presentation/views/map_view.dart';
import 'package:my_addis_app/features/profile/presentation/views/profile_view.dart';
import 'package:my_addis_app/features/report/presentation/views/report_view.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(homeViewModelProvider.notifier).loadData(),
    );
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final pages = [
      _buildHomeScreen(theme, scheme),
      const MapView(),
      const ReportView(),
      const ProfileView(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Addis Ababa Live'),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: switch (state) {
        HomeLoading() => const Center(child: CircularProgressIndicator()),
        HomeError(:final message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(homeViewModelProvider.notifier).loadData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        _ => pages[_selectedIndex],
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: const Icon(Icons.report_problem_outlined),
            selectedIcon: const Icon(Icons.report_problem),
            label: 'Report',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreen(ThemeData theme, ColorScheme scheme) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(theme, scheme),
            const SizedBox(height: 28),
            Text(
              'Quick actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildActionCard(
                        scheme,
                        icon: Icons.report_problem,
                        title: 'Report an Issue',
                        subtitle: 'Fast city issue reporting',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildActionCard(
                        scheme,
                        icon: Icons.local_offer,
                        title: 'Find Services',
                        subtitle: 'Search public and utility services',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'City guidance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              context,
              scheme,
              icon: Icons.location_city,
              title: 'Trusted by residents',
              subtitle:
                  'Get reliable access to city services and local support.',
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              context,
              scheme,
              icon: Icons.shield,
              title: 'Secure & up to date',
              subtitle: 'Built with modern city data and a secure experience.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withAlpha(46),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              return isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: ClipOval(
                            child: Image.asset(
                              '../../../../../assets/images/adis1.png',
                              width: 60,
                              height: 60,
                              // fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to Addis Ababa',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A modern app for local services, reports, and trusted city news.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            AppImages.addisAbaba,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome to Addis Ababa',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A modern app for local services, reports, and trusted city news.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFlagChip(scheme, scheme.primary, 'Green'),
              _buildFlagChip(scheme, scheme.secondary, 'Yellow'),
              _buildFlagChip(scheme, scheme.error, 'Red'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagChip(ColorScheme scheme, Color background, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background.withAlpha(41),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: background,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
