# Sketch & Guess

絵しりとり伝言ゲーム - お題を見て絵を描く、絵を見て答える、みんなで楽しむリアルタイムゲーム

## 概要

Sketch & Guessは、友達と一緒に楽しめるオンライン絵しりとり伝言ゲームです。各プレイヤーがスケッチブックを持ち、順番に絵を描いたり、答えを書いたりしながら、お題が正しく伝わるかを競います。

### ゲームの流れ

1. **ルーム作成**: 4〜8人の参加人数を設定してゲームルームを作成
2. **参加者待機**: QRコードやURLで友達を招待
3. **お題選択**: ダイスを振って各プレイヤーのお題を決定
4. **ゲーム開始**:
   - お題を見て絵を描く（60秒）
   - 前の人の絵を見て答えを書く
   - スケッチブックを回して全員がプレイ
5. **結果発表**: お題と最終回答を比較して、正しく伝わったかチェック
6. **アーカイブ**: 完成したスケッチブックは後から振り返ることができます

## 主な機能

### ゲーム機能
- **リアルタイムプレイ**: Turbo Streamsを使った同期プレイ
- **お絵描き機能**: HTML5 Canvasで直接絵が描ける
- **タイマー機能**: 60秒の制限時間付き
- **マルチラウンド**: 複数ラウンドのプレイに対応(予定)
- **FREE プロンプト**: ランダムで自由にお題を入力できる特別なカード

### アーカイブ機能
- **スケッチブック一覧**: 完成したゲームのスケッチブックを表示
- **詳細表示**: 全ページをグリッド表示で振り返り

### デザイン
- **統一されたUI**: カラフルでボードゲーム風のデザイン
- **レスポンシブ対応**: スマホ、タブレット、PCに対応
- **楽しいフォント**: Comic Sans MSを使用したフレンドリーなUI

## 技術スタック

### フレームワーク & ライブラリ
- **Ruby on Rails 8.1**
- **Ruby 3.4.7**
- **Turbo (Hotwire)**: リアルタイム通信
- **Solid Cache**: キャッシュストレージ
- **Solid Cable**: WebSocketアダプター
- **Active Storage**: 画像アップロード

### フロントエンド
- **HTML5 Canvas**: お絵描き機能
- **JavaScript (ES6)**: インタラクティブ機能
- **CSS3**: アニメーションとレスポンシブデザイン

## セットアップ

### 必要なもの
- Ruby 3.x
- Rails 8.1
- SQLite3（開発環境）
- Node.js & Yarn

### インストール

```bash
# リポジトリをクローン
git clone https://github.com/yourusername/sketch-and-guess.git
cd sketch-and-guess

# 依存関係をインストール
bundle install
yarn install

# データベースをセットアップ
rails db:create
rails db:migrate

# お題データを投入
rails db:seed

# サーバーを起動
thrust bin/rails server
```

ブラウザで `http://localhost:3000` にアクセス

## 使い方

### ゲームを始める

1. TOPページで「ゲームを始める」をクリック
2. 参加人数（4〜8人）を選択
3. 表示されたQRコードやURLを友達に共有
4. 全員が集まったら自動的にお題選択画面へ
5. ダイスを振ってお題を決定
6. ゲーム開始！

### お絵描きのコツ

- **ペンツール**: 線を描く
- **消しゴム**: 間違えた部分を消す
- **クリア**: 全部消してやり直す
- **色の選択**: 黒と赤から選べます
- **時間制限**: 60秒以内に描き終えましょう

### アーカイブを見る

1. TOPページで「過去のスケッチブックを見る」をクリック
2. 表紙一覧から見たいスケッチブックを選択
3. 全ページをグリッド表示で確認
4. お題と最終回答の比較結果をチェック

## プロジェクト構成

```
sketch-and-guess/
├── app/
│   ├── controllers/
│   │   ├── rooms_controller.rb      # ルーム管理、ゲーム進行
│   │   └── sketch_books_controller.rb # スケッチブック、アーカイブ
│   ├── models/
│   │   ├── cache/                   # Redisキャッシュモデル
│   │   │   ├── room.rb
│   │   │   ├── user.rb
│   │   │   └── game.rb
│   │   ├── sketch_book.rb           # スケッチブックモデル
│   │   ├── page.rb                  # ページモデル
│   │   └── prompt.rb                # お題モデル
│   └── views/
│       ├── rooms/                   # ゲーム画面
│       │   ├── index.html.erb      # TOP
│       │   ├── new.html.erb        # ルーム作成
│       │   ├── show.html.erb       # 待機画面
│       │   ├── prompt_selection.html.erb # お題選択
│       │   └── results.html.erb    # 結果画面
│       └── sketch_books/            # スケッチブック
│           ├── index.html.erb      # アーカイブ一覧
│           ├── show.html.erb       # ゲームプレイ/アーカイブ詳細
│           └── _archive_view.html.erb # アーカイブ表示
├── config/
│   └── routes.rb
└── db/
    ├── migrate/                     # マイグレーション
    └── seeds.rb                     # お題のシードデータ
```

## お題データ

お題は`db/seeds.rb`で管理されています。6種類のお題カードがあり、ダイスの目（1〜6）に対応しています。

特別なお題：
- **FREE**: ジャンル指定なしで自由にお題を入力
- **FREE:ジャンル名**: 指定ジャンルで自由にお題を入力

## デプロイ

## カスタマイズ

### お題を追加する

`db/seeds.rb`を編集して新しいお題を追加できます：

```ruby
Prompt.create!(
  order: 7,
  word: "あなたのお題",
  category: "カテゴリー名"
)
```

### タイマーを変更する

`app/views/sketch_books/show.html.erb`の JavaScript部分で時間を変更：

```javascript
let timeLeft = 60; // 秒数を変更
```

### 参加人数を変更する

`app/views/rooms/new.html.erb`のスライダー範囲を変更：

```erb
<%= form.range_field :member_limit, in: 4..8, ... %>
```

## トラブルシューティング

### 画像がアップロードできない

Active Storageの設定を確認してください：

```bash
rails active_storage:install
rails db:migrate
```

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 作者

Generated with ❤️ using [Claude Code](https://claude.com/claude-code)

---

🎮 **Have fun playing Sketch & Guess!** 🎨
