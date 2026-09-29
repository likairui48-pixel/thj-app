# 同禾境 · 安卓客户端（thj-app）

> 液态玻璃质感 · 黑白双主题 · 椭圆形浮动底栏 · 消息提示 · 在线更新接口已预留

这是「同禾境」（Minecraft 社区平台）的官方安卓客户端。它不是第二套系统，
**所有数据都来自网站接口**，站点更新时 App 会自动跟着变。

---

## 一、这一版做了什么

| 模块 | 说明 |
|---|---|
| 首页 | 实时在线人数、服务器版本、赛季剩余天数、在线玩家列表（含假人折叠开关） |
| 排行榜 | 段位筛选（S/A/B/C）、服务端分页续载、赛季卡、「我在这」一键定位 |
| 玩家名片 | 等级/时长/挖矿/距离/击杀等数据 + 段位分构成条形图 + 网页完整主页 |
| 社区 | 内嵌网页容器（与 App 共享登录态，一次登录全站通用） |
| 消息 | 通知/私信/好友申请三类未读汇总 + 分类列表 + **系统通知提醒**（含通知测试） |
| 我的 | 登录/注册（原生表单）、我的段位、私信/好友/充值/活动入口、检查更新、加群 |
| 设置 | 黑白双主题切换、减弱动画、服务器地址切换（含故障转移与自定义） |

### 视觉
- **液态玻璃**：`BackdropFilter` 模糊 + 半透明染色 + 1px 亮边 + 顶部内高光 + 按下缩放
- **椭圆形底栏**：浮动胶囊（圆角 = 高度/2），选中项有滑动高光指示器 + 未读角标
- **黑白双主题**：夜=墨黑、昼=素白，强调色只用站点品牌绿 `#2E9E63`；支持「跟随系统」

### 消息提示
- App 运行时每 45 秒轮询未读数；有新消息 → 弹系统通知 + 底栏小红点
- Android 13+ 首次进入会申请通知权限；设置页可手动申请 + 发测试通知
- 点通知直接跳到「消息」页

### 已预留的「后续更新接口」
1. **在线更新**：读站点 `GET /api/app/version`
   ```json
   { "ok": true, "latest": {
       "version": "1.1.0", "versionCode": 2,
       "url": "https://…/thj-app-arm64.apk",
       "notes": ["新增聊天室"], "force": false, "size": 12345678 } }
   ```
   接口不存在时静默降级（不会报错、不影响使用）。`lib/core/update.dart`
2. **远程配置**：读 `GET /api/app/config`，可动态改底部栏（增/删/改名 Tab）与功能开关
   ```json
   { "ok": true, "tabs": [{"id":"shop","label":"商城","icon":"gift"}],
     "features": {"chat": true} }
   ```
   `lib/app/config.dart` 的 `FeatureRegistry`
3. **图标名映射**：远程只能传字符串（`home/rank/community/message/person/search/settings/gift/more`），
   由 `iconFor()` 映射到 IconData —— 避免远程下发非法图标导致崩溃

---

## 二、技术栈（全部钉死版本，防止 CI 漂移）

| 项 | 版本 |
|---|---|
| Flutter | 3.24.5（stable） |
| Java | 17 |
| AGP / Gradle | 8.3.2 / 8.7 |
| minSdk / targetSdk | 26（Android 8.0）/ 34 |
| 包名 | `cn.mcfuns.thj` |
| 依赖 | http 1.2.2 · shared_preferences 2.3.3 · flutter_local_notifications 17.2.3 · webview_flutter 4.10.0 · url_launcher 6.3.1 |

---

## 三、开发与出包

**本地（Aether 沙箱）不能编译**（Java 被 PaX 拦截），走 GitHub Actions：

```bash
sh push-thj.sh          # 建仓库 + commit + push（带重试）+ 触发 CI
```

CI 产出 4 个 APK：`thj-app-arm64.apk`（推荐）、`-arm32`、`-x86_64`、`-universal`（保底）。

---

## 四、服务器地址

| 入口 | 地址 | 用途 |
|---|---|---|
| 主 | `https://thjmc.duckdns.org:8443` | 正式（Cloudflare 隧道/新域名就绪后替换） |
| 保底 | `http://211.101.233.180:8080` | 直连（明文，仅对该 IP 放行 cleartext） |

请求失败会自动切换候选地址，成功后记住；也可在「设置 → 服务器地址」手动指定。

---

## 五、站点侧待补（可选，做了就能在线更新）

`server.js` 增加两个只读接口即可，App 无需改代码：

```js
app.get('/api/app/version', (req, res) => ok(res, { latest: {
  version: '1.1.0', versionCode: 2,
  url: 'https://…/thj-app-arm64.apk', notes: ['…'], force: false
}}));
app.get('/api/app/config', (req, res) => ok(res, {})); // 空对象也能跑
```
