# supply-chain-impact-analysis-agent：LanceDB 利用調査と Neo4j 移行実装案

対象リポジトリ: `/Users/yoheionishi/work/supply-chain-impact-analysis-agent`  
作成目的: 第3部記事のストレージ説明コストを下げるため、Neo4j ローカルへの移行可否と作業範囲を整理する  
**注:** 本ドキュメントは設計メモ。実装・記事本文の変更は別タスク。

---

## 1. 結論（要約）

| 論点 | 結論 |
| :--- | :--- |
| LanceDB は使われているか | **はい。** グラフ永続化・Cypher 実行（lance-graph）・ベクトル検索（hybrid）の3用途 |
| semantic similarity search は必須か | **フェデレーションの本筋では不要。** `bom_hybrid_query` 用のデモ機能のみ |
| Neo4j 移行は妥当か | **記事・読者体験・シーズン1との連続性の面で妥当。** フェデレーション設計（ontology / ツール境界）はそのまま維持可能 |
| 移行の核心 | **`app/storage` + `cypher_executor` の差し替え。** ontology / analysis / Agent Skill の構造は維持 |

---

## 2. 現状：LanceDB / LanceGraph の使われ方

### 2.1 依存関係

`pyproject.toml`:

- `lancedb>=0.8`
- `lance-graph>=0.5.4`

データ配置: `data/lancedb/{ebom,routing,sourcing}/`（ドメイン別）+ `data/lancedb/component_vectors/`（ベクトル）

### 2.2 用途マップ

| レイヤ | ファイル | Lance の役割 | フェデレーション本筋 |
| :--- | :--- | :--- | :--- |
| ドメインストア | `app/storage/domain_store.py` | `graph_nodes` / `graph_edges` テーブルへの CRUD | **必須（現状）** |
| フェデレーションファサード | `app/federation/graph_store.py` (`LanceGraphStore`) | 3ドメインを束ねる。BFS は Python で ebom+routing エッジ走査 | **必須（現状）** |
| Cypher 実行 | `app/federation/cypher_executor.py` | Lance 行を PyArrow に載せ、`lance_graph.CypherQuery` で **Cypher サブセット** 実行 | **必須（現状）** |
| フェデレーション分析 | `app/federation/analysis.py` | 上記 executor 経由で sourcing→ebom→routing | **必須** |
| ハイブリッド | `app/hybrid_store.py` (`UnifiedBomContextStore`) | `component_vectors` テーブルでベクトル検索 | **任意** |
| Agent ツール | `app/agent/registry.py` | `bom_hybrid_query` は hybrid 有効時のみ登録 | **任意** |

### 2.3 Cypher の位置づけ

- Cypher 文自体は **`ontology/cypher_builder.py`** が SSOT（Neo4j 移行後も流用可能）
- 実行エンジンだけが **lance-graph**（`domains/export.py` の `cypher-engine-profile.json` は `engine: lance-graph`、Neo4j 完全互換ではない）
- 制約例: `shortestPath()` 非対応 → `shortest_supply_path` は **Python BFS**（`graph_store.py`）

### 2.4 変更不要なコア（移行後も維持）

```
ontology/schema.py          # Pydantic SSOT
ontology/cypher_builder.py  # 名前付き Cypher レシピ
domains/registry.py         # ドメイン別エッジ所有権
app/federation/analysis.py  # クエリ時オーケストレーション（ID 受け渡し）
app/tools.py / GraphExplorer
skills/bom-graph-explorer/  # Graph Contract / query-catalog（engine 名のみ更新）
```

---

## 3. semantic similarity search は必要か

### 3.1 現状の実装

`app/hybrid_store.py`:

- `text_to_embedding()` — **SHA256 から固定長ベクトルを生成するデモ用疑似 embedding**（外部 LLM / embedding モデルなし）
- `vector_search_components()` — LanceDB `.search(query_vec)`
- `find_supplier_impact_for_query()` — vector → DuckDB 属性 → graph impact

`bom_hybrid_query` 利用箇所:

- UI デモシナリオ（brass valve / steel 等の自然言語）
- `scripts/demo_hybrid.py`, `scripts/seed_complex_bom.py`
- Agent runner のヒューリスティック（goal に "steel" / "vector" / "similar" を含む場合）

### 3.2 フェデレーション本筋との関係

**コアパス（有事分析）:**

```
bom_supplier_impact(supplier_id)
  → sourcing Cypher
  → ebom Cypher（Component.id）
  → routing Cypher（Product.id / Component.id）
```

→ **ベクトル検索は不要。** 第2部 §4.3 の「非構造入力 → 入口ドメインでアンカリング」も、実務的には次で足りる:

| トリガー | 決定論的アンカリング例 |
| :--- | :--- |
| 地域・国 | Sourcing グラフ / DuckDB の `Supplier.country` フィルタ |
| 材質・部品名 | DuckDB `components` の `material` / `name` LIKE |
| サプライヤー ID | `bom_supplier_impact(SUP-xxx)` 直叩き |

### 3.3 判断

| 選択肢 | 内容 | おすすめ度 |
| :--- | :--- | :--- |
| **A. hybrid ツールを外す** | `bom_hybrid_query` と vector テーブルを削除。デモは DuckDB + 決定論的ツールのみ | **記事主題に最も合う** |
| B. DuckDB のみで代替 | `ILIKE` / 全文検索で部品候補を絞り、以降は federation | 十分。説明コスト低 |
| C. LanceDB を vector 専用に残す | グラフだけ Neo4j、vector だけ `data/lancedb/component_vectors` | 移行コスト中、説明コスト高 |
| D. Neo4j Vector Index | Neo4j 5.11+ の vector + 本物 embedding | 本番向きだがスコープ拡大 |

**推奨:** シリーズの主題がフェデレーションである以上、**A または B**。現状の SHA256 ベクトルは「semantic search のデモ」としても説得力が弱く、Lance を記事で説明する ROI が低い。

---

## 4. Neo4j 移行の狙い（記事・読者向け）

- シーズン1第3部（Neo4j + Pydantic + Agent Skill）との連続性
- 第1部で既出の Neo4j イメージと整合
- 「LanceDB / lance-graph とは何か」の説明節を不要化
- Cypher カタログが **本物の Neo4j Cypher** として読める（`shortestPath` 等は将来拡張可能）

**変えないもの:** 物理分離・論理結合、Graph Contract、Bridge Keys、決定論的ツール境界。

---

## 5. ターゲットアーキテクチャ

```
ontology/                    # 変更なし（SSOT）
domains/                     # 変更なし（ingest ロジックは driver 差し替え）
app/
  storage/
    graph_store_protocol.py  # 新規: Protocol（add_node, add_edge, domain, all_nodes...）
    neo4j_domain_store.py  # 新規: 1 DB = 1 graph_id
    neo4j_config.py          # 新規: URI / auth / database 名
  federation/
    graph_store.py           # LanceGraphStore → Neo4jGraphStore（ファサード名は維持可）
    cypher_executor.py       # neo4j driver で execute（lance_graph 削除）
    analysis.py              # 基本変更なし
  hybrid_store.py            # 削除 or DuckDB-only に縮小（推奨: A）
data/
  bom.duckdb                 # 維持（Component マスタ）
docker/
  docker-compose.neo4j.yml   # 3 database または 3 コンテナ
```

### 5.1 ドメイン分離の Neo4j モデル（推奨）

**方式1: 単一 Neo4j、DB 3つ（Neo4j 4.4+ multi-database）**

| graph_id | Neo4j database | 所有エッジ |
| :--- | :--- | :--- |
| sourcing | `sourcing` | SUPPLIED_BY |
| ebom | `ebom` | USED_IN |
| routing | `routing` | PRODUCED_BY, INPUT_OF |

- 組織境界 = database 境界（第2部の設計と一致）
- 1 Docker コンテナでデモ可能

**方式2: Neo4j インスタンス 3 つ（ポート 7687/7688/7689）**

- より厳密な物理分離デモ向き。運用は重い。

### 5.2 ノード・エッジモデル

現行 Lance 行 → Neo4j プロパティグラフ:

```cypher
// 例: Component
(:Component {id: 'COMP-103', name: '...', material: '...'})

// 例: SUPPLIED_BY（sourcing DB のみ）
(c:Component {id})-[:SUPPLIED_BY {lead_time_days}]->(s:Supplier {id})
```

- `ontology/schema.py` のラベル・エッジ型をそのまま使用
- 書き込み前バリデーション（Pydantic + `domains/registry.py`）は **現行通りアプリ層**

### 5.3 Cypher 実行の差し替え

現行 `cypher_executor.py` の流れ:

1. Lance から全ノード/エッジ読み出し
2. PyArrow 化
3. `lance_graph.CypherQuery.execute(datasets)`

Neo4j 移行後:

1. `neo4j.Driver.execute_query(cypher, parameters, database_=graph_id)`
2. `ontology/cypher_builder.py` のクエリを **そのまま**（または Neo4j 向けに `IN $ids` パラメータを改善）
3. `cypher-engine-profile.json` → `engine: neo4j`、dialect_notes 更新

**メリット:** `List parameters` や `shortestPath` が使えるようになり、Python BFS を Cypher に寄せられる可能性。

---

## 6. 変更ファイル一覧（想定）

### 6.1 削除・縮小候補

| ファイル / 依存 | 理由 |
| :--- | :--- |
| `lance-graph`, `lancedb`（pyproject） | グラフ用途を Neo4j に移行後 |
| `app/storage/domain_store.py` | → `neo4j_domain_store.py` |
| `app/storage/lance_util.py` | Lance 専用 |
| `data/lancedb/**` | → Neo4j 永続ボリューム |
| `app/hybrid_store.py` の vector 部分 | 推奨: 削除（§3.3 A） |
| `tests/test_hybrid_store.py` | vector 削除時 |
| `tests/test_lance_graph_store.py` | → `test_neo4j_graph_store.py` |

### 6.2 修正

| ファイル | 変更内容 |
| :--- | :--- |
| `app/federation/graph_store.py` | `Neo4jGraphStore` ファサード（API 互換） |
| `app/federation/cypher_executor.py` | neo4j driver |
| `app/federation/serialize.py` | 文言 "Lance" → "Neo4j" |
| `domains/*/pipeline.py` | store 注入先変更 |
| `pipeline/demo/load_domains.py` | Neo4j seed |
| `domains/export.py` | `CYPHER_ENGINE_PROFILE.engine = neo4j` |
| `skills/.../cypher-engine-profile.json` | sync 再生成 |
| `app/agent/context.py` | `BOM_NEO4J_URI` 等 env |
| `app/agent/static/*` | UI 文言 Lance → Neo4j |
| `docs/*.md` | runbook 更新 |
| `docker-compose` / `scripts/run_docker_stack.sh` | Neo4j サービス追加 |

### 6.3 維持（インターフェース互換）

- `GraphExplorer.supplier_impact` / `supply_path`
- `federated_impact_rows(store, supplier_id)`
- `ToolRegistry` の `bom_supplier_impact`, `bom_supply_path`
- `scripts/sync_ontology.py` 出力形式

---

## 7. 実装フェーズ

### Phase 0: 準備（1–2日）

- [ ] `GraphStore` Protocol 定義（`domain()`, `add_node`, `add_edge`, `impacted_products_by_supplier`）
- [ ] `docker-compose.neo4j.yml`（3 database 作成スクリプト）
- [ ] env: `BOM_NEO4J_URI`, `BOM_NEO4J_USER`, `BOM_NEO4J_PASSWORD`

### Phase 1: ドメインストア（2–3日）

- [ ] `Neo4jDomainStore(graph_id, driver)` — MERGE で upsert
- [ ] ingest パイプラインを Neo4j 向けに接続
- [ ] `tests/test_neo4j_domain_store.py`

### Phase 2: Cypher executor（1–2日）

- [ ] `execute_domain_cypher()` を neo4j driver 実装に差し替え
- [ ] 既存 `tests/test_cypher_executor.py`, `test_cypher_builder.py` を Green に
- [ ] `cypher-engine-profile.json` 更新 + `sync_ontology.py`

### Phase 3: フェデレーションファサード（1日）

- [ ] `Neo4jGraphStore` = 3 × `Neo4jDomainStore`
- [ ] `analysis.py` / `federation API` / `demo_federation.py` 動作確認
- [ ] `shortest_supply_path`: BFS 維持 or Neo4j `shortestPath` 検討

### Phase 4: Hybrid / Vector 方針（0.5–2日）

**推奨（A）:**

- [ ] `bom_hybrid_query` 削除
- [ ] デモ: DuckDB `material LIKE '%brass%'` + `bom_supplier_impact` に置換
- [ ] `UnifiedBomContextStore` → `ComponentMasterStore`（DuckDB のみ）にリネーム

**残す場合（C）:**

- [ ] vector だけ LanceDB テーブル1つ残存（グラフは Neo4j）— 説明コストは残る

### Phase 5: ドキュメント・記事整合（1日）

- [ ] `docs/project-layout.md`, runbook 更新
- [ ] 第3部記事: Lance 説明節を Neo4j + Docker 手順に差し替え（**別 PR**）
- [ ] AGENTS.md / README

---

## 8. テスト戦略

| 種別 | 内容 |
| :--- | :--- |
| 単体 | `cypher_builder`, `schema` validation（現行維持） |
| 統合 | Testcontainers Neo4j or `docker compose up` in CI |
| E2E | `demo_federation.py --reset`, `pytest tests/test_federation_api.py` |
| 回帰 | supplier SUP-002 → COMP-* → PROD-* → PROC-* の既知パス |

---

## 9. リスクとトレードオフ

| 項目 | Lance 現状 | Neo4j 移行後 |
| :--- | :--- | :--- |
| ローカル起動 | ファイルのみ（軽い） | Docker + JVM（重い） |
| 説明コスト（記事） | 高（Lance 未知） | 低（Neo4j 既知） |
| Cypher 互換 | サブセット | フルに近い |
| CI | 簡単 | Neo4j コンテナ必要 |
| シーズン1 連続性 | 弱い | 強い |
| embedded / サーバーレス | ◎ | △（Aura または Docker） |

**記事・教育目的** なら Neo4j 有利。**リポジトリを最小依存で配布** したいなら Lance 有利。

---

## 10. 第3部記事への示唆（実装変更は別途）

記事側で強調すべきは Lance ではなく:

1. `ontology/` + `domains/` + `app/federation/` の **二層境界**
2. `graph_contract.yaml` + `query-catalog.json`
3. 決定論的ツール連鎖（`bom_supplier_impact` 等）
4. Agent Skill の SSOT 生成

ストレージは **「Neo4j をドメイン別 DB で3つ — Docker Compose で起動」** 程度で足りる。

---

## 11. 関連ドキュメント

- シリーズ記事レビュー: `instructions/feedback-20260707-01.md`
- リポジトリ: `docs/project-layout.md`, `docs/federation-demo-runbook.md`, `docs/ontology-on-lance.md`（移行後は `ontology-on-neo4j.md` 等に）

---

## 12. 推奨判断（まとめ）

1. **Neo4j 移行は、フェデレーション設計を変えずに記事の説明効率を上げられる。**
2. **LanceDB は実際に使われているが、本筋はグラフ CRUD + lance-graph Cypher executor。**
3. **semantic similarity search（`bom_hybrid_query`）はデモ用 SHA256 ベクトルであり、シリーズの Must ではない。移行時に削除 or DuckDB 代替が妥当。**
4. **移行の作業中心は `app/storage` + `cypher_executor` + Docker。ontology / analysis / skills の契約構造は維持。**
