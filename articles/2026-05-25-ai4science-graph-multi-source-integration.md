---
title: "AI for Science 向け — グラフは「RAGの検索器」より先に、エッジの出所と multi-hop の版を固定する"
emoji: "🕸️"
type: "tech"
topics: ["aiforscience", "graphrag", "knowledgegraph", "parquet", "reproducibility", "oss"]
published: false
---
<!-- markdownlint-disable MD013 MD060 -->

## この記事について

生命科学・材料・地球観測など、**複数ソースの観測データ**を AI で扱う研究では、「知識グラフ」「Graph RAG」という語がよく出ます。一方で現場では、**Neo4j を常時立ててエージェントに聞かせる**構成と、**バッチで Parquet にパスを書き出し、論文・監査はその artefact を正とする**構成が混在し、再現性の話が抜け落ちがちです。

筆者は [indago](https://github.com/edgesentry/indago) で、AIS・制裁リスト・ニュース（GDELT）などを取り込み、**グラフ上の multi-hop パスをスコアリングと説明の両方に使う** OSS パイプラインを運用しています。ドメインは海事 OSINT ですが、パターンは **「実験室が複数 DB・文献・測定ログを統合する」** 研究と同型です。本記事は、AI for Science コミュニティ向けに **グラフ・マルチソース統合** を、SaaS 統合の話ではなく **データ契約と再現性** の観点で翻訳します。

関連: 判断の三層分離は [スコアと LLM の分離](2026-05-19-explainable-judgment-score-llm-separation.md)、メトリクス凍結は [判断の再現性](2026-05-19-reproducible-judgment-metrics.md)。

---

## 1. 研究現場で起きていること（海事でも創薬でも同じ）

| 悩み | 典型例（分野横断） |
|------|-------------------|
| ソースごとにスキーマが違う | 測定装置 CSV・公開 DB・論文抽出 JSON |
| 「つながり」はあるが根拠が薄い | 同名エンティティの突合ミス |
| デモは Graph RAG で動くが、論文の数値と合わない | 検索のたびに参照文献が変わる |
| GPU クラスタはない | 週次バッチとノートブックだけ |

AI for Science の政策文書でも、**研究データ基盤**と**計算資源**が課題として繰り返されます。グラフは「賢く検索する」以前に、**エッジをいつ・どのシードから生成したか**が研究の再現性の一部になります。

---

## 2. 二つのグラフ・アーキテクチャ

```text
┌─────────────────────────────────────────────────────────────┐
│  A. 対話型 Graph RAG（よく見るデモ）                          │
│  クエリ → ベクター/グラフ検索 → LLM が回答                    │
│  リスク: 検索結果の揺れが「結論」に見える                      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  B. バッチ統合 + パス artefact（本記事の推奨パターン）         │
│  ingest → 正規化 → グラフ構築 → スコア/パスを Parquet に固定   │
│  読み取り: DuckDB / WASM UI / ノートブック                    │
│  LLM: 任意・下流（ナレーションのみ）                           │
└─────────────────────────────────────────────────────────────┘
```

筆者の過去記事 [SaaS分断とグラフRAG](20250815_why_graph_rag.md) は主に **A の戦略・組織** の話でした。運用に入ると **B** が必須です。Klarna 型の常時グラフ DB も B の一形態ですが、**小規模ラボ**では B を **Parquet + 週次 CI** で足りることが多いです。

---

## 3. マルチソース統合の「契約」— ノード・エッジ・パス

indago では、グラフを次の **3 層の artefact** に分けて書き出します（[ref-knowledge-graph.md](https://github.com/edgesentry/indago/blob/main/docs/ref-knowledge-graph.md)）。

| Artefact | 中身 | 研究での対応イメージ |
|----------|------|----------------------|
| `{region}_graph_nodes.parquet` | Vessel, Company, … | 遺伝子・化合物・論文著者ノード |
| `{region}_graph_edges.parquet` | OWNED_BY, SANCTIONED_BY, … | 相互作用・所属・引用 |
| ウォッチリストの `ownership_chain` | MMSI ごとの JSON パス | 「このサンプルがどの経路で表型に届くか」 |

**シードの版管理**が要点です。船舶所有関係は [`config/equasis/ownership_seed.csv`](https://github.com/edgesentry/indago/blob/main/config/equasis/README.md) のように **git 管理の CSV** から CI でエッジを生成します。論文では「補足データ S1: seed コミット `abc123`」と書ける状態を作ります。

```text
公開 CSV / DB ダンプ
        ↓  ingest（バージョン固定）
Lance / DuckDB 上のグラフ
        ↓  pipelines.knowledge_graph --export
Parquet（nodes / edges / paths）
        ↓  publish
第三者が同じコミット + 同じ入力で再実行可能
```

ストレージは Lance 列指向（`graph_store.py`）。**本番で常時 Neo4j を叩く必要はない** — クエリ API（`KnowledgeGraph.query_sanctions_path`）は開発・検証用で、本番の「正」は **publish 済み Parquet** です。

---

## 4. スコアに効くグラフと、説明用のグラフを同一契約にする

Graph RAG だけを先に入れると、よくある失敗は次のとおりです。

1. **RAG がランキングも返す** — 文献検索の揺れが「重要度」になる  
2. **グラフは説明用、スコアは別モデル** — パスとスコアが矛盾する  
3. **LLM がパスを言い換える** — 監査で無効  

indago では `compute_composite_scores()` が **グラフリスク成分** を合成スコアに含め、同じ run で **`ownership_chain` をウォッチリスト列に埋め込み**ます。UI（[arktrace](https://github.com/edgesentry/arktrace)）は **検出しない・読むだけ** です。

| 層 | 役割 |
|----|------|
| バッチ | スコア・順位・パス JSON を決定 |
| Parquet | 機械可読な根拠 |
| UI / SHAP | 人間の理解 |
| LLM（任意） | brief の下書きのみ |

これは創薬で「活性予測モデル」と「メカニズム説明のパス」を **同じ run ID** で束ねるのと同じ発想です。

---

## 5. AI for Science 研究者向けチェックリスト

論文・SPReAD 計画・ラボ Wiki に、そのまま貼れる問いです。

- [ ] **エッジの出所** — 各リレーションタイプの入力ファイルとバージョンは？  
- [ ] **マルチソースの ingest 順序** — パイプラインカタログ（ステップ一覧）は固定か？  
- [ ] **パスの正** — multi-hop は毎回オンライン計算か、publish 済み JSON か？  
- [ ] **スコアと検索の分離** — ランキングを変えられるのはバッチだけか？  
- [ ] **再現コマンド** — `git checkout` + `workflow run` + `metrics/YYYYMMDD.json` の trio が示せるか？  

---

## 6. 小規模ラボへの最小構成

| コンポーネント | 推奨 |
|----------------|------|
| 計算 | GitHub Actions + 自前サーバ or 無料枠（GPU 不要の週次バッチ） |
| ストレージ | Parquet + オブジェクトストレージ（R2 / S3 / オンプレ MinIO） |
| 分析 | DuckDB（CLI または WASM） |
| グラフ | 常時クラスタより **export Parquet** |
| LLM | 任意・ローカル（説明のみ） |

次の記事 [小規模ラボ向け DuckDB + Parquet + GitHub Actions](2026-05-25-ai4science-duckdb-parquet-github-actions-small-lab.md) で CI の具体例を書きます。

---

## 7. まとめ

AI for Science でグラフを扱うとき、**「Graph RAG を入れた」こと自体は成果にならない** ことが多いです。成果になるのは、**マルチソース ingest・エッジのシード・multi-hop パス・スコア** がひとつの publish run に束ねられ、第三者が **同じ artefact** を再検証できることです。

筆者のドメインは海事ですが、**エッジの出所・パスの版・スコアとの分離** は、文献グラフ・パスウェイ・観測ネットワークでも同じです。コミュニティでは「モデル選び」の前に **データ契約の設計** を翻訳する役割が、データエンジニアリング出身の実装者に向いています。

---

## 参考リンク

- [indago ref-knowledge-graph](https://github.com/edgesentry/indago/blob/main/docs/ref-knowledge-graph.md)  
- [arktrace ownership chain UI](https://github.com/edgesentry/arktrace/blob/main/docs/ref-ownership-chain-ui.md)  
- [文科省「AI for Scienceの推進に向けた基本的な戦略方針」](https://www.mext.go.jp/a_menu/jinzai/ai_for_science/index.htm)  
- [AWS Japan: AI for Science の歩き方 #1](https://zenn.dev/aws_japan/articles/ai4s-01-start-2026) — 研究者向け入門シリーズ
