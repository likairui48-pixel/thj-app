import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/img.dart';
import '../core/state.dart';
import '../core/ui.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    super.key,
    this.targetType = 'player',
    this.targetId,
    this.targetLabel,
    this.detail = '',
  });

  final String targetType;
  final String? targetId;
  final String? targetLabel;
  final String detail;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _state = AppState.i;
  final _player = TextEditingController();
  final _detail = TextEditingController();
  List<String> _reasons = const [];
  List<String> _online = const [];
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _against = const [];
  String _reason = '';
  DateTime? _occurredAt;
  List<String> _images = <String>[];
  bool _loading = true;
  bool _busy = false;
  String? _err;

  bool get _isPlayer => widget.targetType == 'player';

  @override
  void initState() {
    super.initState();
    _detail.text = widget.detail;
    if (_isPlayer && widget.targetId != null) {
      _player.text = widget.targetId!;
    }
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final results = await Future.wait([
        Api.i.reportReasons(),
        Api.i.status(),
        if (_state.isLoggedIn) Api.i.myReports() else Future.value(<String, dynamic>{}),
      ]);
      if (!mounted) return;
      final reasons = asStrList(results[0]['reasons']);
      final status = results[1];
      final mine = results.length > 2 ? results[2] : <String, dynamic>{};
      setState(() {
        _reasons = reasons;
        _reason = reasons.isEmpty ? '' : reasons.first;
        _online = asStrList(status['names']);
        _reports = asList(mine['reports']);
        _against = asList(mine['against']);
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

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    final target = _isPlayer
        ? _player.text.trim().replaceFirst(RegExp(r'^@'), '')
        : (widget.targetId ?? '');
    if (_isPlayer && !RegExp(r'^[A-Za-z0-9_]{2,16}$').hasMatch(target)) {
      showToast(context, '请输入正确的玩家游戏名（2-16 位字母/数字/下划线）',
          error: true);
      return;
    }
    if (target.isEmpty) {
      showToast(context, '举报对象无效', error: true);
      return;
    }
    if (_reason.isEmpty) {
      showToast(context, '请选择举报理由', error: true);
      return;
    }
    if (!_state.isLoggedIn) {
      showToast(context, '请先登录再举报', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final urls = <String>[];
      for (final d in _images) {
        if (d.startsWith('data:')) {
          final up = await Api.i.uploadImage(d, kind: 'forum');
          final url = asStr(up['url']);
          if (url.isNotEmpty) urls.add(url);
        } else {
          urls.add(d);
        }
      }
      final j = await Api.i.reportCreate({
        'targetType': widget.targetType,
        'targetId': target,
        'reason': _reason,
        'detail': _detail.text.trim(),
        if (urls.isNotEmpty) 'images': urls,
        if (_occurredAt != null)
          'occurredAt': _occurredAt!.millisecondsSinceEpoch,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('举报已提交'),
          content: Text(
            '编号 #${asInt(j['id'])}，已附带 ${asInt(j['images'])} 张截图。\n'
            '处理结果会通过站内通知告知你。',
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好的'),
            ),
          ],
        ),
      );
      _detail.clear();
      setState(() => _images = <String>[]);
      await _load();
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
      title: '举报中心',
      child: AsyncView(
        loading: _loading,
        error: _err,
        onRetry: _load,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isPlayer) ...[
                      Text(
                        '举报对象',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.targetLabel ??
                            '${widget.targetType} #${widget.targetId}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      TextField(
                        controller: _player,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: '举报对象（玩家游戏 ID）',
                          hintText: '例如 zaoren',
                          prefixIcon: Icon(Icons.person_search_rounded),
                        ),
                      ),
                      if (_online.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: _online.take(12).map((n) {
                            return GestureDetector(
                              onTap: () => setState(() => _player.text = n),
                              child: Pill(text: n, color: AppColors.teal),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: _reasons.contains(_reason) ? _reason : null,
                      decoration: const InputDecoration(
                        labelText: '举报理由',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: _reasons
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                r,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _reason = v ?? ''),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '事发时间（选填）',
                          prefixIcon: Icon(Icons.schedule_rounded),
                        ),
                        child: Text(
                          _occurredAt == null
                              ? '不填则由系统按当前时间取证'
                              : '${fmtDate(_occurredAt!.millisecondsSinceEpoch)} '
                                  '${fmtTime(_occurredAt!.millisecondsSinceEpoch)}',
                          style: TextStyle(
                            color: _occurredAt == null
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _detail,
                      maxLength: 500,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '补充说明',
                        hintText: '请描述具体情况（在哪、做了什么、有何影响）',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '截图证据（最多 3 张）',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_images.length}/3',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (var i = 0; i < _images.length; i++)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnyImage(url: _images[i], width: 76, height: 76),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    final next = List<String>.from(_images)
                                      ..removeAt(i);
                                    setState(() => _images = next);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: cs.outlineVariant),
                                    ),
                                    child: Icon(Icons.close_rounded,
                                        size: 12, color: cs.onSurface),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_images.length < 3)
                          GestureDetector(
                            onTap: () async {
                              final picked = await ImgPicker.multi(
                                  limit: 3 - _images.length);
                              if (picked.isNotEmpty) {
                                setState(() => _images = [
                                      ..._images,
                                      ...picked,
                                    ].take(3).toList());
                              }
                            },
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: cs.outlineVariant),
                              ),
                              child: Icon(Icons.add_photo_alternate_outlined,
                                  color: cs.onSurfaceVariant, size: 22),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '系统会自动附带当时的服务器日志与站内发言取证；AI 初审仅作参考，最终由管理员裁定。',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.flag_rounded, size: 18),
                      label: const Text('提交举报'),
                    ),
                  ],
                ),
              ),
              if (_reports.isNotEmpty) ...[
                const SectionTitle(title: '我的举报记录'),
                ..._reports.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _reportCard(context, r, against: false),
                  ),
                ),
              ],
              if (_against.isNotEmpty) ...[
                const SectionTitle(title: '我收到的处理'),
                ..._against.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _reportCard(context, r, against: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, Map<String, dynamic> r,
      {required bool against}) {
    final cs = Theme.of(context).colorScheme;
    final status = asStr(r['status']);
    final color = status == 'resolved'
        ? AppColors.brand
        : status == 'rejected'
            ? Colors.grey
            : AppColors.warning;
    final label = status == 'resolved'
        ? '已处理'
        : status == 'rejected'
            ? '未通过'
            : '待处理';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${asInt(r['id'])}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  asStr(r['targetLabel'], '举报'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Pill(text: label, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '理由：${asStr(r['reason'], '—')}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10.5),
          ),
          if (asStr(r['handleNote']).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '处理结果：${asStr(r['handleNote'])}',
              style: TextStyle(color: cs.onSurface, fontSize: 11),
            ),
          ],
          const SizedBox(height: 3),
          Text(
            '${against ? '收到' : '提交'}于 ${fmtAgo(r['createdAt'])}'
            '${asInt(r['handledAt']) > 0 ? ' · 处理于 ${fmtAgo(r['handledAt'])}' : ''}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}
