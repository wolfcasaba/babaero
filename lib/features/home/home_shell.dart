import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat/chat_list_screen.dart';
import '../chat/data/chat_provider.dart';
import '../discover/discover_screen.dart';
import '../matches/matches_screen.dart';
import '../profile/data/profile_provider.dart';
import '../profile/my_profile_screen.dart';
import '../timeline/timeline_screen.dart';

/// Root shell with a bottom nav. Keeps each tab's state alive via IndexedStack.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _tabs = [
    DiscoverScreen(),
    TimelineScreen(),
    MatchesScreen(),
    ChatListScreen(),
    MyProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mark online as soon as the app is in the foreground on the home shell.
    _setOnline(true);
  }

  @override
  void dispose() {
    _setOnline(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Drive real presence off the app lifecycle so is_online / last_active
    // reflect actual activity (Discover ordering + the online dot depend on it).
    _setOnline(state == AppLifecycleState.resumed);
  }

  void _setOnline(bool online) {
    ref.read(profileRepositoryProvider).setOnline(online);
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadTotalProvider);
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          height: 66,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(LucideIcons.flame),
              label: 'Discover',
            ),
            const NavigationDestination(
              icon: Icon(LucideIcons.newspaper),
              label: 'Feed',
            ),
            const NavigationDestination(
              icon: Icon(LucideIcons.heart),
              label: 'Matches',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(LucideIcons.messageCircle),
              ),
              label: 'Messages',
            ),
            const NavigationDestination(
              icon: Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
