# 站点侧更新接口

App 已经内置读取逻辑，站点只需要返回 JSON。

## 版本清单

`GET /api/app/version` → `app-version.example.json`

注意：
- `versionCode` 必须递增；
- `url` 要能被手机直接下载；
- `force: true` 会让旧版本无法继续使用；
- `size` 可选，用于显示安装包大小。

## 远程配置

`GET /api/app/config` → `app-config.example.json`

- `tabs`：底部栏。为空时用 App 内置的 5 个 Tab。
- `features`：功能开关，后续页面可按需接入。
- `announcement`：启动公告，同一个 `id` 只弹一次。
- `minVersionCode` / `forceUpdate`：最低版本控制。

## 建议

不要让配置接口依赖登录态，也不要在里面放大段 HTML。
App 只把它当“运营开关”，真正的业务数据仍然走现有 `/api/*`。
