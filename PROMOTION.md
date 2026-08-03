# Launch copy

This file keeps the first public launch drafts in one place. The links point to the hosted client and the source repository.

## X

我做了一个很小的工具，专门盯住 @thsottiaux 的公开动态。

Tibo 发了和 Codex usage limit reset 有关的帖子，浏览器就会提醒你。它只接受 Tibo 本人发布的 X 帖子，不读取 X 或 OpenAI 登录信息，也不读取用户的 Codex 使用量。

网页体验：https://chloride233.github.io/tibo-reset-watch/
源码：https://github.com/Chloride233/tibo-reset-watch

现在还是 beta：公开数据源大约每 15 分钟更新，页面会每 2 分钟检查一次。欢迎试用，也欢迎指出误报或漏报。

## V2EX

### 标题

做了一个只追踪 Tibo 本人动态的 Codex reset 提醒工具

### 正文

我想知道 Tibo 什么时候发了 Codex usage limit reset 相关的动态，所以做了一个很小的提醒工具。

它现在有网页/PWA、macOS 菜单栏版本和 Windows Electron 目标：

- 只接受 @thsottiaux 本人发布的 X 帖子。
- 普通动态会展示，但只有可能重置或已经确认重置的内容会进入提醒列表。
- 第一次打开会先建立基线，不会把旧帖子全部当成新提醒。
- 不需要 X、OpenAI 或 Telegram 登录，也不读取用户的 Codex 使用量。
- 提醒偏好和去重记录保存在本地。

网页：https://chloride233.github.io/tibo-reset-watch/
源码：https://github.com/Chloride233/tibo-reset-watch

目前公开源大约每 15 分钟更新，所以它不是实时 X 流。现在主要想找几位真实用户试用，看看提醒是否足够准确。

## 小众软件

**软件名称**：Tibo Reset Watch

**应用平台**：Web / PWA、macOS、Windows

**推荐类型**：开发者自荐

**是否收费**：免费，MIT License

**一句简介**：只追踪 @thsottiaux 本人公开动态，发现 Codex reset 相关帖子时提醒你。

**应用简介**：

这是一个解决单一问题的小工具：当 Tibo 发布和 Codex usage limit reset 有关的公开帖子时，给你一个浏览器或桌面通知。

工具只接受 @thsottiaux 本人发布的 X 帖子，回复和引用帖也会按作者校验。它不要求 X、OpenAI 或 Telegram 登录，不读取用户的 Codex 使用量，提醒偏好和去重记录只保存在本地。

网页体验：https://chloride233.github.io/tibo-reset-watch/

项目地址：https://github.com/Chloride233/tibo-reset-watch

当前公开数据源大约每 15 分钟同步一次，适合想少刷时间线、只在意 reset 动态的人。
