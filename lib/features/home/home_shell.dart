import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat/chat_list_screen.dart';
import '../discover/discover_screen.dart';
import '../matches/matches_screen.dart';
import '../profile/my_profile_screen.dart';

/// Root shell with a bottom nav. Keeps each tab's state alive via IndexedStack.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    DiscoverScreen(),
    MatchesScreen(),
    ChatListScreen(),
    MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.flame),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.heart),
              label: 'Matches',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.messageCircle),
              label: 'Messages',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
