import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../core/ui.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _input = TextEditingController();
  bool _loading = false;
  String? _q;
  String? _err;
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _players = const [];
  List<Map<String, dynamic>> _threads = const [];
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _input.text = widget.initialQuery;
    _loadHistory();
    if (widget.initialQuery.trim().isNotEmpty) {
      _search(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final sp = await SharedPreferences.getInstance();
    final h = sp.getStringList('search_history') ?? const <String>[];
    if (mounted) setState(() => _history = h);
  }

  Future<void> _saveHistory(String q) async {
    final sp = await SharedPreferences.getInstance();
    final h = sp.getStringList('search_history') ?? <String>[];
    h.remove(q);
    h.insert(0, q);
    final next = h.take(8).toList();
    await sp.setStringList('search_history', next);
    if (mounted) setState(() => _history = next);
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.length < 1) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _q = q;
      _err = null;
    });
    try {
      final j = await Api.i.search(q);
      if (!mounted) return;
      setState(() {
        _users = asList(j['users']);
        _players = asList(j['players']);
        _threads = asList(j['threads']);
        _loading = false;
      });
      await _saveHistory(q);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPage(
      title: '搜索',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: const InputDecoration(
                      hintText: '玩家、用户、帖子',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _search(_input.text),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : (_q == null
                    ? _emptyState(context)
                    : _results(context, cs)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        if (_history.isNotEmpty) ...[
          SectionTitle(
            title: '最近搜索',
            trailing: TextButton(
              onPressed: () async {
                final sp = await SharedPreferences.getInstance();
                await sp.remove('search_history');
                if (mounted) setState(() => _history = const []);
              },
              child: const Text('清空'),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _history
                .map(
                  (q) => ActionChip(
                    label: Text(q),
                    onPressed: () {
                      _input.text = q;
                      _search(q);
                    },
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Icon(Icons.travel_explore_rounded,
                  color: cs.onSurfaceVariant, size: 42),
              const SizedBox(height: 10),
              Text(
                '输入玩家名、站内昵称或帖子关键词',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _results(BuildContext context, ColorScheme cs) {
    if (_err != null) {
      return ErrorView(message: _err!, onRetry: () => _search(_q ?? ''));
    }
    if (_users.isEmpty && _players.isEmpty && _threads.isEmpty) {
      return EmptyView(
        text: '没有找到「$_q」相关结果',
        icon: Icons.search_off_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
      children: [
        if (_users.isNotEmpty) ...[
          const SectionTitle(title: '用户'),
          ..._users.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Nav.to(
                  '/u/${Uri.encodeComponent(asStr(u['username']))}',
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: asStr(u['username']),
                      avatar: asStrOrNull(u['avatar']),
                      size: 40,
                      online: asBool(u['online']),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asStr(u['username']),
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            asStr(u['bio'], '这个人很懒，什么都没写'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (_players.isNotEmpty) ...[
          const SectionTitle(title: '游戏玩家'),
          ..._players.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Nav.to(
                  '/p/${Uri.encodeComponent(asStr(p['name']))}',
                ),
                child: Row(
                  children: [
                    UserAvatar(name: asStr(p['name']), size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        asStr(p['name']),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'Lv.${asInt(p['level'])} · ${asDouble(p['playtimeHours']).toStringAsFixed(1)}h',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (_threads.isNotEmpty) ...[
          const SectionTitle(title: '帖子'),
          ..._threads.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Nav.to(
                  '/forum/thread/${asInt(t['id'])}',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asStr(t['title'], '无标题'),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (asStr(t['body']).isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        asStr(t['body']),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
