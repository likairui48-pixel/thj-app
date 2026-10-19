import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/state.dart';
import '../core/ui.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _tiers = const [];
  Map<String, dynamic> _payInfo = <String, dynamic>{};
  Map<String, dynamic> _member = <String, dynamic>{};
  List<Map<String, dynamic>> _payments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        Api.i.tiers(),
        Api.i.payInfo(),
        Api.i.membership(),
        Api.i.myPayments(),
      ]);
      if (!mounted) return;
      setState(() {
        _tiers = asList(results[0]['tiers']);
        _payInfo = results[1];
        _member = results[2];
        _payments = asList(results[3]['payments']);
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

  Future<void> _pay(Map<String, dynamic> pkg) async {
    final note = TextEditingController();
    final ref4 = TextEditingController();
    String method = 'wechat';
    String? proof;
    var busy = false;
    final isDonate = asInt(pkg['price']) <= 0;
    final amount = TextEditingController(
      text: isDonate ? '' : '${asInt(pkg['price'])}',
    );
    final qr = asMap(_payInfo['qr']);

    await showAppSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '开通 · ${asStr(pkg['name'], '会员')}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                asStr(pkg['note'] ?? _payInfo['notice']),
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (qr['wechat'] != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => showImageViewer(
                          ctx,
                          [asStr(qr['wechat'])],
                          0,
                        ),
                        child: Column(
                          children: [
                            NetImage(
                              url: asStr(qr['wechat']),
                              width: 110,
                              height: 110,
                            ),
                            const SizedBox(height: 4),
                            const Text('微信收款码',
                                style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  if (qr['alipay'] != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => showImageViewer(
                          ctx,
                          [asStr(qr['alipay'])],
                          0,
                        ),
                        child: Column(
                          children: [
                            NetImage(
                              url: asStr(qr['alipay']),
                              width: 110,
                              height: 110,
                            ),
                            const SizedBox(height: 4),
                            const Text('支付宝收款码',
                                style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金额（元）',
                  prefixIcon: Icon(Icons.currency_yuan_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: method,
                      decoration:
                          const InputDecoration(labelText: '付款方式'),
                      items: const [
                        DropdownMenuItem(
                            value: 'wechat', child: Text('微信')),
                        DropdownMenuItem(
                            value: 'alipay', child: Text('支付宝')),
                      ],
                      onChanged: (v) => setSt(() => method = v ?? 'wechat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: ref4,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: '单号后 4 位',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: '备注（游戏 ID 会自动带上）',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final d =
                      await ImgPicker.one(maxWidth: 1400, quality: 80);
                  if (d != null) setSt(() => proof = d);
                },
                icon: Icon(
                  proof == null
                      ? Icons.upload_rounded
                      : Icons.check_circle_rounded,
                  size: 17,
                ),
                label: Text(proof == null ? '上传付款截图' : '已选择截图'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final a = double.tryParse(amount.text.trim()) ?? 0;
                        if (a <= 0) {
                          showToast(ctx, '请填写金额', error: true);
                          return;
                        }
                        setSt(() => busy = true);
                        try {
                          await Api.i.paySubmit({
                            'packageId': asStr(pkg['id']),
                            'amount': a,
                            'method': method,
                            'ref4': ref4.text.trim(),
                            'note': note.text.trim(),
                            if (proof != null) 'proof': proof,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          if (mounted) {
                            showToast(context, '已提交，等待管理员核对');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            showToast(ctx, e.toString(), error: true);
                          }
                        } finally {
                          if (ctx.mounted) setSt(() => busy = false);
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('提交付款信息'),
              ),
            ],
          ),
        ),
      ),
    );
    amount.dispose();
    note.dispose();
    ref4.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = asBool(_member['active']);
    final tier = asMap(_member['tier']);
    final packages = asList(_payInfo['packages']);
    return AppPage(
      title: '会员与充值',
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新',
        ),
      ],
      child: AsyncView(
        loading: _loading,
        error: _err,
        onRetry: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            AppCard(
              color: active
                  ? parseColor(asStr(tier['color'])).withOpacity(0.08)
                  : null,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: (active
                              ? parseColor(asStr(tier['color']))
                              : cs.onSurfaceVariant)
                          .withOpacity(0.13),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: active
                          ? parseColor(asStr(tier['color']))
                          : cs.onSurfaceVariant,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active
                              ? '${asStr(tier['label'], '会员')} · 生效中'
                              : '普通玩家',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          active
                              ? (asBool(_member['permanent'])
                                  ? '永久有效'
                                  : '有效期至 ${fmtDate(_member['until'])} · 剩 ${asInt(_member['daysLeft'])} 天')
                              : '开通后游戏内权限自动同步，立即生效',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle(title: '会员档位'),
            ..._tiers.map((t) {
              final color = parseColor(asStr(t['color']));
              final benefits = asStrList(t['benefits']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              asStr(t['label'], '?').substring(0, 1),
                              style: TextStyle(
                                color: color,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      asStr(t['name'], '会员'),
                                      style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (asStr(t['badge']).isNotEmpty)
                                      Pill(
                                        text: asStr(t['badge']),
                                        color: color,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  asStr(t['slogan']),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '¥${asDouble(t['price']).toStringAsFixed(asDouble(t['price']) == asDouble(t['price']).roundToDouble() ? 0 : 1)}'
                            '\n/${asInt(t['days'])}天',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                      if (benefits.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        ...benefits.take(5).map(
                              (b) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_rounded,
                                        color: color, size: 13),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        b,
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 10.5,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SectionTitle(title: '充值 / 赞助'),
            ...packages.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asStr(p['name'], '充值'),
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              asStr(p['note']),
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        asInt(p['price']) <= 0
                            ? '自定'
                            : '¥${asInt(p['price'])}',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _pay(p),
                        child: Text(asInt(p['price']) <= 0 ? '赞助' : '开通'),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            Text(
              asStr(_payInfo['notice'], '付款后请提交订单信息，管理员核对后开通。'),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
            if (_payments.isNotEmpty) ...[
              const SectionTitle(title: '我的充值记录'),
              AppCard(
                child: Column(
                  children: _payments.take(10).map((p) {
                    final status = asStr(p['status']);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asStr(p['packageName'] ??
                                      p['package'] ??
                                      '充值'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fmtDateTime(p['createdAt'] ??
                                      p['created_at']),
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '¥${asDouble(p['amount']).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Pill(
                            text: statusLabel(status),
                            color: statusColor(status),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
