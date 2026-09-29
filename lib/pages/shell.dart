import 'dart:async';

import 'package:flutter/material.dart';

import '../app/config.dart';
import '../core/store.dart';
import '../widgets/glass.dart';
import 'home_page.dart';
import 'me_page.dart';
import 'messages_page.dart';
import 'rank_page.dart';
import 'web_page.dart';

/// 应用外壳：背景光晕 + 椭圆形液态玻璃底部栏 + 5 个 Tab
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _state = AppState.i;
  List<FeatureSpec> _features = FeatureRegistry.active;
  int _index = 0;
  StreamSubscription<String>? _navSub;
  final Set<String> _built = <String>{};

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChange);
    _navSub = NavBus.i.stream.listen(_gotoId);
    _built.add(_features.isEmpty ? 'home' : _features.first.id);
  }

  @override
  void dispose() {
    _navSub?.cancel();
    _state.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {
      _features = FeatureRegistry.active;
      if (_index >= _features.length) _index = 0;
    });
  }

  void _gotoId(String id) {
    final i = _features.indexWhere((f) => f.id == id);
    if (i < 0) return;
    _goto(i);
  }

  void _goto(int i) {
    if (i < 0 || i >= _features.length) return;
    setState(() {
      _index = i;
      _built.add(_features[i].id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _features
        .map((f) => NavItem(id: f.id, label: f.label, icon: iconFor(f.icon)))
        .toList();

    return AuroraBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: List<Widget>.generate(_features.length, (i) {
            final id = _features[i].id;
            if (!_built.contains(id)) return const SizedBox.shrink();
            return _pageFor(id);
          }),
        ),
        bottomNavigationBar: GlassPillNav(
          items: items,
          index: _index,
          badges: _state.badges,
          onChanged: _goto,
        ),
      ),
    );
  }

  Widget _pageFor(String id) {
    switch (id) {
      case 'home':
        return HomePage(onOpenTab: _gotoId);
      case 'rank':
        return const RankPage();
      case 'community':
        return const WebInline(title: '社区', path: '/feed');
      case 'messages':
        return MessagesPage(onNeedLogin: () => _gotoId('me'));
      case 'me':
        return const MePage();
      default:
        return const WebInline(title: '更多', path: '/');
    }
  }
}
