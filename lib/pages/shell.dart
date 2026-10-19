import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/state.dart';
import '../core/ui.dart';
import 'community.dart';
import 'home.dart';
import 'me.dart';
import 'messages.dart';
import 'rank.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _state = AppState.i;
  List<TabSpec> _tabs = AppState.i.config.tabs;
  int _index = 0;
  StreamSubscription<String>? _tabSub;
  final Set<String> _built = <String>{};

  @override
  void initState() {
    super.initState();
    _state.addListener(_onState);
    _tabSub = Nav.tabs.listen(_goto);
    _built.add(_tabs.isEmpty ? 'home' : _tabs.first.id);
  }

  @override
  void dispose() {
    _state.removeListener(_onState);
    _tabSub?.cancel();
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    final next = _state.config.tabs;
    if (next.length != _tabs.length ||
        (next.isNotEmpty &&
            _tabs.isNotEmpty &&
            next.first.id != _tabs.first.id)) {
      setState(() {
        _tabs = next.isEmpty ? AppConfig.defaultTabs : next;
        if (_index >= _tabs.length) _index = 0;
      });
    } else {
      setState(() {});
    }
  }

  void _goto(String id) {
    final i = _tabs.indexWhere((t) => t.id == id);
    if (i < 0) return;
    setState(() {
      _index = i;
      _built.add(_tabs[i].id);
    });
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _built.add(_tabs[i].id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs.isEmpty ? AppConfig.defaultTabs : _tabs;
    if (_index >= tabs.length) _index = 0;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List<Widget>.generate(tabs.length, (i) {
          final id = tabs[i].id;
          if (!_built.contains(id)) return const SizedBox.shrink();
          return _pageFor(id, tabs[i]);
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: _badgeIcon(t, false),
              selectedIcon: _badgeIcon(t, true),
              label: t.label,
            ),
        ],
      ),
    );
  }

  Widget _badgeIcon(TabSpec t, bool selected) {
    final icon = Icon(_iconFor(t.icon));
    final count = _state.badges[t.id] ?? 0;
    if (!t.badge || count <= 0) return icon;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: icon,
    );
  }

  Widget _pageFor(String id, TabSpec tab) {
    switch (id) {
      case 'home':
        return const HomePage();
      case 'community':
        return const CommunityPage();
      case 'messages':
        return const MessagesPage();
      case 'rank':
        return const RankPage();
      case 'me':
        return const MePage();
      default:
        return _RemoteTabPage(tab: tab);
    }
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'home':
        return Icons.cottage_rounded;
      case 'community':
        return Icons.forum_rounded;
      case 'message':
      case 'messages':
        return Icons.chat_bubble_rounded;
      case 'rank':
        return Icons.leaderboard_rounded;
      case 'person':
      case 'me':
        return Icons.person_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'event':
        return Icons.celebration_rounded;
      case 'settings':
        return Icons.tune_rounded;
      default:
        return Icons.apps_rounded;
    }
  }
}

class _RemoteTabPage extends StatelessWidget {
  const _RemoteTabPage({required this.tab});
  final TabSpec tab;

  @override
  Widget build(BuildContext context) {
    final url = tab.url;
    return AppPage(
      title: tab.label,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.extension_rounded,
                  color: AppColors.brand, size: 42),
              const SizedBox(height: 14),
              const Text('这个入口由站点远程配置开启'),
              const SizedBox(height: 6),
              Text(
                url == null || url.isEmpty
                    ? '当前版本还没有内置该页面，请更新 App。'
                    : '点击下方按钮在浏览器打开。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              if (url != null && url.isNotEmpty) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(Api.i.abs(url));
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('在浏览器打开'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
