# SKAdNetworkItems 来源记录

Info.plist 中的 52 个 SKAdNetworkIdentifier 的来源与抓取日期，便于日后增量更新。

| 来源 | 数量 | 抓取日期 | 说明 |
|------|------|----------|------|
| Google 官方第三方买方列表 | 50 | 2026-06-11 | https://developers.google.com/admob/ios/3p-skadnetworks（含 AdMob 主 ID `cstr6suwn9`） |
| Goodlook 产线 Info.plist | +1 | 2026-06-11 | `pwa73g5rt2`（与本项目同一套 HKAdvertising/CN 广告栈，产线验证） |
| 穿山甲/Pangle 官方文档 | +1 | 2026-06-11 | `238da6jt44`（Pangle 主 SKAdNetwork ID） |

## 更新方式

1. 重新抓取 Google 列表页，与现有列表求并集；
2. 检查穿山甲/优量汇/快手/百度接入文档是否新增 SKAdNetworkIdentifier；
3. 用 PlistBuddy 增量追加，全部小写、去重；
4. `plutil -lint pixelmatch/Info.plist` 校验。

注：优量汇/快手/百度截至抓取日未在公开文档提供独立 SKAdNetwork ID（国内归因主要走自有方案），
Goodlook 产线同款配置运行正常；若后续文档新增，按上述流程合并。
