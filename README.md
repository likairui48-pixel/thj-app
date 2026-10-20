# 同禾境 App（全新版）

> 服务器随身仪表盘 · 社区消息中心 · 活动通行证

这不是旧客户端的换皮，也不是 WebView 套壳。所有页面都是 Flutter 原生实现，
数据全部来自同禾境站点 `https://thjmc.duckdns.org:8443`。

---

## 一、这一版有什么

### 首页
- 实时在线人数 / 上限 / 版本 / 延迟
- 在线玩家列表，假人自动折叠（可展开）
- 赛季倒计时、我的段位、全服公告
- 活动 banner + 倒计时 + 快捷入口
- 最新帖子、进服地址、玩家群

### 社区
- 7 个版块、最新 / 热门、分页
- 帖子详情、发帖、回复、点赞、收藏
- 编辑 / 删除自己的帖子与回复
- 最多 9 图，上传前压缩
- 举报主题 / 回复
- 全局搜索：用户 / 玩家 / 帖子

### 消息
- 通知中心：私聊、@、好友、举报、会员、段位、系统
- 世界频道：与游戏内聊天互通
- 私信：图片、正在输入、已读、撤回、置顶、免打扰
- 好友申请：同意 / 拒绝
- 长按消息：复制、撤回、举报、看主页

### 排行
- 段位榜 / 时长榜 / 等级榜
- 段位筛选、我的位置、假人折叠
- 段位分布图、百分位、平均得分构成
- 玩家名片：数据、段位构成、名片图分享

### 社交
- 好友：搜索、申请、同意、备注、分组、拉黑、删除
- 关注 / 粉丝
- 个人主页：背景、签名、标签、动态、帖子
- 留言板：@提及、回复、删除

### 活动
- 活动中心：签到、连签奖励、签到榜、日程
- 相册：全服合照、全屏查看
- 商城：商品、库存、限购、规格、虚拟/实体、地址
- 订单：收款码、付款凭证、提交审核、卡密、物流、关闭
- 兑换码
- SMP：报名 / 退赛 / 位置公开 / 实时地图 / 击杀流水 / 名单 / 规则

### 我的
- 资料编辑：头像、主页背景、签名、标签
- 绑定 / 解绑 Minecraft 账号（6 位绑定码）
- 会员：档位、权益、收款码、充值记录
- 隐私设置、游戏内提醒设置
- 主题、通知模式、缓存、检查更新、退出

### 平台能力
- 深浅色 / 跟随系统
- 离线缓存：首页、榜单、帖子
- 深链：`/chat?u=1`、`/u/name`、`/p/name`、`/forum/thread/1`、`/festival`、`/smp`、`/report`
- 后台长连接 + 静默前台服务（可选）
- 远程配置：底部栏、功能开关、公告、最低版本
- 在线更新：读 `/api/app/version`

---

## 二、技术栈

| 项 | 值 |
|---|---|
| Flutter | 3.24.5 stable |
| Dart | 3.5.x |
| Android | minSdk 26 / targetSdk 34 / compileSdk 34 |
| 包名 | `cn.mcfuns.thj.next` |
| 网络 | `http` + 自写 Engine.IO v4 WebSocket |
| 存储 | `shared_preferences`（会话 Cookie / 设置 / 缓存） |
| 通知 | `flutter_local_notifications` + 原生前台服务 |
| 选图 | `image_picker`（自动压缩） |
| 分享 | `share_plus` |
| 构建 | GitHub Actions / 本机 Flutter |

---

## 三、本地开发

```bash
flutter pub get
flutter analyze
flutter run
```

> 需要 Flutter 3.24.5、Java 17、Android SDK 34。

### 出包

```bash
flutter build apk --release --split-per-abi
```

产物：
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

当前 `release` 使用 debug 签名，方便直接安装测试。正式发版前请在
`android/app/build.gradle` 里配置自己的 keystore，并妥善保管；签名变了以后
旧版本无法覆盖安装，需要先卸载。

---

## 四、站点更新接口（留好的口子）

App 启动后会读两个接口，**不需要发版就能改入口和公告**。

### 1. 版本清单 `GET /api/app/version`

```json
{
  "ok": true,
  "latest": {
    "version": "1.1.0",
    "versionCode": 2,
    "url": "https://thjmc.duckdns.org:8443/static/app/thj-app-arm64.apk",
    "notes": ["新增举报中心", "修复聊天断线"],
    "force": false,
    "size": 23456789,
    "minVersionCode": 1
  }
}
```

- `versionCode` 必须递增，App 只靠它判断新旧。
- `force: true` + `hasNewer` 会弹不可取消的更新框。
- 接口失败时静默降级，不影响使用。

### 2. 远程配置 `GET /api/app/config`

```json
{
  "ok": true,
  "tabs": [
    {"id": "home", "label": "首页", "icon": "home", "enabled": true},
    {"id": "community", "label": "社区", "icon": "community", "enabled": true},
    {"id": "messages", "label": "消息", "icon": "message", "enabled": true, "badge": true},
    {"id": "rank", "label": "排行", "icon": "rank", "enabled": true},
    {"id": "me", "label": "我的", "icon": "person", "enabled": true}
  ],
  "features": {
    "chat": true,
    "community": true,
    "rank": true,
    "events": true,
    "shop": true,
    "smp": true,
    "report": true,
    "guestbook": true,
    "search": true
  },
  "announcement": {
    "id": "2026-10-01-notice",
    "title": "国庆活动开启",
    "body": "签到、商城、SMP 已上线。",
    "link": "/festival"
  },
  "minVersionCode": 1,
  "forceUpdate": false
}
```

- `tabs` 为空时使用内置 5 个 Tab。
- 未知 Tab ID 会显示“该入口需要更新 App”，不会崩。
- `announcement.id` 用来去重，同一个 id 只弹一次。
- `features` 目前作为功能开关保留，页面可按需接入。

### 3. 活动通用化

活动页只认 `/api/festival` 返回的 `event / timeline / checkin / products`，
不把“国庆”写死在 App 里。下一场活动只要后台换数据，App 直接复用。

---

## 五、已知边界

- **推送**：没有接 FCM / 厂商推送。App 进程活着时靠长连接秒收；
  被系统杀掉后只能等下次打开或后台轮询。设置里提供三档接收方式，并把代价写清楚。
- **支付**：沿用站点的“收款码 + 人工核对”。如果以后上 Google Play，
  数字权益需要改用 Play Billing，或把购买引导到官网。
- **管理后台**：不搬进 App，仍在浏览器打开 `/admin`。
- **SMP 地图**：依赖活动服日志。日志路径不对时页面会显示“地图维护中”，不会白屏。

---

## 六、目录

```
lib/
  app.dart              应用入口 / 路由 / 公告 / 强制更新
  main.dart
  core/
    api.dart            所有站点接口 + 容错解析
    state.dart          全局状态 / 设置 / 未读 / 远程配置
    realtime.dart       Socket.IO（Engine.IO v4）长连接
    notify.dart         本地通知
    ui.dart             主题 / 卡片 / 通用组件 / 格式化
    img.dart            选图 + data URL
    cache.dart          离线 JSON 缓存
    deeplink.dart       深链
    meta.dart           版本 / 地址 / 包名
    nav.dart            全局导航
    update_ui.dart      更新弹层
  pages/                首页、社区、消息、排行、我的、活动、SMP…
android/                原生壳 / 前台服务 / 深链
.github/workflows/      GitHub Actions 出包
server/                 更新接口示例 JSON
```

---

## 七、License

私有项目，未授权请勿分发。
