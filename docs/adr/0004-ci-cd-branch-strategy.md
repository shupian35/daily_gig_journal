---
status: Accepted
date: 2026-07-15
deciders: (grill-with-docs 流程用户)
---

# ADR-0004 · CI/CD 按分支分两套：main 正式版 / dev 预发布版

## Context

GitHub Actions 当前配置只看 main 分支：

- **ci.yaml**：`push` / `pull_request` 都只 watch main，dev 推送没有任何 check
- **cd.yaml**：`push: main + paths: pubspec.yaml` 触发；读 pubspec 版本、对比 tag、build Android/iOS artifact + 创建 GitHub Release

这个形态在 claude.md 的"开发分支策略"——dev 日常开发、main 只做发布——下，对应已经脱节：dev 推送没人验证，build 也只在 main 跑，需要一个折衷的"我刚 dev 推的代码能不能 build 出 apk 到我手机上"路径。

用户原话（2026-07-15）：
> "修改github工作流，实现dev分支推送之后 构建预发布版，main分支推送之后构建正式版"

## Decision

### 高层

- **CI（analyze + test）**：dev 与 main 都跑，`pull_request` 同步覆盖
- **CD（build + release）**：dev 与 main 都跑，但走的 job 路径不一样
  - main → 正式版：`v{version}` tag + `prerelease: false`
  - dev → 预发布版：`preview/v{version}+{build}-{short_sha}` tag + `prerelease: true`

### 触发

- `on.push.branches: [main, dev]`，`paths-ignore: ['**.md', '.claude/**', '.gitignore']`
- main 与 dev 共用同一个触发源；分派在 `plan` job 内分类
- 不再用 `paths: ['pubspec.yaml']` 这种硬筛选——分派移到内部 by branch

### 5 个 job

1. **plan**（ubuntu）—— 检出 pubspec.yaml 的 version + build_number，git short_sha，分支类型；用 git tag 探测决定 main 上的 `should_release`
2. **build-android**（ubuntu，受 `should_release` gate）—— APK + artifact upload
3. **build-ios**（macos，受 `should_release` gate）—— IPA + artifact upload
4. **release-main**（ubuntu，仅 main + new version）—— 创 `v{version}` tag + GitHub Release，`prerelease: false`
5. **release-preview**（ubuntu，仅 dev）—— 创 `preview/v{version}+{build}-{short_sha}` tag + GitHub Release，`prerelease: true`

### 为什么是 `preview/v...-sha` 不是 `v...-rc.N`

- 用 git 短 sha 命名，每个 dev push 都有独特 tag；不依赖人工 bump 版本号
- 用户原始描述是"预发布版"而不是"release candidate"——beta 风格而非 semver pre-release 风格
- 同一个 dev branch 上的多个 commit 形成连续可回溯的 preview 历史，而不是离散的人工候选

### 为什么 dev 也要 build iOS

- 用户选了 M（dev 也跑 iOS build）
- 理由：iOS native 改动（Info.plist、pod、plugin iOS 静态错误）如果不早验证，主仓合并后才暴露
- 代价：macOS-Latest runner 是 ×10 速率，免费 plan 用得更快
- 取舍记录在此 ADR，未来若发现成本不适合可改回 N

## Alternatives considered

### N · dev 仅 build Android + CI（曾被推荐过）

- 优点：每次 dev push 7~8 分钟，省钱省时
- 缺点：iOS 改动晚一拍发现
- 用户在 Q5 选了 M（双平台覆盖）

### O · dev 仅 CI 不 build

- 优点：dev push 最快（5 分钟）
- 缺点：preview artifact 只在 main 出，dev 上只能看 test/analyze
- 用户不考虑——"dev 推送之后构建预发布版"明示需要 build

### P · 不打 `prerelease: true` 旗标

- 优点：dev / main 在 Releases 页视觉对齐
- 缺点：用户被 GitHub 自动升级 / 通知机制误识为稳定
- 用户在 Q3 选了 Q（旗标），避免"以为下载正式版结果是中途构建"

### X · dev 不跑 CI

- 优点：CI 时间留给 main
- 缺点：broken code 直接产 preview，无验证门槛
- 用户在 Q4 选了 Y（双跑），避免 dev 失明

### δ · pubspec 变自动 bump 版本号

- 自动改版本号对单人项目危险、对多人仓库灾难
- 直接拒绝

### 多个 workflow 文件

- 拆 `cd-main.yaml` + `cd-preview.yaml` 各管一摊
- 用户原描述 "dev 分支... main 分支..."，对偶结构清晰
- **未选** —— 同一文件下用 `branch_type` 输出分派更简单；增 / 改 job 只看一处

## Consequences

### 正向

- dev push 后立刻能得到一个 APK / IPA + 一个 GitHub Pre-release，链上 click 就能下载到手机
- dev 上的 CI 把回归拦截在源头——push 就跑 analyze + test，5~8 分钟出结果
- preview 与正式版的命名空间不冲突：GitHub Releases 页 `v1.2.0` 与 `preview/v1.2.0+1-abc1234` 并存，按 `prerelease` 旗标直观区分
- main 上的行为兼容旧：tag `v{version}`、`make_latest: true`、`prerelease: false`，App Store 上架流程不变

### 代价

- macOS-Latest runner ×10 速率：dev push 各跑一次 Android + iOS = ~25 分钟/次
- GitHub Actions 免费 plan 每月 2000 分钟会被吃紧；个人项目勉强够用
- 若同时多人推 dev，queue 会堵
- yaml 结构变复杂——一个 `plan` job 输出 5 个字段，下游 5 个 job 拉取；review 时 YAML 阅读门槛 +1

### 反向影响

- `codemagic.yaml`（独立的 iOS 流水线）现在和 `cd.yaml` 之间没有协调；同一个 dev push 会跑两次 iOS build（GitHub Actions 一次 + Codemagic 不触发，因为 Codemagic 看的是 tag / manual trigger 还是 push？需要在文档里说清楚）

## 验证

- 在 dev 分支推一个测试 commit：`flutter test` + 预览版下载两条都跑通后关 issue
- 在 main 上 bump pubspec 一次（version `1.0.0+1` → `1.0.0+2`）：走 release-main，验证 tag `v1.0.0` 重新被创、Release 标记 `prerelease: false`

## Status

Accepted。已落地于：
- `.github/workflows/ci.yaml` —— `branches: [main, dev]`
- `.github/workflows/cd.yaml` —— 5 jobs（plan / build-android / build-ios / release-main / release-preview）
- `CONTEXT.md` —— 新增 "Preview Build" 词条 + "CI/CD 按分支分两套" 概念

## 相关 ADR

- **ADR-0001** · 集中 WorkEntry 变更语义（本仓库首个 ADR，引用本 ADR 的"前置"概念）
- **ADR-0003** · 历史备忘：Provider 失效级联（本仓库旧 AGENTS.md 规则备忘）