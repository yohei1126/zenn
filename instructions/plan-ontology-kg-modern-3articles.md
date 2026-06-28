# Season 4 企画：オントロジー活用レベル（L0〜L5）の探究（3部作）

## 0. 位置づけ

### 本シリーズの趣旨と目的（冒頭宣言）

- **普遍的な方法論ではなく「当事者の実践論」**:
  本シリーズは、あらゆる現場で使える普遍的で抽象的なオントロジー構築法を提案するものではない。著者が直面している具体的なプロジェクト（サプライチェーン影響分析など、グラフ構造とグラフアルゴリズムが真に有効で、ビジネス価値を生む問題）の解決から得られた方法論の整理である。
- **起点となる問題**:
  「グラフとグラフアルゴリズムが有効で、会社にとって明確な価値がある問題」が先にあり、それをAIエージェントによって効率的かつ安全に運用したいという要求が起点となっている。
- **直面する摩擦とオントロジーの再定義**:
  グラフデータベースは本来スキーマレスであり、管理や整合性の維持が困難である。そのため、「グラフDBが壊れていないこと」をシステム的に保証したい。また、グラフを参照するLLMエージェントが回答する際の「グラウンディング（根拠検証）の確かな拠り所」が欲しい。
  これらの実践的課題を解決するために、データエンジニア（DE）やAIエンジニアが現場で**「気持ちよく使える」開発者体験**を重視し、現代的解釈としてオントロジーを「データ品質と回答検証の契約（Contract）」として再定義する。
- **体系的解説**: サプライチェーン影響分析の参照実装 [supply-chain-impact-analysis-agent](https://github.com/yohei1126/supply-chain-impact-analysis-agent) のドキュメント [ontology-levels.md](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/docs/ontology-levels.md) (および [ontology-levels-general.md](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/docs/ontology-levels-general.md), [ontology-levels-project.md](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/docs/ontology-levels-project.md)) をベースに、オントロジー活用レベル（L0〜L5）と回答のグラウンディング（G\*）を体系的に解説する。
- **ペルソナごとのゴール**:
  - **データエンジニア（DE）**: LPG（Neo4j）をクローズドワールド（CWA）として捉え、インジェスト時・ロード後に厳密なバリデーションを回して「信頼できるグラフ基盤」を構築する（L0〜L3）。
  - **AIエンジニア（AI）**: 信頼されたグラフに対し、LLMに直接DBクエリを書かせるのではなく、決定論的ツール（L4/Traversal）を介して安全に探索し、その結果からLLMが要約時に幻覚を起こさないよう回答を検証する（G\* Grounding）。

### シリーズの重心

```text
  第1部  現代的オントロジーの定義とペルソナ（Why）  … 古典AIとの決別、LLM前提の再定義、L0〜L5+G*の定義
  第2部  現代アーキテクチャとDE/AIの分担（What）   … 3段パイプライン、CWAに基づく検証タイミング（Validation Timing）の設計
  第3部  参照実装でのハンズオン（How）            … Pydantic + Neo4j + SHACL + Graph Contract + Grounding 実装
```

### 既存企画との関係（連載マップ）

本シリーズは、これまでの仮想グラフ戦略、論理フェデレーション、およびデータプラットフォーム上での最新トレンドに続く **「シーズン4」** として位置づけます。

| シーズン | 記事群 | 問い・テーマ |
| :--- | :--- | :--- |
| **Season 1**<br>(仮想グラフ) | [2026-05-30-vkg-strategy-what.md](file:///Users/yoheionishi/work/zenn/articles/2026-05-30-vkg-strategy-what.md)<br>[vkg-strategy2.md](file:///Users/yoheionishi/work/zenn/articles/2026-05-30-vkg-strategy2.md)<br>[vkg-strategy3.md](file:///Users/yoheionishi/work/zenn/articles/2026-05-30-vkg-strategy3.md) | **① データをどう辿り、型を固定するか**<br>・仮想グラフ（VKG）戦略とオントロジー設計の必要性<br>・知識獲得のボトルネックと古典的アプローチの限界 |
| **Season 2**<br>(論理フェデレーション) | [supply-chain-impact-analysis-agent.md](file:///Users/yoheionishi/work/zenn/articles/2026-06-06-supply-chain-impact-analysis-agent.md)<br>[agent2.md](file:///Users/yoheionishi/work/zenn/articles/2026-06-06-supply-chain-impact-analysis-agent2.md)<br>[agent3.md](file:///Users/yoheionishi/work/zenn/articles/2026-06-06-supply-chain-impact-analysis-agent3.md) | **② 部門別データをどう結ぶか**<br>・社内データスペースの論理フェデレーション<br>・Bridge Keyを用いたグラフ結合とGraph Contractの基礎 |
| **Season 3**<br>(コンテキスト革命) | [databricks-genie-ontology-ontorank.md](file:///Users/yoheionishi/work/zenn/articles/2026-06-17-databricks-genie-ontology-ontorank.md)<br>[snowflake-cortex-sense-genie-ontology.md](file:///Users/yoheionishi/work/zenn/articles/2026-06-24-snowflake-cortex-sense-genie-ontology.md) | **③ どの定義を信頼するか**<br>・利用統計（クエリログ等）から意味レイヤーを自律構築する「第三の道」<br>・Databricks Genie (OntoRank) / Snowflake Cortex Sense の比較 |
| **Season 4**<br>(本作) | *本企画 (3部作)* | **④ オントロジー活用レベル（L0〜L5 + G\*）の体系化と実装**<br>・`ontology-levels.md` の解説<br>・検証タイミングの設計と、Pydantic+Neo4j+SHACL+Groundingの具現化 |

### 参照リポジトリ（第3部）

| 用途 | パス |
| :--- | :--- |
| 索引 | [ontology-levels.md](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/docs/ontology-levels.md) |
| L0–L2 SSOT | [ontology/schema.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/ontology/schema.py) |
| L4 SSOT | [ontology/contract/graph_contract.yaml](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/ontology/contract/graph_contract.yaml) |
| export | [scripts/sync_ontology.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/scripts/sync_ontology.py) |
| seed + gate | [scripts/seed_complex_bom.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/scripts/seed_complex_bom.py) |
| L3 audit | [scripts/audit_neo4j.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/scripts/audit_neo4j.py), [app/validation/neo4j_l3_audit.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/app/validation/neo4j_l3_audit.py) |
| L4 ingest audit | [scripts/audit_ingest_pipeline.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/scripts/audit_ingest_pipeline.py) |
| Federation | [app/federation/composer.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/app/federation/composer.py), [app/exploration.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/app/exploration.py) |
| Agent + G\* | [app/agent/runner.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/app/agent/runner.py), [app/agent/grounding.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/app/agent/grounding.py), [scripts/eval_agent_grounding.py](file:///Users/yoheionishi/work/supply-chain-impact-analysis-agent/scripts/eval_agent_grounding.py) |

---

## 1. シリーズ一行要約

> 古典AIの焼き直しではない。LLMと近代的DE/AIスタックを前提に、オントロジーを「推論エンジン」ではなく「データ品質と Grounding の検証契約（Contract）」として再定義する。

---

## 2. タイトル設計と3部構成

Zennの制約（メインタイトル＋サブタイトルを合わせて70文字以内）に適合するよう、以下のタイトル設計とします。

- **メインタイトル（共通）**: `現代の知識グラフとオントロジー` (14文字)
- **区切り文字**: ` - ` (3文字)

| 部 | 記事タイトル案 (文字数) | 重心 | コード |
| :--- | :--- | :--- | :--- |
| **第1部** | **現代の知識グラフとオントロジー - 「推論」から「契約」へ：データ品質保証と回答検証の全体像** (45文字) | 古典との対比、LLM前提の定義、ペルソナ別の関心（L0–L5 + G\*） | **概念のみ**（Pydantic/YAML の対比数行まで） |
| **第2部** | **現代の知識グラフとオントロジー - インジェストから監査まで、DE/AIの検証タイミング設計** (44文字) | 3段パイプライン、CWAに基づく validation timing、CI/CD・テスト自動化の役割分担 | **抜粋スニペット**（schema / YAML 各10行） |
| **第3部** | **現代の知識グラフとオントロジー - PydanticからSHACL、Agent Groundingにいたる実装ハンズオン** (51文字) | clone → seed → audit → agent → grounding eval (ハンズオン) | **実行可能コード中心**（実リポジトリの徹底引用） |

---

## 3. 古典的オントロジー vs 現代の定義（対比方針）

「過去のセマンティックWebの焼き直し」にしないため、第1部冒頭で以下の対比を明確に示します。

| 次元 | 古典的オントロジー（過去の焼き直し） | 現代の定義（LLM前提・DE/AIプラクティス） |
| :--- | :--- | :--- |
| **主要前提** | 論理推論エンジン（Reasoner）が全てを解決する | **LLMのセマンティクス理解**と**近代的エンジニアリング**の融合 |
| **世界観** | オープンワールド仮説（OWA / 不明な情報は「真偽不明」） | クローズドワールド仮説（CWA / スキーマ外は「即座にエラー」） |
| **表現と言語** | RDF/XML, OWL, SPARQL などの重厚な独自技術 | **Pydantic**, **JSON Schema**, **YAML** などの汎用エンジニアリング言語 |
| **検証の主眼** | TBoxによる公理の論理的一貫性チェック | **インジェスト時（On write）の拒否**と**ロード後の自動監査（CI/CD）** |
| **推論（Inference）** | OWL Reasoner による暗黙のノード/エッジの導出（高コスト） | 決定論的な**グラフアルゴリズム/Traversal** ＋ **LLM によるコンテキスト要約** |
| **Grounding (G\*)** | なし（グラフのデータ自体がSSOTで完結） | **LLMの回答がツール出力（Evidence）から逸脱していないかの動的検証** |

---

## 4. ペルソナごとの「やりたいこと」

本シリーズでは、読者の想定ペルソナを明確にし、「なぜオントロジーに投資するのか」をエンジニアリングの動機として整理します。

### ① データエンジニア（DE）がやりたいこと
* **ゴール**: LLMやアプリケーションが「踏んでも壊れない」頑丈で信頼できるグラフデータベースを維持する。
* **やりたいこと（オントロジーの用途）**:
  - Pydanticなどの使い慣れた言語でスキーマをSSOT（単一の真実のソース）として定義し、CIやスキーマ同期を自動化する。
  - 不正なデータ（型違反、未定義のリレーション）がNeo4jに書き込まれるのをストレージ境界でブロックする（On write validation）。
  - すでにロードされたグラフに対し、グラフ全体としての整合性を自動監査（SHACL/Cypher）し、データ品質をCI/CDパイプラインの一部として証明する。

### ② AIエンジニア（AI）がやりたいこと
* **ゴール**: LLMエージェントがユーザの ad-hoc な質問に対して、ハルシネーション（幻覚）を起こさず、根拠（エビデンス）に基づいた正確なビジネスロジックを返す。
* **やりたいこと（オントロジーの用途）**:
  - LLMに直接 Cypher を書かせるのではなく、オントロジーで保証された「名前付き探索ツール（Traversal / L4）」を道具（Tools）として提供し、実行パスを決定論的にする。
  - ツールが返した構造化エビデンス（ノードIDや値）と、LLMが最終的に生成した自然言語の要約が一致しているかを、検証プログラム（G\* Grounding）によって動的に防御する。

---

## 5. 各部アウトライン

### 第1部：現代の知識グラフとオントロジー - 「推論」から「契約」へ：データ品質保証と回答検証の全体像
**ファイル名（案）:** `2026-07-xx-kg-ontology-redefinition.md`  

#### 一行要約
OWL推論の焼き直しは不要。LLM前提の現代において、DE（データ品質）とAI（Grounding）がオントロジーを使ってやりたいことと、その活用レベル L0〜L5 を体系的に再整理する。

#### 構成
* **§0. 連載案内**: 3部構成と参照リポジトリの紹介。
* **§1. なぜいま「オントロジー」を再定義するのか**:
  - SaaS/DWHの乱立によるセマンティクスの分断。
  - LLMエージェントのハルシネーション問題。
  - 「推論エンジン」ではなく「検証・品質契約（Contract）」としての再評価。
* **§2. 古典的オントロジー vs 現代の定義（3の対比表）**:
  - OWA vs CWA。
  - OWL/RDF vs Pydantic/YAML。
  - 論理推論 vs Traversal+LLM。
* **§3. ペルソナごとに「やりたいこと」**:
  - DEの関心: 信頼できるデータインフラ、CI/CDの一部としてのデータ品質監査。
  - AIの関心: Tool境界の安全性、G\* Groundingによる幻覚の動的検証。
* **§4. オントロジー活用レベル (L0–L5) ラダー**:
  - `ontology-levels-general.md` に基づき、L0からL5までの階層定義を導入。
    - **L0: Vocabulary**（語彙）
    - **L1: Payload Schema**（プロパティ・値の型）
    - **L2: Structural Constraints**（許可されたエッジパターン）
    - **L3: Instance Conformance**（格納されたデータ全体の整合性証明）
    - **L4: Graph Contract**（マルチドメイン間のフェデレーション合意）
    - **L5: Reasoning**（OWL等による論理推論）
  - 本プロジェクトが「どこまでカバーし、どこを明示的にスコープ外（L5 OWL）とするか」の宣言（本番運用ではL5ではなく、L0〜L4＋G\* が最も実用的であることの提示）。
* **§5. コラム：古典オントロジーとの決別**:
  - RDF/OWL/SHACL の役割を一言ずつ解説し、Season 0 へ誘導（深追い禁止）。

---

### 第2部：現代の知識グラフとオントロジー - インジェストから監査まで、DE/AIの検証タイミング設計
**ファイル名（案）:** `2026-07-xx-kg-ontology-modern-architecture.md`  

#### 一行要約
validated ingest → federated traversal → grounded answers を実現するために、いつ、誰が、何を検証すべきか（Validation Timing）の近代的設計方針。

#### 構成
* **§1. 現代KGの3段パイプライン**:
  - 1) Ingest（スキーマ検証された書き込み）
  - 2) Exploration（決定論的なツールによる探索とフェデレーション）
  - 3) Grounding（回答の根拠検証ゲート）
* **§2. 検証タイミング（Validation Timing）の設計**:
  - `ontology-levels-project.md` §5 に基づき、データの一貫性を保証するための検証フェーズを定義。
    - **Authoring時**: `schema.py` や `graph_contract.yaml` による「定義」（L0-L2, L4）
    - **Pre-load (メモリ上)**: データ投入前の早期エラー検出
    - **On write (書き込み時)**: closed-world ingest に従い、ストレージ境界で型やリレーション違反をブロック
    - **After load (ロード後監査 - L3)**: Cypher監査と Neosemantics SHACL による実データ整合性の「証明」
    - **At federate (フェデレーション時 - L4)**: Bridge Key による結合整合性および品質ゲートの検証
    - **CI/CDパイプライン**: 継続的な回帰テストとスキーマ・コード同期の自動化
* **§3. DEのベストプラクティス（L0–L3）**:
  - Pydantic SSOT から `ontology.json` / SHACL Shapes への自動エクスポート。
  - Write-time guards（ストレージ境界でのバリデーション）の実装パターン。
  - `audit_neo4j.py` を用いた CI パイプラインでの継続的データ監査。
* **§4. AIのベストプラクティス（L4, G\*）**:
  - Graph Contract YAML（`graph_contract.yaml`）によるマルチドメインの境界合意と Bridge Key / Join の定義。
  - 決定論的ツールによる LLM 生成 Cypher の排除。
  - `grounding.py` による LLM の要約と evidence（根拠）の整合性検証（LLM-as-a-judge & Heuristic fallback）。

---

### 第3部：現代の知識グラフとオントロジー - PydanticからSHACL、Agent Groundingにいたる実装ハンズオン
**ファイル名（案）:** `2026-07-xx-kg-ontology-implementation-walkthrough.md`  

#### 一行要約
`supply-chain-impact-analysis-agent` のコードを用いて、DEのスキーマ定義・データ監査から、AIのエージェント実行・G\*グラウンディング評価までを一気通貫で動かす。

#### 構成（ハンズオン形式）
* **§0. セットアップと全体シナリオ**:
  - `uv sync`, Neo4j (n10s起動), 全体の実行ジャーニーのMermaid（DEトラックとAIトラックの分岐・合流）。
* **§1. 【DEトラック】L0–L2: Pydanticによるスキーマ定義と同期**:
  - `schema.py` の `RelationEdge` 抜粋。`sync_ontology.py` による drift drift 検証。
* **§2. 【DEトラック】On write: 異常データのブロック体験**:
  - スキーマに違反するデータを意図的に投入し、ストレージ境界（`validate_node_payload`）で即座に拒否される様子を確認。
* **§3. 【DEトラック】L3: データのシードと事後全体監査**:
  - `seed_complex_bom.py --reset` の実行。
  - `audit_neo4j.py` (Cypher + Pydantic + SHACL) による全体整合の証明。
* **§4. 【DE/AI境界】L4: Graph Contract によるドメイン連携と監査**:
  - `graph_contract.yaml` による Bridge Key の定義。
  - `audit_ingest_pipeline.py` を用いた連携品質の自動監査。
* **§5. 【AIトラック】Federated Traversal: 決定論的ツールによる探索**:
  - `app/exploration.py` / `composer.py` の join 処理。LLMに Cypher を書かせないメリット。
* **§6. 【AIトラック】G\*: Agent の実行と Grounding 検証の実態**:
  - エージェントを実行し、`evidence` ポインタを含む回答を出力させる。
  - `grounding.py` で LLM の要約がエビデンス（ツール出力JSON）から逸脱した際に fallback（ヒューリスティックによる定型文出力等）が発動する様子のコードリーディング。
* **§7. 【AIトラック】自動評価スイート**:
  - `eval_agent_grounding.py` を用いた、CI/CDで機能するグラウンディングテストの体験。
* **§8. なぜ L5 OWL Reasoning をやらないのか**:
  - LPG上における論理推論の限界、OWA vs CWA の摩擦の記録。
* **§9. まとめと検証コマンド一覧**:
  - 実運用におけるコマンドリファレンスと連載の完結。

---

## 6. 成功基準
* 古典的セマンティックWebの焼き直し（OWL Reasonerの構築など）に踏み込まず、なぜ現代スタック（Pydantic + YAML + LLM Grounding）で十分かつ安全なのかが論理的に説明されていること。
* `ontology-levels.md` の L0〜L5 および G\*、検証タイミングの体系的なマッピングが正確に紹介され、読者が「実務で適用すべきオントロジー活用レベル」を理解できること。
* 第3部を読み進めることで、ローカル環境でスキーマ検証からエージェントのグラウンディング評価までの全工程が再現・ハンズオンできること。
