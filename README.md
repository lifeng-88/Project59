# Hub — Lumina Focus iOS

基于 `stitch_smart_utility_hub` 设计稿实现的 SwiftUI iOS 应用，采用 **Lumina Focus** 设计系统（宁静蓝主色、柔和阴影与 12px 圆角卡片）。支持**浅色 / 深色 / 跟随系统**主题。

## 打开项目

```bash
open Hub.xcodeproj
```

在 Xcode 中选择模拟器或真机，运行 **Hub** target（iOS 17+）。

## 功能对照

| 设计稿 | iOS 实现 |
|--------|----------|
| `today_2/code.html` | `TodayView` — 搜索、侧栏、删除任务、持久化 |
| `calendar/code.html` | `CalendarView` — 日期联动、今天按钮、空档快捷操作 |
| `insights/code.html` | `InsightsView` — 动态统计、专注目标进度、下拉刷新 |
| `settings/code.html` | `SettingsView` — 主题、语言、云同步开关、头像、专注目标 |
| `quick_add/code.html` | `QuickAddSheet` — 日期/优先级/提醒/分类 |
| `focus_mode_settings` | `FocusModeSettingsView` — 番茄钟、环境音、开始专注 |
| `lumina_focus/DESIGN.md` | `Design/LuminaTheme.swift` + `L10n.swift` |

数据通过 `UserDefaults`（`PersistedAppState`）本地持久化；头像保存在 Application Support。

## 核心能力

- **任务**：CRUD、搜索、提醒通知、JSON/CSV 导入导出
- **专注**：番茄钟 + 短休/长休、后台阶段通知、会话恢复、连续天数统计
- **同步**：iCloud Drive 备份（需 Xcode 开启 iCloud 能力与 `Hub.entitlements`）
- **本地化**：设置内切换中/英（`L10n` + `locale` 环境，主要界面已接入）

## 项目结构

```
Hub/
├── HubApp.swift
├── ContentView.swift
├── Hub.entitlements
├── Design/          # 颜色、字体、L10n
├── Models/          # 任务与全局状态
├── Services/        # 通知、导出、iCloud、专注会话、头像存储
├── Components/      # 顶栏、底栏、任务行、头像等
└── Views/           # 各 Tab 与子页面
```

## 设计要点

- **主色** 浅色 `#005DA7` / 深色 `#A4C9FF`
- **页面边距** 24pt，卡片圆角 12–16pt
- **中文界面** 为默认；可在设置中切换 English
