import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'player_page.dart';

/// 排行榜：段位筛选 + 服务端分页（滚动续载）+ 假人折叠
class RankPage extends StatefulWidget {
  const RankPage({super.key});

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 30;

  final _scroll = ScrollController();
  final List<RankRow> _rows = <RankRow>[];
  List<TierInfo> _tiers = const <TierInfo>[];
  String? _tier;
  int _total = 0;
  int _fakesFolded = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _err;
  bool _first = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _err = null;
      _rows.clear();
      _hasMore = true;
    });
    try {
      final j = await Api.i.board(
        limit: _pageSize,
        offset: 0,
        tier: _tier,
        showFakes: AppState.i.showFakes,
      );
      final rows = asList(j['board']).map(RankRow.fromJson).toList();
      final tiers = asList(j['tiers']).map(TierInfo.fromJson).toList();
      setState(() {
        _rows.addAll(rows);
        if (tiers.isNotEmpty) _tiers = tiers;
        _total = asInt(j['total']);
        _fakesFolded = asInt(j['fakesFolded']);
        _hasMore = rows.length >= _pageSize;
        _first = false;
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final j = await Api.i.board(
        limit: _pageSize,
        offset: _rows.length,
        tier: _tier,
        showFakes: AppState.i.showFakes,
      );
      final rows = asList(j['board']).map(RankRow.fromJson).toList();
      setState(() {
        _rows.addAll(rows);
        _hasMore = rows.length >= _pageSize;
      });
    } catch (_) {
      setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = GlassTokens.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      color: t.accent,
      backgroundColor:
          t.brightness == Brightness.dark ? const Color(0xFF16171A) : Colors.white,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          R.page,
          MediaQuery.of(context).padding.top + 8,
          R.page,
          GlassPillNav.reserved(context),
        ),
        itemCount: _rows.length + 3,
        itemBuilder: (context, i) {
          if (i == 0) return _head(t);
          if (i == 1) return _tierRow(t);
          if (i == 2) return _metaRow(t);
          final row = _rows[i - 3];
          return _rowTile(t, row, index: i - 3);
        },
      ),
    );
  }

  Widget _head(GlassTokens t) {
    final s = AppState.i.season;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('排行榜',
                style: TextStyle(
                    color: t.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
            const Spacer(),
            if (AppState.i.me?.loggedIn == true)
              GlassChip(
                label: '我在这',
                icon: Icons.my_location_rounded,
                onTap: _jumpToMe,
              ),
          ],
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          strong: true,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s?.name ?? '当前赛季',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      s == null
                          ? '赛季数据加载中'
                          : '共 $_total 位玩家 · 剩余 ${s.daysLeft} 天',
                      style: TextStyle(color: t.text3, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (s != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(R.tile),
                    border: Border.all(color: t.accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('${s.daysLeft}',
                          style: TextStyle(
                              color: t.accent,
                              fontSize: 20,
                              height: 1,
                              fontWeight: FontWeight.w800)),
                      Text('天后结算',
                          style: TextStyle(color: t.text3, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tierRow(GlassTokens t) {
    final chips = <Widget>[
      GlassChip(
        label: '全部',
        active: _tier == null,
        onTap: () {
          if (_tier != null) {
            setState(() => _tier = null);
            _reload();
          }
        },
      ),
    ];
    for (final tier in _tiers) {
      chips.add(GlassChip(
        label: tier.label,
        active: _tier == tier.key,
        color: Color(tier.color),
        onTap: () {
          setState(() => _tier = _tier == tier.key ? null : tier.key);
          _reload();
        },
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Center(child: chips[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaRow(GlassTokens t) {
    if (_err != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ErrorHint(message: _err!, onRetry: _reload),
      );
    }
    if (_loading && _rows.isEmpty) {
      return Column(
        children: List<Widget>.generate(
          6,
          (_) => const Padding(
            padding: EdgeInsets.only(top: 9),
            child: GlassSkeleton(height: 62, radius: 18),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          Text(
            _first ? '加载中…' : '已显示 ${_rows.length} / $_total',
            style: TextStyle(color: t.text3, fontSize: 11.5),
          ),
          const Spacer(),
          if (_fakesFolded > 0)
            Text('已折叠 $_fakesFolded 个假人',
                style: TextStyle(color: t.text3, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _rowTile(GlassTokens t, RankRow row, {required int index}) {
    final isTop3 = row.pos <= 3;
    final tierColor = Color(row.tier.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        radius: R.tile,
        strong: isTop3,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerPage(name: row.name)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${row.pos}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isTop3 ? t.text : t.text3,
                  fontSize: isTop3 ? 18 : 15,
                  fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PlayerAvatar(name: row.name, size: 38),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: t.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${hoursText(row.hours)} · 放置 ${shortNum(row.placed)}'
                    '${row.level == null ? '' : ' · Lv.${row.level}'}',
                    style: TextStyle(color: t.text3, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${row.score}',
                    style: TextStyle(
                        color: t.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(R.pill),
                    border: Border.all(color: tierColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    row.tier.label,
                    style: TextStyle(
                        color: tierColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _jumpToMe() async {
    final me = AppState.i.me;
    final name = me?.mcName;
    if (name == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('你还没有绑定 Minecraft 账号')),
      );
      return;
    }
    try {
      final j = await Api.i.get('/api/rank/${Uri.encodeComponent(name)}');
      final r = asMap(j['rank']);
      final pos = asInt(r['position']);
      if (!mounted) return;
      if (pos <= 0 || pos > _rows.length) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('你当前第 $pos 名，已刷新榜单')),
        );
      } else {
        _scroll.animateTo(
          ((pos - 1) * 71).toDouble().clamp(
                0,
                _scroll.position.maxScrollExtent,
              ),
          duration: Motion.page,
          curve: Motion.ease,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('定位失败：$e')));
    }
  }
}
