# Sketch & Guess ゲーム仕様書

## ゲーム概要
お絵かきとテキストを交互に行う伝言ゲーム

## プレイヤー人数
4-8人

---

## ゲームの流れ

### 1. お題の配布（ラウンド開始時）

#### Promptデータ構造
- `card_num`: integer（カードグループ番号）
- `order`: integer（1-6、ダイスの出目に対応）
- `word`: string（お題の単語）
  - 特殊値 `"FREE"`: ユーザーに自由入力させる

#### お題配布フロー
1. プレイヤー数分の異なる`card_num`を選択
   - 例: 4人なら card_num: 1, 2, 3, 4
2. 各プレイヤーに1つの`card_num`グループ（6個のお題）を配布
3. **ダイスを1つ振る**（全員共通の出目）
   - 出目: 1-6
4. 全員が同じ`order`のpromptをお題として選択
   - プレイヤーA → card_num: 1, order: 3 のお題
   - プレイヤーB → card_num: 2, order: 3 のお題
   - プレイヤーC → card_num: 3, order: 3 のお題
   - プレイヤーD → card_num: 4, order: 3 のお題

→ 各プレイヤーは異なるお題を持つが、同じorder番号（ダイスの出目）のものを選ぶ

---

### 2. 初期化フェーズ（ターン1）

#### 偶数人の場合
1. 各プレイヤーにスケッチブックを1冊ずつ配布
2. 1ページ目に自分の名前とお題を書く
3. **この時点では渡さない**

#### 奇数人の場合
1. 各プレイヤーにスケッチブックを1冊ずつ配布
2. 1ページ目に自分の名前とお題を書く
3. **すぐにスケッチブックを隣に渡す**

---

### 3. ゲーム進行（偶数人の例: 4人）

```
ターン1: 1ページ目に自分の名前とお題を書く
        （この時点では渡さない）

ターン2: 自分のお題を2ページ目に描く（絵・60秒）
        → 右隣に渡す

ターン3: 受け取ったスケッチブックの絵（2ページ目）を見て
        3ページ目にテキスト回答（制限なし）
        → 右隣に渡す

ターン4: テキスト（3ページ目）を見て4ページ目に絵を描く（60秒）
        → 右隣に渡す

ターン5: 絵（4ページ目）を見て5ページ目にテキスト回答（制限なし）
        → 右隣に渡して元の持ち主に戻る（1ラウンド終了）
```

**完成したスケッチブック（4人の場合）**:
- 1ページ目: お題（Alice）
- 2ページ目: 絵（Alice）
- 3ページ目: テキスト（Bob）
- 4ページ目: 絵（Carol）
- 5ページ目: テキスト（Dave）
- **合計5ページ**

---

### 4. ゲーム進行（奇数人の例: 5人）

```
ターン1: 1ページ目に自分の名前とお題を書く
        → すぐにスケッチブックを右隣に渡す

ターン2: 受け取ったスケッチブックの1ページ目のお題を見て
        2ページ目に絵を描く（60秒）
        → 右隣に渡す

ターン3: 絵（2ページ目）を見て3ページ目にテキスト回答（制限なし）
        → 右隣に渡す

ターン4: テキスト（3ページ目）を見て4ページ目に絵を描く（60秒）
        → 右隣に渡す

ターン5: 絵（4ページ目）を見て5ページ目にテキスト回答（制限なし）
        → 右隣に渡して元の持ち主に戻る（1ラウンド終了）
```

**完成したスケッチブック（5人の場合）**:
- 1ページ目: お題（Alice）
- 2ページ目: 絵（Bob）
- 3ページ目: テキスト（Carol）
- 4ページ目: 絵（Dave）
- 5ページ目: テキスト（Eve）
- **合計5ページ**

---

### 5. 複数ラウンド

`Cache::Room.total_round > 1`の場合：
1. お題を変更（新しいcard_numとダイスの出目）
2. スケッチブックを新しくする（新しいSketchBookレコードを作成）
3. 次のラウンド開始
4. ラウンドごとに異なる`SketchBook.round`値で識別

---

### 6. 結果の表示

- 各スケッチブックごとに全ページを順番に表示
- 非同期でOK（各プレイヤーが自分のペースで閲覧可能）
- 元のお題と最後の回答を比較して楽しむ

---

## 技術仕様

### 制限時間
- **絵を描く**: 60秒（カウントダウンタイマー）
- **テキスト回答**: 制限なし

### 待機時の表示
- テキスト回答中、他のプレイヤーが完了待ちの時
- 「あと○人が回答中...」と表示して進捗を可視化

### スケッチブックを渡す方向
- 固定方向（右回り）
- `Cache::Room`に参加したユーザーの登録順序を保持
- この順序に従ってスケッチブックを順番に回す

### 絵のデータ形式
- **形式**: PNG画像
- **保存**: Active Storageを使用
- Canvas APIで描いた絵をBlob/File形式に変換して保存

---

## データモデル設計

### 永続化モデル（ActiveRecord）

#### SketchBook
スケッチブック本体（ゲーム結果の保存）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | integer | 主キー |
| room_id | string | ゲームルームID（Cache::RoomのID） |
| owner_name | string | スケッチブックの元の持ち主 |
| prompt_id | integer | お題のID |
| round | integer | ラウンド番号（1, 2, 3...） |
| completed | boolean | 完成フラグ（元の持ち主に戻ったか） |
| created_at | datetime | 作成日時 |
| updated_at | datetime | 更新日時 |

**リレーション**:
- `belongs_to :prompt`
- `has_many :pages, dependent: :destroy`

---

#### Page
スケッチブックのページ

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | integer | 主キー |
| sketch_book_id | integer | スケッチブックID |
| page_number | integer | ページ番号（1, 2, 3...） |
| page_type | string | ページタイプ（prompt/sketch/text） |
| content | text | テキストコンテンツ（page_type=textの場合） |
| user_name | string | 作成者名 |
| created_at | datetime | 作成日時 |
| updated_at | datetime | 更新日時 |

**page_type**:
- `"prompt"`: お題ページ（1ページ目）
- `"sketch"`: 絵のページ
- `"text"`: テキストページ

**リレーション**:
- `belongs_to :sketch_book`
- `has_one_attached :image`（page_type="sketch"の場合、Active Storage使用）

---

#### Prompt
お題データ

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | integer | 主キー |
| card_num | integer | カードグループ番号 |
| order | integer | 順序（1-6、ダイスの出目） |
| word | string | お題の単語（"FREE"の場合はユーザー入力） |
| created_at | datetime | 作成日時 |
| updated_at | datetime | 更新日時 |

**リレーション**:
- `has_many :sketch_books`

---

### 揮発モデル（CacheModel）

#### Cache::Room
ゲームルーム（一時的な状態管理）

| 属性 | 型 | 説明 |
|-----|-----|------|
| id | string | ルームID（UUIDなど） |
| member_limit | integer | 人数制限（4-8） |
| total_round | integer | 総ラウンド数 |
| entering_count | integer | 現在の参加人数 |
| member_order | array/json | 参加ユーザーの順序（スケッチブックを渡す順番） |

**TTL**: 1日

**メソッド**:
- `full?`: 参加人数が上限に達したか

---

#### Cache::User
ユーザー情報（一時的な状態管理）

| 属性 | 型 | 説明 |
|-----|-----|------|
| id | string | ユーザーID（UUIDなど） |
| name | string | ユーザー名 |
| room_id | string | 所属ルームID |
| sketch_book_id | integer | 自分のスケッチブックID（永続化されたSketchBook） |
| current_sketch_book_id | integer | 現在持っているスケッチブックID（オプション） |

**TTL**: 1日

---

#### Cache::Game
ゲーム進行状態（一時的な状態管理）

| 属性 | 型 | 説明 |
|-----|-----|------|
| id | string | ゲームID（room_idと同じ） |
| room_id | string | ルームID |
| current_turn | integer | 現在のターン番号 |
| turn_type | string | ターンタイプ（sketch/text） |
| turn_started_at | datetime | ターン開始時刻 |
| current_round | integer | 現在のラウンド番号 |
| status | string | ゲーム状態（waiting/in_progress/finished） |
| sketch_book_holders | hash/json | スケッチブックの現在の持ち主情報 |

**TTL**: 2時間

**status**:
- `"waiting"`: 参加者待ち
- `"in_progress"`: ゲーム進行中
- `"finished"`: ゲーム終了

**sketch_book_holders**の例:
```json
{
  "sketch_book_1": "user_name_a",
  "sketch_book_2": "user_name_b",
  "sketch_book_3": "user_name_c",
  "sketch_book_4": "user_name_d"
}
```

---

## ゲーム状態遷移

```
1. waiting（参加者待ち）
   ↓ 人数が揃う（member_limit達成）

2. in_progress（ゲーム進行中）
   ↓ 全スケッチブックが元の持ち主に戻る

3. round_finished（ラウンド終了）
   ↓ 次のラウンドがある場合は2へ、なければ4へ

4. finished（ゲーム終了）
```

---

## UI/UX仕様

### お題入力画面（word="FREE"の場合）
- テキスト入力フィールドを表示
- 自由にお題を入力できる

### 絵を描く画面
- Canvas APIを使用
- 60秒のカウントダウンタイマー表示
- ペン、消しゴム、色選択などの基本ツール
- タイムアップまたは「完了」ボタンでPNG保存

### テキスト回答画面
- テキスト入力フィールド
- 制限時間なし
- 「回答完了」ボタン
- 他のプレイヤーの進捗表示: 「あと○人が回答中...」

### 待機画面
- 他のプレイヤーが作業中の時
- 進捗バー/インジケーター
- 「あと○人が回答中...」

### 結果表示画面
- スケッチブック選択UI
- ページめくりUI（前へ/次へボタン）
- 元のお題と最後の回答を並べて表示（オプション）

---

## 実装の注意点

### キャッシュの揮発性
- `Cache::`モデルは一定時間で消える
- 永続化すべきデータ（スケッチブック、ページ）は必ずActiveRecordモデルへ
- `user_id`ではなく`user_name`を保存（キャッシュが消えても大丈夫）

### スケッチブックの完成判定
- `SketchBook.completed`フラグを使用
- または、ページ数で判定: `pages.count == expected_page_count`
- 期待ページ数 = プレイヤー数 + 1（要検証）

### 同時実行制御
- 複数プレイヤーが同時にページを作成する可能性
- トランザクションまたは楽観的ロックの検討

### リアルタイム通信
- Action Cable/Turbo Streamsで進捗状況をリアルタイム更新
- ターン切り替え時の同期

---

## 今後の検討事項

- [ ] スケッチブックの完成判定ロジックの詳細（ページ数の計算）
- [ ] Cache::Gameでのスケッチブック持ち主管理の実装方法
- [ ] Cache::Roomのmember_order管理方法（配列 vs JSON）
- [ ] リアルタイム通信の実装方法（Action Cable vs Turbo Streams）
- [ ] エラーハンドリング（途中退出、タイムアウトなど）
- [ ] セキュリティ対策（不正なページ追加の防止など）

---

**更新日**: 2025-10-23
**バージョン**: 1.0