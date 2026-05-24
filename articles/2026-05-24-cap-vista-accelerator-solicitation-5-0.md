---
title: "Cap Vista Accelerator とは — シンガポール国家安全保障向けイノベーション・アクセラレータ Sol 5.0"
emoji: "🇸🇬"
type: "idea"
topics: ["capvista", "singapore", "accelerator", "maritime", "startup"]
published: true
---

## この記事について

[Cap Vista Accelerator — Solicitation 5.0](https://accelerator.capvista.com.sg/en/challenges/solicitation-5-0?lang=en) は、2026 年 3〜4 月に応募受付を行い、6 月 4 日にピッチが予定されていたシンガポール発の公募プログラムです。

筆者は **[EdgeSentry](https://github.com/edgesentry)** — エッジセキュリティと AI を中心に OSS で開発しているプロジェクト — の一員として活動しています。Sol 5.0 では Challenge 1（海上保安データ分析）に、シャドウフリートの可視化・分析をテーマとした提案を提出しました。

本記事は、Cap Vista が「誰か」「何のためにやっているか」、Sol 5.0 で何を募集していたか、応募時に何を意識すべきかを、公開情報と筆者の応募経験をもとに整理したものです。（防衛・国家安全保障の文脈を含むため、提出文案の直接転載はしていません。）

---

## Cap Vista とは誰か

**Cap Vista Accelerator** は、シンガポールの **Cap Vista** が運営するイノベーション公募プラットフォームです。公式サイトでは次のように位置づけられています。

- グローバルな企業・スタートアップ・大学を招き、**チャレンジ文書（Challenge Statement）** に沿った提案を募集する
- 評価パネル（チャレンジオーナー・技術専門家を含む）が提案を審査し、ショートリストが **ピッチ** に進む
- 採択者には **完全資金提供のトライアル**（PoC・実験・デモ等）が付与される
- 成功すれば **エンドユーザーと直接協働して検証し、スケールを目指す**

プラットフォーム本体は [Agorize](https://www.agorize.com/) 上に構築されています。個人参加も可能で、**複数チャレンジへの同時応募** も明示的に許されています。

Cap Vista 自体の法人沿革や出資構造は公開情報が限定的ですが、募集テーマ（AI・センサー・海事・エネルギー・先端材料）と「national security applications」という表現から、**シンガポールの国家安全保障・防衛イノベーションエコシステム**（DSTA / MINDEF 系のエンドユーザー・研究機関と接続する窓口）として理解するのが実務上妥当です。応募者にとって重要なのは「VC のデモデー」ではなく **「課題オーナーが書いた要求仕様に対する、資金付き実証の入札」** だという点です。

---

## 何の目的でやっているか

公式のフレーミングは **「From Prototype to Breakthrough Innovation」** — プロトタイプを、そのままでは届かない現場課題に接続することです。

| ステップ | 内容 |
|---------|------|
| 1. 課題公開 | エンドユーザー側の pain を Challenge Statement として具体化 |
| 2. 提案募集 | グローバルから技術提案を集める（論文だけでなく **実装・デプロイ可能なソリューション**） |
| 3. 評価・ピッチ | 革新性・関連性・実装 readiness を見る |
| 4. 資金付きトライアル | 提案どおりの検証方法で PoC を実施（コストは Cap Vista 側負担） |
| 5. スケール | うまくいけば運用展開を加速 |

Innovator にとけるメリットは、単なる助成金以上に **「課題を持つ側（エンドユーザー）との直接接続」** です。特に防衛・海事・インフラ系では、一般市場向け SaaS では触れにくい **運用データ・評価基準・現場制約** がトライアル設計に含まれるため、プロダクトの検証深度が一段上がります。

---

## Solicitation 5.0 では何を募集していたか

Sol 5.0 のタグラインは **「AI, sensors, maritime, energy and advanced materials」** 領域の課題解決です。2026 年時点の [Challenge Statements](https://accelerator.capvista.com.sg/en/challenges/solicitation-5-0?lang=en) には **5 つの独立したチャレンジ** がありました。

### Challenge 1 — 海上保安データ分析

**要約:** MPOL（Maritime Pattern of Life）分析を、AIS・SAR・EO・独自データセット等の融合から **一段進め、シャドウフリート**（制裁回避・グレーゾーン運用）を **予測・特定** する新しい分析手法を求める。

**求めるもの（抜粋）**

- シンガポールから最大 1600nm、水深 200m までの主要航路でシャドウフリートを特定・予測する技法
- オープンソース・EO 等を融合し、異常と予測を形成する ingest / fusion
- シャドウフリート MPOL 検知に資する **独自データセット** の提案

**評価メトリクス:** 予測精度 · 計算コスト · 粒度 · **説明可能性（Explainability）**

**明示的に「不要」とされたもの（重要）**

- 履歴データだけに依存する予測
- **定番手法のそのまま:** リアルタイム船舶監視、AIS+衛星融合による単純異常検知、行動プロファイリング、**リスクスコアリング**、ジオフェンス、従来型制裁スクリーニング、既製 behavioural analytics

→ つまり Windward / Pole Star 型の「AIS 異常スコア SaaS」をそのまま持ち込むのは **設計上アウト** です。**文脈指標（マクロ物流・経済）・予測・説明可能な新規性** をどう示すかが勝負になります。

### Challenge 2 — 低視界自律走行キット

全天候・低視界（豪雨・煙・塵）での on/off-road 自律走行向け **ポータブルキット**。SWaP（Size, Weight, Power, Cost）と誤警報率が metrics。提供車両への最大 6 ヶ月統合、現地テスト 1 週間以内。

### Challenge 3 — ポータブル高エネルギー蓄電

150 Wh 超の **スリムな manpack 蓄電**、太陽光・車載・AC 等からの充電。Wh/kg、サイクル寿命、11–16.8 V / 5 A 出力。熱帯 humid 環境での accredited lab 検証。

### Challenge 4 — 野戦用発電ユニット

2 kW 超を **12 時間以上連続** 出力する小型・静音・野戦展開可能な発電。ソーラー・バイオ燃料・ガス等の組み合わせ可。従来型ディーゼル発電機の incremental 改善は対象外。

### Challenge 5 — 海事環境向け腐食管理

塩害・高湿度の熱帯海事資産向け **新規防食・コーティング**。保護寿命、エネルギー効率、retrofit 互換。Phase 1  lab → Phase 2 現場の二段階トライアル。

### スケジュール（Sol 5.0）

| フェーズ | 時期 |
|---------|------|
| 応募 | 2026-03-23 〜 2026-04-29 13:00 (GMT+8) |
| ショートリスト | 2026 年 4 月末〜5 月 |
| ピッチ | **2026-06-04（Hybrid）** |
| 採択後 | 提出から約 60 日以内にアワード（公式記載） |

※ 2026 年 5 月時点で公式ページには **「The challenge has ended and all enquiries are now closed.」** と表示されています。

---

## 応募する際に気をつけること

Sol 5.0 全体と、特に C1（海事分析）で効いた／効くと考えたポイントです。

### 1. 「What We Are **Not** Looking For」を最初に読む

Cap Vista のチャレンジは **否定リストが具体的** です。C1 は「AIS 融合・リスクスコア・既製 analytics」を明示的に除外しています。自分の製品説明が **その否定リストの言い換えになっていないか** を第三者にチェックさせるのが安全です。

### 2. 評価軸は二つだけ — 両方に数字で答える

公式の評価基準はおおむね次の二本柱です。

- **Innovativeness and Relevance** — どの pain に、既存市場と何が違うか
- **Tech Feasibility and Readiness** — スケール時のコスト、商用実績

「すごい AI」だけでは足りず、**トライアル期間・環境・成功条件** まで PDF 提案書に書く必要があります（Conditions of Contract のダウンロードと提案テンプレート PDF が必須）。

### 3. C1 では「公開データの限界」と「Cap Vista データの役割」を分けて書く

シャドウフリート検知では、公開 OFAC / AIS だけでは **ラベル密度が構造的に低い**（例: シンガポール近海の confirmed positive が極端に少ない）ことがあります。メトリクス（Precision@K、AUROC 等）を **何のラベル集合に対する数字か** とセットで示さないと、審査側は「精度が低いのでは？」と誤読します。

逆に、**Cap Vista が持つ MPOL 確認 intercept ラベル** を注入したときに何が変わるか — それが PoC の核心実験として設計できると、エンドユーザー視点の説得力が出ます。

### 4. Explainability は「nice to have」ではなく Key Metric

C1 では **Explainability** が metrics に明示されています。ブラックボックススコアだけでなく、**特徴量寄与・根拠チェーン・第三者が追える説明** をデモ可能な形で示すとよいです。

### 5. 計算コストと edge 展開をセットで

「Low computational cost to maximise **edge deployments**」とあるため、クラウド GPU 前提の批評だけでは弱いです。ラップトップ / エッジノード / ブラウザ内分析（WASM 等）で **どこまで回るか** をベンチマーク付きで書くと Feasibility 軸に刺さります。

### 6. Option Cost（スケール費用）を省略しない

各チャレンジに **Option Cost** 欄があります。PoC 成功後の **単価・台数ティア・データ取得コスト** をぼかすと、商用 readiness の評価で不利になります。

### 7. 複数応募可 — ただし提案はチャレンジごとに独立

Sol 5.0 は **チャレンジごとに別提案** です。同じコア技術を別ドメインに横展開する場合でも、**課題文の語彙と metrics に合わせて書き直す** 必要があります。

### 8. Cap Vista には別系統の公募もある

Sol 5.0 以外に、例えば **Innovative Products & Services** 公募や **AI Joint Challenge**（OSINT + SWaP 等）など、Cap Vista ブランド下で **目的と評価軸の異なる公募** が並行することがあります。Sol 5.0 の C1 は「海事 MPOL / シャドウフリート analytics」に特化しており、Products 公募や Joint Challenge は **別の勝ち方** です。どの公募に何を出すかは、スポンサーが重視する pain と自社の主商品線の交差で決めるのがよいです。

---

## まとめ

| 問い | 短い答え |
|------|---------|
| Cap Vista は誰？ | シンガポール発。国家安全保障系課題を **Challenge Statement で公開し、資金付きトライアルで検証する** 公募プラットフォーム |
| 何のため？ | プロトタイプをエンドユーザーの実課題に接続し、採用・スケールまで短いサイクルで進める |
| Sol 5.0 で何を？ | 5 題（海事 analytics / 低視界自律走行 / 蓄電 / 発電 / 腐食管理）。C1 は **シャドウフリート・MPOL の次世代 analytics** |
| 応募の勘所 | **Not Looking For 回避** · 二軸評価（革新×実装）· トライアル設計 · explainability · edge コスト · option cost · ラベルと metrics の正直な定義 |

Sol 5.0 の応募期間は終了していますが、Cap Vista は今後も solicitation を出す可能性が高く、同型の **「否定リスト付き RFP + 資金付き PoC」** として参考になります。次の solicitation が出たら、まず challenge card の **Learn more → What We Are Not Looking For** から読み始めるのが、最も時間対効果の高い準備です。

---

## 参考リンク

- [Cap Vista Accelerator — Solicitation 5.0（公式）](https://accelerator.capvista.com.sg/en/challenges/solicitation-5-0?lang=en)
- [EdgeSentry（GitHub）](https://github.com/edgesentry)
