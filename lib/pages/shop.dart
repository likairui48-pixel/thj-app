import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/state.dart';
import '../core/ui.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _orders = const [];

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
      final j = await Api.i.shopOrders();
      if (!mounted) return;
      setState(() {
        _orders = asList(j['orders']);
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

  Future<void> _submit(Map<String, dynamic> o) async {
    final ref4 = TextEditingController(text: asStr(o['ref4']));
    final note = TextEditingController(text: asStr(o['note']));
    String method = asStr(o['payMethod'], 'wechat');
    String? proof;
    var busy = false;

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
                      '提交付款信息',
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
                '${asStr(o['orderNo'])} · ${asStr(o['productName'])} · 应付 ${asStr(o['amountText'])}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: '付款方式'),
                items: const [
                  DropdownMenuItem(value: 'wechat', child: Text('微信')),
                  DropdownMenuItem(value: 'alipay', child: Text('支付宝')),
                ],
                onChanged: (v) => setSt(() => method = v ?? 'wechat'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ref4,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: '付款单号后 4 位',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: '给站长的留言',
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
                        if (ref4.text.trim().isEmpty && proof == null) {
                          showToast(ctx, '请上传截图或填写单号后 4 位',
                              error: true);
                          return;
                        }
                        setSt(() => busy = true);
                        try {
                          await Api.i.shopSubmit(asInt(o['id']), {
                            'payMethod': method,
                            'ref4': ref4.text.trim(),
                            'note': note.text.trim(),
                            if (proof != null) 'proof': proof,
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                          if (mounted) {
                            showToast(context, '已提交，等站长核对到账');
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
                    : const Text('提交审核'),
              ),
            ],
          ),
        ),
      ),
    );
    ref4.dispose();
    note.dispose();
  }

  Future<void> _close(Map<String, dynamic> o) async {
    final ok = await showConfirm(
      context,
      title: '关闭订单',
      message: '关闭后该订单不再处理，库存会释放。',
      okText: '确认关闭',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.i.shopCloseOrder(asInt(o['id']));
      await _load();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '我的订单',
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
        isEmpty: !_loading && _orders.isEmpty,
        emptyText: '还没有订单',
        emptyIcon: Icons.receipt_long_outlined,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            itemCount: _orders.length,
            itemBuilder: (context, i) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _orderCard(context, _orders[i]),
                ),
          ),
        ),
      ),
    );
  }

  Widget _orderCard(BuildContext context, Map<String, dynamic> o) {
    final cs = Theme.of(context).colorScheme;
    final status = asStr(o['status']);
    final color = statusColor(status);
    final code = asStr(o['code']);
    final needsReview = asBool(o['needsReview']);
    final canSubmit = status == 'pending';
    final amount = asStr(o['amountText'], '${asDouble(o['amount']).toStringAsFixed(2)}');
    final orderNo = asStr(o['orderNo'], '#${asInt(o['id'])}');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asStr(o['productName'], '订单'),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$orderNo · ${fmtDateTime(o['createdAt'])}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥$amount',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Pill(
                    text: statusLabel(status),
                    color: color,
                  ),
                ],
              ),
            ],
          ),
          if (asStr(o['spec']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '规格：${asStr(o['spec'])}',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10.5,
              ),
            ),
          ],
          if (code.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      '卡密：$code',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      showToast(context, '卡密已复制');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                  ),
                ],
              ),
            ),
          ],
          if (asStr(o['trackingNo']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '快递：${asStr(o['trackingCompany'])} ${asStr(o['trackingNo'])}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
          if (asStr(o['adminNote']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '站长留言：${asStr(o['adminNote'])}',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 10.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (asBool(o['needsShip'])) const Pill(text: '需收货', color: AppColors.teal),
              if (asStr(o['payMethod']).isNotEmpty)
                Pill(
                  text: asStr(o['payMethod']) == 'wechat' ? '微信' : '支付宝',
                  color: cs.onSurfaceVariant,
                ),
              if (needsReview)
                const Pill(text: '已提交付款信息', color: AppColors.teal),
              if (asStr(o['provisionGroup']).isNotEmpty)
                Pill(text: '已开通 ${asStr(o['provisionGroup'])}', color: AppColors.brand),
            ],
          ),
          if (canSubmit) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (!needsReview)
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _submit(o),
                      child: const Text('提交付款信息'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submit(o),
                      child: const Text('补充 / 修改付款信息'),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _close(o),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ] else if (needsReview) ...[
            const SizedBox(height: 8),
            Text(
              '已提交付款信息，站长核对到账后立即开通 / 发货。',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class RedeemPage extends StatefulWidget {
  const RedeemPage({super.key});

  @override
  State<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends State<RedeemPage> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final j = await Api.i.shopRedeem(code);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('兑换成功'),
          content: Text(
            asStr(j['message'], '奖励已发放到你的账号。'),
            style: const TextStyle(height: 1.55),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好的'),
            ),
          ],
        ),
      );
      _code.clear();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppPage(
      title: '兑换码',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入卡密 / 活动兑换码',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '兑换前请先绑定游戏账号。会员类奖励会直接开通到绑定 ID。',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '兑换码',
                    hintText: '例如 THJ-XXXX-XXXX',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _redeem,
                  icon: _busy
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.redeem_rounded, size: 18),
                  label: const Text('立即兑换'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
