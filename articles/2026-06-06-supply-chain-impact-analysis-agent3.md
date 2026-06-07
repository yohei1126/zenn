---
title: "組織の境界を越えるAIエージェントの知識連携 - サプライチェーン影響分析エージェントの実装（実装編）"
emoji: "🛠️"
type: "tech"
topics: ["ontology", "knowledgegraph", "federation", "llm", "supplychain"]
published: false
---

:::message
この記事は、エンタープライズにおける組織分断された複数データドメインの連携と、AIエージェントによるクエリ時論理フェデレーションをテーマにした、3部構成のシリーズ記事（シーズン2）の **第3部** です。

* **第 1 部**：[分断されたグラフと影響分析の課題（背景編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)
* **第 2 部**：[組織境界を維持する論理フェデレーション（設計編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2)
* **第 3 部**：[サプライチェーン影響分析エージェントの実装（実装編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3)（本記事）

※ シーズン1（仮想グラフの基本概念、AIエージェントでの有効性、変更管理）は以下からご覧いただけます。
* [第1部 Snowflake / Databricks / Google が挑む仮想グラフ戦略](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)
* [第2部  AIエージェントの知識表現と推論になぜグラフが使われるのか？](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2)
* [第3部 物理グラフDBを独自開発するための変更管理と安定運用戦略](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3)
:::

## 概要

前回の [第2部：設計編](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2) では、設計・製造・調達のデータ境界を維持したまま、クエリ実行時にのみ共通IDで論理結合する「論理フェデレーション（Logical Federation）」の設計原則を解説しました。

最終章となる第3部では、この論理モデルを **Neo4j**（グラフデータベース）および **DuckDB** を用いてローカル環境にどう実装したか、実際のコード構造をもとに解説します。

Pydanticによるスキーマ検証、各部門の「越境書き込み」を防ぐドメインガード、そしてPythonとNeo4jドライバーによるクエリ時フェデレーションとエージェント連携の具体的なコードと実装ディテールに迫ります。

---

## 1. 設計から実装へのマッピング方針（4大コア論点）

第3部の具体的なソースコード構造に入る前に、第2部で論じた「4つのコア論点」をどのように実装にマッピングしたのか、その基本方針を以下に整理します。

本アーキテクチャでは、単一のNeo4jインスタンス上で **複数データベース（Multi-Database：`ebom`, `routing`, `sourcing`）** 機能を用いることで、物理分離とセキュリティ境界を論理的かつシンプルに実現しています。

| 第2部の設計論点 | 実装における具体的アプローチ（重要な論点） | 記事における解説の主眼 |
| :--- | :--- | :--- |
| **① データ所有権（Data Ownership）の保証** | **リポジトリ内のコード境界 (`domains/`)**<br>各部門（ドメイン）が自律してインジェスト処理を定義できるよう、ディレクトリおよびコード境界を分離。`domains/registry.py` により越境データの書き込みをアプリ側で自動検証・遮断します。 | 各ドメインの「スキーマ主権」を崩さず、データの一元管理に伴う組織的衝突をいかに回避しているかを解説します。 |
| **② セキュリティ境界（Security）の維持** | **Neo4j 複数データベースによる物理分離**<br>センシティブな調達リスクなどのデータは、独立した物理データベースとして稼働する `sourcing` データベース等へ分割。接続ドライバーレベルでアクセス境界を制御します。 | 物理的に同じNeo4jインスタンスを共有しつつも、アクセス制御やデータ運用を完全に分離するセキュリティ境界の構築を説明します。 |
| **③ クエリ品質（Query Quality）と信頼性** | **決定論的ツール (`app/tools.py`) によるCypherのカプセル化**<br>LLMによるアドホックなCypher生成を一切排除し、事前に動作・安全性が検証された「名前付きクエリカタログ」としてツール側（API）にカプセル化。AIエージェントには実行計画の策定（ツール連携）のみを担わせます。 | LLMのハルシネーションや構文エラーを防ぎ、ミッションクリティカルな影響波及分析を100%安全かつ正確に動作させる仕組みを提示します。 |
| **④ 運用の容易さ（Ease of Operation）** | **Docker Composeによるローカル起動環境の提供**<br>巨大な共有データベースサーバ群の常時運用コストを避けるため、開発者向けに `docker-compose` 定義を提供。DuckDBとNeo4jマルチDBが即座に起動する環境を構築します。 | サーバーレスに近い手軽さで開発・テストフットプリントを最小限に抑える方法を示します。 |

※ 各クラスの内部処理や詳細なインジェストスクリプトは、実際のコンパニオンリポジトリをご参照ください。本記事では、この方針を具現化するための「骨格」となる実装コードに絞って紹介します。

---

## 2. 物理的なリポジトリ構成とドメインの分離

本実装では、各ドメインの自律性を保ちつつ共通スキーマを共有するため、以下のようなディレクトリ配置を採用しています。

```text
├── ontology/           # 技術的SSOT（共有スキーマ定義、共通バリデータ）
│   ├── contract/
│   │   └── graph_contract.yaml # 共有IDとフェデレーションの契約（Graph Contract）
│   └── schema.py       # Pydanticノード・エッジ定義
├── domains/            # 各部門（組織）ごとの専有領域
│   ├── ebom/           # 設計ドメイン用インジェスト・ルール
│   ├── routing/        # 製造工程ドメイン用インジェスト・ルール
│   └── sourcing/       # 調達ドメイン用インジェスト・ルール
├── app/
│   ├── storage/        # Neo4jデータベースアクセスドライバ
│   └── federation/     # クエリ時の論理結合・影響分析エンジン
└── data/
    └── bom.duckdb      # 共有 Component 属性マスタ (DuckDB)
```

データは、Docker Compose で起動された Neo4j の別個のデータベース（`sourcing`, `ebom`, `routing`）に書き込まれるため、他部門による意図しないデータ破壊や同一接続での競合は発生しません。

---

## 3. Pydanticによるスキーマと境界（越境）検証の強制

第2部で議論した通り、スキーマレスなグラフDBのデータ汚染を防ぐため、アプリケーションの境界線で厳密な検証（バリデーション）を行います。

:::message
**`ontology/` ディレクトリと「オントロジー」の対応**

* **古典的オントロジー**: 概念と関係の **意味・体系**（語彙の定義）。
* **[シーズン1第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) の再定義**: 上記に **守るべき制約** と **利用文脈** を含め、**変更管理可能な SSOT** として実装するもの。
* **本リポジトリでの具体化**:
  * `ontology/schema.py` — 型・エッジ接続ルール（**厳格層**。書き込み時に Pydantic で強制）
  * `ontology/contract/graph_contract.yaml` — Bridge Keys・フェデレーション経路・Quality Gates（**組織横断契約**。第2部の Graph Contract）
  * Agent Skill 用 JSON — 上記 SSOT から **自動生成**（Skill 内にハードコードしない）

シーズン1は **1グラフDB** が前提でしたが、本実装は **Neo4j マルチDB（ebom / routing / sourcing）** で組織境界を表現します。オントロジーの「型・制約」は全 DB で共有し、「どの DB がどのエッジを書けるか」は `domains/registry.py` が追加の境界として担います。
:::

### 3.1 ノードとエッジの定義 (`ontology/schema.py`)

`ontology/schema.py` には、全ドメインで共有される基本エンティティのPydanticモデルと、エッジ（関係性）の接続方向ルールを定義しています。これらは Neo4j にノードやエッジを書き込む際の厳格なゲートキーパーとして機能します。

```python
# ontology/schema.py（一部抜粋）
ALLOWED_EDGES: dict[EdgeType, tuple[NodeLabel, NodeLabel]] = {
    "USED_IN": ("Component", "Product"),      # 部品は製品に使われる
    "PRODUCED_BY": ("Product", "Process"),    # 製品は工程で製造される
    "SUPPLIED_BY": ("Component", "Supplier"), # 部品はサプライヤーに供給される
    "INPUT_OF": ("Component", "Process"),     # 部品は工程に投入される
}

class RelationEdge(BaseModel):
    source_label: NodeLabel
    source_id: str
    target_label: NodeLabel
    target_id: str
    edge_type: EdgeType
    properties: dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_domain_and_range(self) -> "RelationEdge":
        expected_source, expected_target = ALLOWED_EDGES[self.edge_type]
        if (self.source_label, self.target_label) != (expected_source, expected_target):
            raise ValueError(
                f"Edge constraint violation: {self.edge_type} only allows "
                f"{expected_source} -> {expected_target}"
            )
        return self
```

### 3.2 ドメイン単位の越境書き込みチェック (`domains/registry.py`)

`ontology/schema.py` が「世の中に存在してよい関係性のルール」を規定するのに対し、`domains/registry.py` は「**どのドメイン（組織）がどの関係性を書き込んでよいか**」の権限境界を制御します。

```python
# domains/registry.py（一部抜粋）
DOMAIN_GRAPHS: dict[GraphId, dict[str, set[str]]] = {
    "ebom": {
        "nodes": {"Component", "Product"},
        "edges": {"USED_IN"},
    },
    "routing": {
        "nodes": {"Component", "Process", "Product"},
        "edges": {"INPUT_OF", "PRODUCED_BY"},
    },
    "sourcing": {
        "nodes": {"Component", "Supplier"},
        "edges": {"SUPPLIED_BY"},
    },
}

def assert_edge_allowed_in_graph(graph_id: GraphId, edge_type: EdgeType) -> None:
    if edge_type not in DOMAIN_GRAPHS[graph_id]["edges"]:
        raise ValueError(f"edge {edge_type} is not allowed in graph {graph_id}")
```

### 3.3 非同期による参照整合性チェックの監査プロセス

更新処理時の同期バリデーションでは「データの形式やノード間の直接的な接続制約」をチェックしますが、ドメイン境界を越えた参照整合性（例：`sourcing` グラフ内の `Component.id` が DuckDB のコンポーネントマスタに本当に登録されているか）は、システムの疎結合性を維持するため非同期で監査します。

リポジトリ内では、`ontology/contract/graph_contract.yaml` に定義された `quality.on_ingest` ルール（`bridge_id_present_in_master` など）に従い、定期実行される監査スクリプトが以下のチェックを行います。

1. **孤立エッジの検出**: グラフ内でエッジ（関係性）の接続先ノードが存在しない、またはIDがマスタと不一致のレコードをスキャン。
2. **マスタ存在チェック**: 調達データ（`sourcing`）に登録された `Component.id` が、コンポーネントマスタである DuckDB テーブルに存在するかを検索。

```python
# 監査スクリプト（非同期チェック）の概念イメージ
def audit_referential_integrity(store: Neo4jGraphStore, master_db):
    # sourcing グラフからすべての部品IDを取得
    sourcing_components = {
        n["id"] for n in store.domain("sourcing").all_nodes() 
        if n["label"] == "Component"
    }
    
    # マスタDBに登録されている正当な部品IDを取得
    valid_master_ids = set(master_db.get_all_component_ids())
    
    # マスタに存在しない部品ID（整合性エラー）を検出
    orphans = sourcing_components - valid_master_ids
    if orphans:
        trigger_data_quality_alert(
            category="bridge_id_present_in_master_failed",
            message=f"マスタに未登録のブリッジIDが調達グラフ内で検出されました: {orphans}"
        )
```

この非同期の監査設計を導入することで、インジェスト処理をブロッキングさせることなく、マルチドメインにおけるデータの整合性を継続的に監視・担保する運用を確立しています。

---

## 4. クエリ時論理フェデレーションの実装

論理フェデレーションを行うファサードクラス `Neo4jGraphStore` は、3つのドメインに対応する個別の `Neo4jDomainStore` の読み取り用接続を管理します。

```python
# app/federation/graph_store.py（一部抜粋）
class Neo4jGraphStore:
    def __init__(self, uri: str = "bolt://localhost:7687", auth: tuple[str, str] = ("neo4j", "password")):
        self.driver = neo4j.GraphDatabase.driver(uri, auth=auth)
        self.domains: dict[GraphId, Neo4jDomainStore] = {
            graph_id: Neo4jDomainStore(graph_id, self.driver)
            for graph_id in DOMAIN_GRAPHS
        }

    def domain(self, graph_id: GraphId) -> Neo4jDomainStore:
        return self.domains[graph_id]
```

### 4.1 3段階の連鎖的クエリ実行 (`app/federation/analysis.py`)

サプライヤーの途絶が発生した際、影響を受けるノードを特定するためのステップは、決定論的にコード化されています。

```python
# app/federation/analysis.py（一部抜粋）
def analyze_supplier_disruption(store: Neo4jGraphStore, supplier_id: str) -> FederatedAnalysis:
    # 1. [Sourcing ドメイン] サプライヤーから影響部品（Component）をCypherでクエリ
    sourcing = query_sourcing_for_supplier(store, supplier_id)
    component_ids = {r["component_id"] for r in sourcing.rows}

    # 2. [EBOM ドメイン] 影響部品のIDリストから影響製品（Product）をCypherでクエリ
    ebom = query_ebom_for_components(store, component_ids)

    # 3. [Routing ドメイン] 影響部品のIDリストから影響を受ける工程（Process）や工場設備をクエリ
    routing = query_routing_for_components(store, component_ids)
    
    # 共通ID（Component.id）でPython側にてマージして集計結果を作成
    federated_rows = federated_impact_rows(store, supplier_id)
    
    # ルールベースでのリスク・代替案（Mitigation）の抽出
    single_source = _single_source_components(store, component_ids)
    problems = _build_problems(sourcing, ebom, routing, single_source, supplier_id)
    mitigations = _build_mitigations(sourcing, ebom, routing, single_source, supplier_id)
    score = _impact_score(sourcing, ebom, single_source)

    return FederatedAnalysis(
        scenario=f"supplier_disruption:{supplier_id}",
        supplier_id=supplier_id,
        problems=problems,
        mitigations=mitigations,
        impact_score=score,
        federated_rows=federated_rows,
    )
```

このフェデレーションロジックのポイントは、**「Cypherクエリの実行が、各ドメインのNeo4jデータベースに対して完全に分離されて実行されている」**点にあります。

`sourcing` データベースに対しては `SUPPLIED_BY` の関係性のみを問うCypherが投げられ、そこから得られた ID（`Component.id`）を仲介して、`ebom` や `routing` のデータベースに次のクエリを投げています。

これにより、一つのクエリで全ドメインを跨ぐ必要がなく、スキーマが非常に小さく、パフォーマンスの最適化が図りやすい状態を保てます。

---

## 5. エージェント用ツールの定義とフォールバック処理

AIプランナーが呼び出すAPI（ツール定義）は以下のようにカプセル化されています。

```python
# app/tools.py（一部抜粋）
def exploration_tool_definitions() -> list[dict[str, Any]]:
    return [
        {
            "name": "bom_supplier_impact",
            "description": "List components and products impacted by a supplier disruption.",
            "parameters": {
                "type": "object",
                "properties": {"supplier_id": {"type": "string"}},
                "required": ["supplier_id"],
            },
        }
    ]
```

### 5.1 クエリ最適化が効かない多ホップ探索のフォールバック

異なるデータベースを跨ぐ複雑な「製品構成（EBOM）から製造工程（Routing）を跨いだ最短経路探索（多ホップ）」が必要なケース（例: `shortest_supply_path`）では、個々のデータベースの単一Cypher処理に依存せず、**Pythonによるメモリ上での幅優先探索（BFS）による論理フェデレーション** を実行します。

```python
# app/federation/graph_store.py（一部抜粋）
def shortest_supply_path(self, from_component_id: str, to_product_id: str) -> list[dict[str, Any]]:
    # 各ドメインから対象の接続エッジ一覧をロード
    path_edge_types = {"USED_IN", "INPUT_OF", "PRODUCED_BY"}
    edges = self._edges_for_types(path_edge_types, ("ebom", "routing"))

    # メモリ上で隣接リストを構築
    adjacency = {}
    for edge in edges:
        # source ➔ target のマップを定義
        ...

    # Pythonによる決定論的なBFSアルゴリズムを実行してパスを返す
    ...
```

このように、単純なリレーション参照は個別のドメインDBにCypherでインプレース実行させつつ、ドメインをまたぐ複雑なトラバースはアプリケーション層（Python）側で柔軟に制御する、ハイブリッドなフェデレーション制御を行っています。

---

## 6. まとめ

3部にわたるシーズン2の連載を通じて、エンタープライズの組織現実とセキュリティを尊重しながら、迅速な有事の影響分析を実現する「論理フェデレーション」の実装ディテールを解説しました。

本記事で紹介した実装成果は、第2部で定義した**「4つのコア論点」**に対して以下のように具体的な解決手段を提示しています。

1. **① データ所有権（Data Ownership）の保証**:
   `domains/` 内にコードを分割し、`domains/registry.py` による越境エッジ・ノード制限ロジックを実装することで、他チームからの無秩序な変更を技術的に排除しました。各チームは、自分のドメインのスキーマとデータの「主権」を維持し続けられます。
2. **② セキュリティ境界（Security）の維持**:
   単一の Neo4j インスタンスを共有しつつも、`ebom`, `routing`, `sourcing` という独立した物理データベースとして運用することでセキュリティ境界を完全に維持。アクセス制御や運用の独立性を保証しています。
3. **③ クエリの品質（Query Quality）と信頼性**:
   `app/tools.py` で定義された決定論的なPython/Cypherツール（`bom_supplier_impact`等）をAIエージェントに提示し、LLMには計画策定（オーケストレーション）のみを委ねました。Text-to-SQL/Cypherにおける構文エラーや存在しない関係性をクエリするハルシネーションをゼロにし、ミッションクリティカルな影響範囲分析の正確性を担保しています。
4. **④ 運用の容易さ（Ease of Operation）**:
   複雑な手動のインフラプロビジョニングを排除し、Docker Composeを用いてローカル環境でミリ秒単位のフェデレーションクエリが検証できる実行環境を提供。フットプリントを抑え、容易な開発サイクルを担保しました。

「データを物理的に統合すること」と「意思決定のために論理的に繋ぎ合わせること」は別問題です。

各ドメインがデータの主権を維持したまま、AIエージェントの決定論的ツールとして結合し合う「論理フェデレーション」の実装パターンこそが、複雑なエンタープライズのシステムを持続可能（サステナブル）に保ちながら、有事に即座に対応できる現実的なデータ基盤の最適解です。

---

**連載一覧：**

* **第 1 部**：[分断されたグラフと影響分析の課題（背景編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)
* **第 2 部**：[組織境界を維持する論理フェデレーション（設計編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2)
* **第 3 部**：[サプライチェーン影響分析エージェントの実装（実装編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3)（本記事）
