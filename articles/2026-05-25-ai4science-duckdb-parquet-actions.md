---
title: "AI for Science 向け — 小規模ラボの週次パイプラインを DuckDB + Parquet + GitHub Actions で組む（GPU なし）"
emoji: "🧪"
type: "tech"
topics: ["aiforscience", "duckdb", "parquet", "githubactions", "dataengineering", "oss"]
published: false
---
<!-- markdownlint-disable MD013 MD060 -->

## この記事について

大学ラボ・スタートアップの研究グループでは、**クラウド GPU 常時起動**や **Databricks / Snowflake フルスタック**は予算・運用の両面で重いことが多いです。一方、観測データ・公開 DB・文献由来の CSV を **週次で統合し、評価指標を凍結する** 必要は、海事 OSINT でもゲノムでも共通です。

筆者は [indago](https://github.com/edgesentry/indago) で、**GPU なし**の GitHub Actions 上で 11 ステップ相当のパイプラインを回し、Parquet とメトリクス JSON を R2 に publish しています。分析 UI [arktrace](https://github.com/edgesentry/arktrace) は **DuckDB-WASM** で Parquet だけを読みます。本記事は、その構成を **AI for Science 向けのテンプレート** として一般化します（コードは概念レベル + 最小例）。

関連: [判断の再現性](2026-05-19-reproducible-judgment-metrics.md) · [グラフとマルチソース統合](2026-05-25-ai4science-graph-integration.md)

---

## 1. なぜ「小規模ラボ向け」か

| 制約 | よくある研究現場 | 本構成の答え |
|------|------------------|--------------|
| 予算 | GPU クラスタは grant 消化が早い | 週次 CPU バッチ + ストレージ数ドル/月 |
| 人員 | PI + ポスドク 1–2 名 | Actions が cron + 手動 dispatch |
| 再現性 | ノートブックだけ | **run ID + Parquet + metrics JSON** |
| データ主権 | 生データを海外 SaaS に載せられない | 自前バケット or オンプレ MinIO |
| 評価 | 論文の表とリポジトリの数字がずれる | README に数字を書かない運用 |

文科省の AI for Science でも **研究データ基盤**と**計算資源の計画**が SPReAD 等で問われます。ここでは **「計算資源 = 週次 CI + DuckDB」** という書き方の一例を示します。

---

## 2. 全体像

```text
┌──────────────────────────────────────────────────────────┐
│  GitHub Actions（週次 cron + workflow_dispatch）          │
│  uv / pip · pytest · パイプライン · バックテスト          │
└────────────────────────────┬─────────────────────────────┘
                             │ artefact upload
                             ▼
┌──────────────────────────────────────────────────────────┐
│  オブジェクトストレージ（R2 / S3 / MinIO）                │
│  score/{region}_watchlist.parquet                        │
│  metrics/YYYYMMDD.json · metrics/index.json              │
│  ducklake_manifest.json（ファイル一覧 + ハッシュ）          │
└────────────────────────────┬─────────────────────────────┘
                             │ HTTPS GET（認証なし or 限定）
                             ▼
┌──────────────────────────────────────────────────────────┐
│  読み取り層                                               │
│  · DuckDB CLI（ローカル検証）                             │
│  · arktrace: DuckDB-WASM + OPFS 同期                      │
│  · ノートブック: read_parquet('https://...')              │
└──────────────────────────────────────────────────────────┘
```

**原則:** 重い「判断」は CI 内のバッチだけ。ノートブックと UI は **読み取り専用**。

---

## 3. レイヤ設計

### 3.1 処理層 — DuckDB を「その週の作業 DB」に

リージョン（または実験条件）ごとに DuckDB ファイルを置き、ingest → 特徴量 → スコアを SQL / Python で流します。

```bash
# 例: パイプラインの一部（indago では run_pipeline.py がオーケストレーション）
uv run python run_pipeline.py --region singapore
```

カタログは [ref-pipeline-catalog.md](https://github.com/edgesentry/indago/blob/main/docs/ref-pipeline-catalog.md)（11 ステップ）。研究では例えば:

1. 公開 DB 取り込み  
2. 正規化・QC  
3. 特徴量  
4. グラフ / ネットワーク  
5. スコアリング → **候補リスト Parquet**  
6. バックテスト → **metrics JSON**  

### 3.2 配布層 — Parquet が「論文の補足 S2」

スコア付きテーブルは **Parquet** で固定します。CSV より型・圧縮・列投影に強く、DuckDB から直接読めます。

```sql
-- ローカル検証（研究メンバー全員が同じクエリを実行可能）
SELECT mmsi, confidence, ownership_chain
FROM read_parquet('singapore_watchlist.parquet')
ORDER BY confidence DESC
LIMIT 50;
```

### 3.3 公開層 — manifest で「どのファイルが正か」

arktrace は `ducklake_manifest.json` で **ファイル URL・サイズ・register_as** を一覧し、ブラウザ OPFS に同期します。研究公開では **Zenodo + manifest の SHA** でも同型です。

---

## 4. GitHub Actions の最小パターン

GPU 不要の週次 publish の骨格です（プロジェクト名は置き換え）。

```yaml
# .github/workflows/data-publish.yml（概念例）
name: data-publish
on:
  schedule:
    - cron: "0 2 * * 1"   # 月曜 02:00 UTC
  workflow_dispatch:

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - run: uv sync
      - run: uv run pytest -q
      - run: uv run python run_pipeline.py --all-regions
      - run: uv run python scripts/push_metrics_snapshot.py
      - name: Upload to object storage
        env:
          R2_ACCOUNT_ID: ${{ secrets.R2_ACCOUNT_ID }}
          # ...
        run: uv run python scripts/sync_r2.py push-all
```

**ポイント:**

| 項目 | 理由 |
|------|------|
| `pytest` を publish 前に | 壊れたパイプラインで metrics を上書きしない |
| `workflow_dispatch` | 論文締切前に手動で「凍結 run」を作れる |
| Secrets は書き込みのみ | 読み取りは公開バケット or 署名 URL |
| アーティファクト retention | デバッグ用に run 単位 JSON を GH に残す |

indago 本番では maintainer 向けメール + `metrics/YYYYMMDD.json` 更新まで含みます（[ref-data-publish-metrics.md](https://github.com/edgesentry/indago/blob/main/docs/ref-data-publish-metrics.md)）。

---

## 5. メトリクスを git に書かない

研究でよくある失敗は、README に「Accuracy = 0.82」と書き、翌週のデータ更新で **リポジトリの数字だけが嘘** になることです。

| 種類 | 置き場所 | git |
|------|----------|-----|
| 評価の**閾値**（例: P@50 ≥ 0.60） | ドキュメント | 可 |
| 評価の**実測**（その週の P@50） | `metrics/20260524.json` | 不可 |
| 論文・grant 提出 | PDF / 申請書に **凍結コピー** | スナップショットのみ |

取得コマンド（indago）:

```bash
uv run python scripts/fetch_publish_metrics.py --interpret
uv run python scripts/fetch_publish_metrics.py --days 7 --json
```

論文の Methods には **「指標は 2026-05-24 の workflow run `12345` と R2 の `20260524.json` から取得」** と書くのが筋です。

---

## 6. 読み取り UI — DuckDB-WASM で GPU なし閲覧

[arktrace](https://github.com/edgesentry/arktrace) はブラウザ内 DuckDB で `read_parquet('watchlist.parquet')` し、**500 件まで**を `ORDER BY confidence DESC` で表示します（スコア変更ロジックはフロントにない）。

研究ラボでは:

- **PI** — ブラウザで候補一覧と SHAP  
- **学生** — 同じ Parquet を Jupyter + DuckDB で検証  
- **レビュア** — manifest の URL から再ダウンロード  

の三層が、**同じ artefact** を指します。

---

## 7. コストの目安（オーダー）

| 項目 | 目安 |
|------|------|
| GitHub Actions | 公開リポなら無料枠内に収まる週次バッチ（要モニタ） |
| R2 / S3 | Parquet 数 GB 程度なら月額数ドル |
| DuckDB | OSS・ライセンスフリー |
| LLM | **必須ではない** — 説明が要る場合のみローカル llama.cpp |

GPU は **モデル再学習の月** だけクラウドを借りる、という割り切りも可能です。日次推論を回さない設計にすると、grant の計算資源欄も書きやすくなります。

---

## 8. SPReAD / 研究計画への書き方（例）

技術計画の一文例（コピー可・要調整）:

> 本研究のデータ処理は、週次 GitHub Actions 上の CPU パイプラインにより実行する。中間・最終成果物は Parquet およびバージョン付き metrics JSON としてオブジェクトストレージに保存し、再現は workflow run ID とファイルハッシュの組で第三者に示す。対話型分析は DuckDB によりローカルまたはブラウザ内で完結し、クラウド GPU 常時利用は不要とする。

---

## 9. チェックリスト

- [ ] パイプラインステップがカタログ化されている  
- [ ] publish 前にテストが走る  
- [ ] スコア付きテーブルは Parquet で固定  
- [ ] メトリクスは日付 JSON + index  
- [ ] README にライブ指標を書いていない  
- [ ] 論文・申請書は **凍結 run** を引用している  

---

## 10. まとめ

小規模ラボでも、**DuckDB + Parquet + GitHub Actions** で「観測科学向けの週次判断パイプライン」は組めます。GPU なしは **能力の制限ではなく、バッチ研究に合った設計選択** です。AI for Science では、モデルより先に **artefact の正と run ID** を決めるほうが、再現性と共同研究の両方に効きます。

---

## 参考リンク

- [indago ref-pipeline-catalog](https://github.com/edgesentry/indago/blob/main/docs/ref-pipeline-catalog.md)  
- [indago ref-data-publish-metrics](https://github.com/edgesentry/indago/blob/main/docs/ref-data-publish-metrics.md)  
- [arktrace DuckDB query layer](https://github.com/edgesentry/arktrace/blob/main/app/src/lib/duckdb.ts)  
- [判断の再現性（Zenn）](2026-05-19-reproducible-judgment-metrics.md)
