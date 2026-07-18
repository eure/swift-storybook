# Implementation Notes - swift-storybook programmable page launch

- cwd: `/Users/hiroshi.kimura/.codex/worktrees/e0e7/swift-storybook`
- git root: `/Users/hiroshi.kimura/.codex/worktrees/e0e7/swift-storybook`
- branch: `codex/programmable-page-launch`
- started at: `2026-07-17 23:36:50 JST`
- note owner: Codex

## 設計判断

- 作業開始時点の未コミット差分を、新規の launch request、exact selector、direct navigation、diagnostics、accessibility marker、tests、README、Agent skill を含む一つの機能として保持して監査する。
- programmable launch は host app の起動境界で opt-in する。StorybookKit が未連携の host app を launch argument だけで差し替えられるとは扱わない。
- selector は表示名、`#fileID`、宣言行を段階的な修飾子として使い、文字列は UTF-8 バイト列で完全一致させる。
- `BookPageSelector.line` は文字列表現で保持し、既存 `BookPage` initializer が受け付ける任意の `FixedWidthInteger` を narrowing せず解決できるようにする。process argument は正の十進表現を任意精度で検証し、先頭の `+` と `0` を正規化する。
- 解決失敗時の request 表示は shell 風の一行文字列ではなく、実際に再利用できる process argument ごとの行として表示する。空名・ハイフン開始名には `--storybook-name=<name>` を再構成する。

## 逸脱点

- `Package.resolved` は一度 tracked baseline を復元したが、SwiftPM が dependency-free の現 manifest に対して自動削除した。機能実装が直接必要とする変更ではないものの、通常の package operation で再現するため既存削除を維持する。

## トレードオフ

- 名前だけの簡便な起動を許しつつ、重複時に先頭要素へフォールバックせず診断画面を出すことで、automation の決定性を優先する。
- 通常起動は既存の auto-open-last-page 挙動を維持し、明示的な programmable launch では履歴による上書きを無効化する方針を監査対象とする。

## 検証

- 開始時点で tracked diff 全体と、未追跡の Swift source、tests、`.agents/skills/swift-storybook-visual-check` の `SKILL.md` / `agents/openai.yaml` を確認済み。
- 開始時点の `git diff --check` は問題なし。
- Xcode (`windowtab7`, Storybook scheme, iPhone 17 Pro / iOS 27.0 Simulator) は test を discovery できている。初回の全 test 実行は Xcode 側で理由表示なく cancelled となったため、修正後に再実行する。
- Development の `SwiftUIDemoApp` を README と同じ host adapter に接続し、exact launch と accessibility hierarchy を repository 内で runtime 検証できるようにする。
- Development project は `StorybookKit` product dependency を持つ一方で package reference が欠落し、example が build 不能だった。project から repo root (`..`) への local package reference を追加し、product dependency を明示的にその package へ結びつける。
- Xcode の iPhone 17 Pro / iOS 27.0 Simulator で build-for-testing 成功後、Swift 6 の全 25 tests が成功した。
- iOS Simulator SDK / arm64 / iOS 16 target を明示し、`-swift-version 5` で `StorybookKit` target の compatibility build が成功した。既存 `BookPreview.swift` の localized interpolation deprecation warning 2 件のみ。
- `skill-creator/scripts/quick_validate.py` を temporary PyYAML dependency とともに実行し、`.agents/skills/swift-storybook-visual-check` は `Skill is valid!` となった。
- Development app の初回 build は既存 project 配線の `Missing package product 'StorybookKit'` で失敗したため、local package reference 追加後に再検証する。
- local package reference 追加後、Development app は iPhone 17 Pro / iOS 27.0 Simulator 向けに build 成功。workspace の `Package.resolved` は実際の remote dependency 2 件へ SwiftPM が更新した。
- final binary を `--storybook Circle --storybook-file SwiftUIDemoApp/Component.swift --storybook-line 24` で起動し、hierarchy で `storybook.page|6:Circle|30:SwiftUIDemoApp/Component.swift|24` を確認。Circle は clipping / overlap なく表示された。
- direct page から back navigation 後、catalog の History に `Circle / SwiftUIDemoApp/Component.swift:24` が記録されることを確認した。
- 履歴がある状態でも明示的な `--storybook` launch は catalog に留まり、last page を自動で開かないことを確認した。
- wrong-file request で `storybook.launch.failure`、exact-match failure reason、4 行の再利用可能な arguments、正しい candidate source が表示され、別 page は開かないことを確認した。

## 未解決の確認事項

- 機能上の未解決事項はなし。後続依頼で commit / push / draft PR 作成が明示承認された。version / changelog 方針、tag、release publication は引き続き対象外とする。
- root `Package.resolved` の削除と Development workspace lockfile の整理は、dependency-free package graph / 実際の example graph を SwiftPM が再生成した結果として含める。

## 最終サマリー

- exact selector / parser / diagnostics / navigation / accessibility marker の公開実装と tests、README、Development host adapter、Agent visual-check skill を一つの reviewable diff にまとめた。
- Swift 6 iOS Simulator tests、Swift 5 compatibility build、skill validation、exact launch / history / explicit catalog / diagnostic runtime checks を完了した。
- pairs-ios と release state は変更しない。明示承認に基づき、この branch の commit / push / draft PR 作成のみを行う。
