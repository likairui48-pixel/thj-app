import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/api.dart';
import '../core/img.dart';
import '../core/store.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/kit.dart';
import 'login_page.dart';

/// 会员状态卡（商城 / 我的 页面共用）
class MembershipCard extends StatelessWidget {
  const MembershipCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final active = asBool(data['active']);
    final tier = asMap(data['tier']);
    final label = active
        ? asStr(tier['label'], asStr(data['group'], '会员'))
        : '还不是会员';
    final until = asInt(data['until']);
    final permanent = asBool(data['permanent']);
    final days = asInt(data['daysLeft']);
    final color = _tierColor(asStrOrNull(tier['color']));
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withOpacity(0.45)),
            ),
            child: Icon(
              active
                  ? Icons.workspace_premium_rounded
                  : Icons.person_outline_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: t.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    if (active && asStrOrNull(tier['badge']) != null) ...[
                      const SizedBox(width: 6),
                      MiniBadge(text: asStr(tier['badge']), color: color),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? (permanent
                          ? '永久有效'
                          : '剩余 $days 天 · ${_date(until)} 到期')
                      : '开通会员可享专属标识 / 特权（见下方礼包）',
                  style: TextStyle(color: t.text3, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 会员与充值：商城礼包 / 我的订单 / 兑换码
class PayPage extends StatefulWidget {
  const PayPage({super.key});

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  bool _loading = true;
  String? _err;
  Map<String, dynamic> _config = const {};
  List<Map<String, dynamic>> _products = const [];
  List<Map<String, dynamic>> _orders = const [];
  Map<String, dynamic> _member = const {};
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final cfg = await Api.i.shopConfig();
      final prod = await Api.i.shopProducts();
      var orders = <Map<String, dynamic>>[];
      var member = <String, dynamic>{};
      if (AppState.i.me?.loggedIn == true) {
        try {
          final o = await Api.i.shopOrders();
          orders = (o['orders'] as List? ?? const [])
              .map((e) => asMap(e))
              .toList();
        } catch (_) {}
        try {
          member = await Api.i.membership();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _locked = asInt(cfg['locked']) == 1 || asInt(prod['locked']) == 1;
        _products = (prod['products'] as List? ?? const [])
            .map((e) => asMap(e))
            .toList();
        _orders = orders;
        _member = member;
        _loading = false;
      });
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
    final t = GlassTokens.of(context);
    return AuroraBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: t.text,
          title: Text('会员与充值',
              style: TextStyle(
                  color: t.text, fontSize: 17, fontWeight: FontWeight.w700)),
          bottom: TabBar(
            controller: _tab,
            indicatorColor: t.accent,
            labelColor: t.text,
            unselectedLabelColor: t.text3,
            tabs: const [
              Tab(text: '礼包'),
              Tab(text: '订单'),
              Tab(text: '兑换'),
            ],
          ),
        ),
        body: AsyncView(
          loading: _loading,
          error: _err,
          onRetry: _load,
          child: TabBarView(
            controller: _tab,
            children: [_shopTab(), _ordersTab(), _redeemTab()],
          ),
        ),
      ),
    );
  }

  // ---------------- 礼包 ----------------
  Widget _shopTab() {
    final t = GlassTokens.of(context);
    final notice = asStrOrNull(_config['payNotice']);
    final qr = asMap(_config['qr']);
    final hasQr =
        asStrOrNull(qr['wechat']) != null || asStrOrNull(qr['alipay']) != null;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 30),
        children: [
          MembershipCard(data: _member),
          if (_locked) ...[
            const SizedBox(height: 10),
            GlassPanel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      color: Color(0xFFE0623A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      asStr(asMap(_config['lock'])['title'], '专区暂未开放'),
                      style: TextStyle(color: t.text2, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (notice != null && notice.isNotEmpty) ...[
            const SizedBox(height: 10),
            GlassPanel(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_outlined, size: 17, color: t.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(notice,
                        style: TextStyle(
                            color: t.text2, fontSize: 12.5, height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
          SectionTitle(title: '礼包 / 会员', sub: hasQr ? '支持微信 / 支付宝扫码' : null),
          if (_products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: EmptyHint(text: '暂时没有可购买的内容', icon: Icons.card_giftcard_rounded),
            )
          else
            ..._products.map(_productCard),
          if (AppState.i.me?.loggedIn != true)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: GlassButton(
                label: '登录后购买',
                icon: Icons.login_rounded,
                primary: true,
                onTap: () async {
                  if (await requireLogin(context, reason: '登录后才能购买')) _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final t = GlassTokens.of(context);
    final canBuy = asBool(p['canBuy']);
    final stock = p['stock'];
    final limitLeft = p['limitLeft'];
    final state = asStr(p['state'], 'on');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        onTap: canBuy ? () => _orderFlow(p) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(asStr(p['name']),
                            style: TextStyle(
                                color: t.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (asStrOrNull(p['badge']) != null) ...[
                        const SizedBox(width: 6),
                        MiniBadge(
                            text: asStr(p['badge']),
                            color: const Color(0xFFE0623A)),
                      ],
                    ],
                  ),
                ),
                Text(asStr(p['priceText'], yuan(asInt(p['price']))),
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ],
            ),
            if (asInt(p['origPrice']) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(asStr(p['origText']),
                    style: TextStyle(
                        color: t.text3,
                        fontSize: 11.5,
                        decoration: TextDecoration.lineThrough)),
              ),
            if (asStr(p['desc']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(asStr(p['desc']),
                    style: TextStyle(
                        color: t.text2, fontSize: 12.5, height: 1.5)),
              ),
            const SizedBox(height: 9),
            Row(
              children: [
                if (asBool(p['hasMembership']) && asInt(p['days']) > 0)
                  MiniBadge(
                      text: '${asInt(p['days'])} 天会员',
                      color: t.accent,
                      icon: Icons.workspace_premium_rounded),
                if (asBool(p['needAddr']))
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: MiniBadge(
                        text: '需收货信息',
                        color: Color(0xFF7A6CE0),
                        icon: Icons.local_shipping_outlined),
                  ),
                if (stock != null && asInt(stock) >= 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('库存 ${asInt(stock)}',
                        style: TextStyle(color: t.text3, fontSize: 11)),
                  ),
                if (limitLeft != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('限购剩 ${asInt(limitLeft)}',
                        style: TextStyle(color: t.text3, fontSize: 11)),
                  ),
                const Spacer(),
                Text(
                  !canBuy
                      ? (state == 'before'
                          ? '未开售'
                          : (state == 'after' ? '已结束' : '已售罄'))
                      : '立即购买',
                  style: TextStyle(
                      color: canBuy ? t.accent : t.text3,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 下单流程 ----------------
  Future<void> _orderFlow(Map<String, dynamic> p) async {
    if (!await requireLogin(context, reason: '登录后才能购买')) return;
    if (!mounted) return;
    final specs = (p['specs'] as List? ?? const []).map((e) => asMap(e)).toList();
    final chosen = <String, String>{
      for (final s in specs)
        asStr(s['name']): (s['options'] as List? ?? const []).isNotEmpty
            ? asStr((s['options'] as List).first)
            : ''
    };
    var qty = 1;
    var deliverMode = asStr(p['deliverDefault'], 'auto');
    final receiver = TextEditingController();
    final phone = TextEditingController();
    final addr = TextEditingController();
    final qq = TextEditingController();
    final note = TextEditingController();

    final go = await GlassSheet.show<bool>(
      context,
      child: StatefulBuilder(
        builder: (ctx, setSt) {
          final t = GlassTokens.of(ctx);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('购买 · ${asStr(p['name'])}',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(asStr(p['priceText'], yuan(asInt(p['price']))),
                  style: TextStyle(color: t.accent, fontSize: 14)),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in specs) ...[
                        Text(asStr(s['name']),
                            style: TextStyle(color: t.text2, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: (s['options'] as List? ?? const [])
                              .map((o) => GlassChip(
                                    label: o.toString(),
                                    active: chosen[asStr(s['name'])] ==
                                        o.toString(),
                                    onTap: () => setSt(() =>
                                        chosen[asStr(s['name'])] = o.toString()),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (asBool(p['hasMembership']) && asInt(p['days']) > 0) ...[
                        Text('开通方式',
                            style:
                                TextStyle(color: t.text2, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            GlassChip(
                              label: '立即开通',
                              active: deliverMode == 'auto',
                              onTap: () => setSt(() => deliverMode = 'auto'),
                            ),
                            GlassChip(
                              label: '给我卡密',
                              active: deliverMode == 'code',
                              onTap: () => setSt(() => deliverMode = 'code'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Text('数量',
                              style:
                                  TextStyle(color: t.text2, fontSize: 12.5)),
                          const SizedBox(width: 12),
                          GlassIconButton(
                            icon: Icons.remove_rounded,
                            size: 32,
                            onTap: qty > 1
                                ? () => setSt(() => qty -= 1)
                                : null,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('$qty',
                                style: TextStyle(
                                    color: t.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ),
                          GlassIconButton(
                            icon: Icons.add_rounded,
                            size: 32,
                            onTap: asInt(p['limitLeft']) > qty || p['limitLeft'] == null
                                ? () => setSt(() => qty += 1)
                                : null,
                          ),
                        ],
                      ),
                      if (asBool(p['needAddr'])) ...[
                        const SizedBox(height: 12),
                        _field(receiver, '收件人姓名', 1),
                        const SizedBox(height: 8),
                        _field(phone, '手机号（11 位）', 1,
                            type: TextInputType.phone),
                        const SizedBox(height: 8),
                        _field(addr, '收货地址（省市区 + 详细）', 2),
                        const SizedBox(height: 8),
                        _field(qq, 'QQ（可选，方便联系）', 1),
                      ],
                      const SizedBox(height: 12),
                      _field(note, '备注（可选）', 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: '取消',
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: '提交订单',
                      primary: true,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    if (go != true || !mounted) return;

    try {
      final j = await Api.i.shopOrder({
        'productId': asInt(p['id']),
        'qty': qty,
        if (specs.isNotEmpty) 'spec': chosen,
        'deliverMode': deliverMode,
        if (asBool(p['needAddr'])) ...{
          'receiver': receiver.text.trim(),
          'phone': phone.text.trim(),
          'addr': addr.text.trim(),
          'qq': qq.text.trim(),
        },
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      });
      final order = asMap(j['order']);
      if (!mounted) return;
      await _paySheet(order, thenRefresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('下单失败：$e')));
    }
  }

  /// 付款信息：收款码 + 单号后 4 位 + 截图
  Future<void> _paySheet(Map<String, dynamic> order,
      {bool thenRefresh = false}) async {
    final ref4 = TextEditingController();
    final note = TextEditingController();
    String proof = '';
    var method = 'wechat';
    final qr = asMap(_config['qr']);
    final id = asInt(order['id']);
    final amountText = asStr(order['amountText'], yuan(asInt(order['amount'])));

    final ok = await GlassSheet.show<bool>(
      context,
      child: StatefulBuilder(
        builder: (ctx, setSt) {
          final t = GlassTokens.of(ctx);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('订单 ${asStr(order['orderNo'], '#$id')}',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('应付 $amountText · ${asStr(order['productName'])}',
                  style: TextStyle(color: t.text2, fontSize: 13)),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          GlassChip(
                            label: '微信',
                            active: method == 'wechat',
                            onTap: () => setSt(() => method = 'wechat'),
                          ),
                          GlassChip(
                            label: '支付宝',
                            active: method == 'alipay',
                            onTap: () => setSt(() => method = 'alipay'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Builder(builder: (c) {
                        final url = asStrOrNull(qr[method]);
                        if (url == null) {
                          return Text('收款码未配置，请联系管理员',
                              style: TextStyle(color: t.text3, fontSize: 12.5));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('扫码付款后回来填写下面的信息',
                                style:
                                    TextStyle(color: t.text3, fontSize: 12)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () =>
                                  showImageViewer(context, Api.i.abs(url)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(R.tile),
                                child: Image.network(Api.i.abs(url),
                                    width: 190,
                                    height: 190,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(
                                        width: 190,
                                        height: 190,
                                        alignment: Alignment.center,
                                        color: t.fill,
                                        child: Text('收款码加载失败',
                                            style: TextStyle(
                                                color: t.text3,
                                                fontSize: 12)))),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 12),
                      _field(ref4, '付款单号后 4 位数字', 1,
                          type: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly]),
                      const SizedBox(height: 8),
                      _field(note, '备注（可选）', 2),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          GlassButton(
                            label: proof.isEmpty ? '上传付款截图' : '已选择 ✓',
                            icon: Icons.image_outlined,
                            expand: false,
                            height: 40,
                            onTap: () async {
                              final d = await Img.pickDataUrl(
                                  maxEdge: 1200, quality: 70);
                              if (d == null) return;
                              setSt(() => proof = d);
                            },
                          ),
                          if (proof.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(R.tile - 6),
                                child: Image.memory(
                                  base64Decode(proof.split(',').last),
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('付款单号后 4 位和截图选填其一即可，站长核对到账后开通。',
                          style: TextStyle(color: t.text3, fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: '稍后再填',
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: '我已付款',
                      primary: true,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await Api.i.shopSubmit(id, {
        'payMethod': method,
        'ref4': ref4.text.trim(),
        if (proof.isNotEmpty) 'proof': proof,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已提交，等站长核对到账后就开通 👍')));
      await _load();
      if (thenRefresh) _tab.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('提交失败：$e')));
    }
  }

  // ---------------- 订单 ----------------
  Widget _ordersTab() {
    final t = GlassTokens.of(context);
    if (AppState.i.me?.loggedIn != true) {
      return ListView(
        padding: const EdgeInsets.all(R.page),
        children: [
          EmptyHint(text: '登录后查看你的订单', icon: Icons.receipt_long_outlined),
          const SizedBox(height: 12),
          GlassButton(
            label: '去登录',
            primary: true,
            onTap: () async {
              if (await requireLogin(context)) _load();
            },
          ),
        ],
      );
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(R.page),
          children: const [
            EmptyHint(text: '还没有订单', icon: Icons.receipt_long_outlined),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(R.page, 14, R.page, 30),
        itemCount: _orders.length,
        itemBuilder: (c, i) {
          final o = _orders[i];
          final status = asStr(o['status'], 'pending');
          final pending = status == 'pending';
          final needsReview = asBool(o['needsReview']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassPanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(asStr(o['productName']),
                            style: TextStyle(
                                color: t.text,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      MiniBadge(
                        text: _statusText(status, needsReview),
                        color: _statusColor(status, needsReview),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${asStr(o['orderNo'])} · ${asStr(o['amountText'])}'
                    '${asInt(o['qty']) > 1 ? ' ×${asInt(o['qty'])}' : ''}',
                    style: TextStyle(color: t.text2, fontSize: 12.5),
                  ),
                  if (asStr(o['spec']).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(asStr(o['spec']),
                          style: TextStyle(color: t.text3, fontSize: 12)),
                    ),
                  if (asStrOrNull(o['code']) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText('卡密：${asStr(o['code'])}',
                                style: TextStyle(
                                    color: t.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                          GlassChip(
                            label: '复制',
                            onTap: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: asStr(o['code'])));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('卡密已复制')));
                            },
                          ),
                        ],
                      ),
                    ),
                  if (asStrOrNull(o['trackingNo']) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                          '快递：${asStr(o['trackingCompany'])} ${asStr(o['trackingNo'])}',
                          style: TextStyle(color: t.text2, fontSize: 12)),
                    ),
                  if (asStrOrNull(o['adminNote']) != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('站长留言：${asStr(o['adminNote'])}',
                          style: TextStyle(color: t.text2, fontSize: 12)),
                    ),
                  const SizedBox(height: 6),
                  Text(ago(o['createdAt']),
                      style: TextStyle(color: t.text3, fontSize: 11)),
                  if (pending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: needsReview ? '修改付款信息' : '我已付款',
                            icon: Icons.upload_rounded,
                            height: 40,
                            primary: !needsReview,
                            onTap: () => _paySheet(o),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GlassButton(
                          label: '取消',
                          height: 40,
                          expand: false,
                          onTap: () async {
                            final yes = await GlassDialog.confirm(
                              context,
                              title: '取消订单',
                              message: '取消后需要重新下单，确定吗？',
                              okLabel: '取消订单',
                              danger: true,
                            );
                            if (yes != true || !mounted) return;
                            try {
                              await Api.i.shopCloseOrder(asInt(o['id']));
                              await _load();
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('取消失败：$e')));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- 兑换码 ----------------
  Widget _redeemTab() {
    final t = GlassTokens.of(context);
    final ctl = TextEditingController();
    String? msg;
    bool okFlag = false;
    return StatefulBuilder(
      builder: (ctx, setSt) => ListView(
        padding: const EdgeInsets.fromLTRB(R.page, 16, R.page, 30),
        children: [
          SectionTitle(title: '兑换码', sub: '签到奖励 / 站长发放的卡密'),
          GlassPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(ctl, 'THJ-XXXX-XXXX-XXXX', 1),
                const SizedBox(height: 12),
                GlassButton(
                  label: '兑换',
                  icon: Icons.redeem_rounded,
                  primary: true,
                  onTap: () async {
                    final code = ctl.text.trim();
                    if (code.isEmpty) return;
                    if (!await requireLogin(context, reason: '登录后才能兑换')) {
                      return;
                    }
                    try {
                      final r = await Api.i.shopRedeem(code);
                      setSt(() {
                        okFlag = true;
                        msg =
                            '兑换成功 🎉\n会员：${asStr(r['group'])}\n到期：${_date(asInt(r['until']))}';
                      });
                      _load();
                    } catch (e) {
                      setSt(() {
                        okFlag = false;
                        msg = e.toString();
                      });
                    }
                  },
                ),
                if (msg != null) ...[
                  const SizedBox(height: 12),
                  Text(msg!,
                      style: TextStyle(
                        color: okFlag ? const Color(0xFF2E9E63) : t.text2,
                        fontSize: 12.5,
                        height: 1.5,
                      )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('提示：兑换会员需要先绑定游戏账号（我的 → 绑定游戏账号）。',
              style: TextStyle(color: t.text3, fontSize: 11.5, height: 1.5)),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, int lines,
      {TextInputType? type, List<TextInputFormatter>? formatters}) {
    final t = GlassTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.fill,
        borderRadius: BorderRadius.circular(R.tile),
        border: Border.all(color: t.stroke),
      ),
      child: TextField(
        controller: c,
        maxLines: lines,
        keyboardType: type,
        inputFormatters: formatters,
        style: TextStyle(color: t.text, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: t.text3, fontSize: 12.5),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        ),
      ),
    );
  }
}

String _statusText(String s, bool needsReview) {
  switch (s) {
    case 'pending':
      return needsReview ? '待审核' : '待付款';
    case 'paid':
      return '已付款';
    case 'shipped':
      return '已发货';
    case 'done':
      return '已完成';
    case 'closed':
      return '已关闭';
    default:
      return s;
  }
}

Color _statusColor(String s, bool needsReview) {
  switch (s) {
    case 'pending':
      return needsReview ? const Color(0xFFCC9A2B) : const Color(0xFFE0623A);
    case 'paid':
    case 'shipped':
      return const Color(0xFF2E9E63);
    case 'done':
      return const Color(0xFF2FA6A0);
    default:
      return const Color(0xFF8A8A8A);
  }
}

String _date(int ms) {
  if (ms <= 0) return '长期';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Color _tierColor(String? hex) {
  const fallback = Color(0xFF2E9E63);
  if (hex == null || hex.isEmpty) return fallback;
  var s = hex.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? fallback : Color(v);
}
