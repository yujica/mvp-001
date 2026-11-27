# mvp-001 — PropertyScore

> **Status: 🚧 開発中 → 公開準備中**

収益不動産の投資判断をAIでサポートするスコアリングツール。
楽待・健美家などから物件情報をコピペするだけで、6カテゴリ100点満点で即スコアリング。

---

## これは何か

不動産投資家が物件を見るとき、毎回同じ判断軸で評価するのは手間がかかる。
PropertyScore は自分の投資基準をそのまま数値化して、物件の良し悪しを素早く判断できるツール。

実際に自分が使うために作り、めっちゃ使っている。

## デモ / URL

（公開後に追記）

## 機能

- 📊 **6カテゴリスコアリング**: 立地・建物性能・CAPEX・家賃/収支・金利耐性・積算
- 🎯 **即除外判定**: 駅徒歩、専有面積、借地権などで自動フィルタ
- ⚙️ **条件カスタマイズ**: 自分の投資基準に合わせて配点調整可能
- 📈 **レーダーチャート**: 物件のバランスを視覚的に把握
- 🤖 **AI情報抽出**: テキストをそのまま貼るだけで物件情報を自動抽出（Gemini API）

## セットアップ

### iOS 版（このリポジトリ）

`iOS/PropertyScore.xcodeproj` を Xcode 26 以降で開き、`PropertyScore` スキームを iOS 26 以降で実行します。掲載 URL または掲載文を入力し、読み取った項目を確認・修正してから採点します。URL は公開 HTTPS ページから HTML またはテキストを取得します。ログインが必要なページ、JavaScript でのみ表示されるページ、取得を制限するサイトでは掲載文の貼り付けか手入力を利用してください。

AI 読み取りには端末上の Apple Foundation Models のみを使用します。対応端末で Apple Intelligence が有効かつ準備済みである必要があります。AI が使えない端末でも手入力と採点が使えます。物件を取得するときは入力した URL の配信元にアクセスしますが、掲載文や入力した条件をクラウド LLM に送ることはありません。分析条件は端末内に保存されます。

README のカテゴリをもとにした iOS 版の初期配点は、立地 20、建物性能 15、CAPEX 15、家賃・収支 20、金利耐性 15、積算 15 です。順に、駅徒歩・築年数・修繕費/価格・年間手取り/価格・想定金利での返済余力・積算評価額/価格を使います。重みや除外条件、ローン試算の前提は変更できます。不明な項目は加点せず、結果を暫定表示します。これは参考試算で、物件の価値や投資判断を保証するものではありません。

```bash
xcodebuild -project iOS/PropertyScore.xcodeproj -scheme PropertyScore \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

UI テストは読み取りのスタブと手入力フォールバックを使うため、Apple Intelligence や外部サイトは不要です。

TestFlight へのアップロードには、App Store Connect のアプリレコード、配布に必要な権限のあるチーム API キー、Apple Developer のチーム ID が必要です。環境変数 `ASC_KEY_ID`、`ASC_ISSUER_ID`、`ASC_KEY_P8`（パスではなくキーの内容）、`APPLE_TEAM_ID` を設定し、`bash iOS/scripts/upload-testflight.sh` を実行します。アプリレコードと `com.yujica.propertyscore` が一致しない場合は `APP_BUNDLE_IDENTIFIER` も指定してください。手元の Xcode でプロビジョニングする場合は `iOS/Signing.xcconfig` でチームとバンドル ID を設定できます。アップロード後、App Store Connect でビルドの処理を待ち、テスターを招待します。

### Web 版のメモ（実装ファイルはこのリポジトリに含まれていません）

```bash
npm install
npm run dev
```

Gemini APIキーは [Google AI Studio](https://aistudio.google.com/app/apikey) で無料取得。
アプリ内のAPIキー設定から入力。

## 技術スタック

| 項目 | 内容 |
|------|------|
| フロントエンド | React + Vite + Tailwind CSS |
| AI | Gemini API |
| デプロイ先 | Vercel |

## ロードマップ

- [x] スコアリングロジック実装
- [x] AI情報抽出（Gemini API）
- [x] レーダーチャート
- [x] 即除外判定
- [ ] Vercelデプロイ・公開URL
- [ ] waitlist / フィードバック導線
- [ ] 課金機能（買い切り or サブスク）
- [ ] Xでの初速検証

## 💡 MVP候補メモ（確定済み）

- いちごろブランドで出す個人プロダクト第1号
- 不動産投資家向け・自分が実際に使っているツール
- Xフォロワーに初速検証
- waitlist / フィードバック取得
