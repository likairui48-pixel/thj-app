import 'dart:async';

import 'package:flutter/material.dart';

/// 全局导航总线：页面只依赖它，不直接依赖其它页面，避免循环 import。
class Nav {
  Nav._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  static final StreamController<String> _tabs = StreamController<String>.broadcast();
  static Stream<String> get tabs => _tabs.stream;

  /// App 启动时注入：把 /path 解析成具体页面
  static void Function(String path)? resolver;

  static void tab(String id) => _tabs.add(id);

  static Future<T?> push<T>(Widget page) async {
    final state = key.currentState;
    if (state == null) return null;
    return state.push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }

  static void pop<T>([T? result]) {
    final state = key.currentState;
    if (state != null && state.canPop()) state.pop<T>(result);
  }

  /// 站内路径：/chat?u=1、/u/name、/forum/thread/1、/festival …
  static void to(String path) {
    if (path.trim().isEmpty) return;
    resolver?.call(path.trim());
  }

  /// 通知 payload：messages / link:/xxx
  static void payload(String payload) {
    if (payload == 'messages') {
      tab('messages');
      return;
    }
    if (payload.startsWith('link:')) {
      to(payload.substring(5));
      return;
    }
    to(payload);
  }
}
