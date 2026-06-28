# 執筆企画: 真マルチモーダルデータ基盤（Lance × DuckDB）— 2部構成

**位置づけ:** World Model × Lance シリーズの **入口2本**（3部作の前に単独公開可）。Graph RAG / Season 0–3 とは無関係。**ODS という語は出さない**。

**読者:** 分散データ・Agentic AI・製造データに関心がある実装者（ODS コミュニティ参加者が読んでも「Pull・版・同居」の話として通じる）。

**根拠文献:**

| 資料 | 使い方 |
| :--- | :--- |
| `raw/lancedb/2605.21800.md` | **Lance 採用理由**（§3.1 Data Bottlenecks, Fig.3 数値） |
| `raw/lancedb/make-your-sql-workflows-multimodal-with-lancedb-x-duckdb.md` | **DuckDB × Lance**（drift、SQL、image_bytes） |
| `raw/lancedb/stable-worldmodel-*.md` | 数値・H200 スループットの補足（任意） |

---

## 2部構成

| 部 | ファイル | タイトル | 焦点 |
| :---: | :--- | :--- | :--- |
| **前編** | `articles/2026-07-06-multimodal-data-foundation-lance-duckdb.md` | 真マルチモーダルデータ基盤とは何か — 世界モデル研究が Lance を選んだ理由 | 問題・WM・MP4/HDF5・**なぜ Lance**・チェックリスト |
| **後編** | `articles/2026-07-13-multimodal-lance-duckdb-query-surfaces.md` | 同じ Lance ファイルを LanceDB と DuckDB で使う — 真マルチモーダルの query 面 | **LanceDB vs DuckDB**・SQL・スキーマ2例 |

相互リンク: 各記事の概要・おわりにで前後編を参照。Zenn slug はファイル名から自動（リンクは `/yohei1126/articles/...`）。

---

## thesis（2部通し）

1. **真マルチモーダル** = bytes・metadata・embedding・（必要なら）action が **同じ版で同居** し **random access** できること  
2. **世界モデル学習** はその要求の **過酷な例** → MP4/HDF5 → Lance（論文 empirics）— **前編**  
3. **LanceDB** = 検索・ML loader。**DuckDB** = SQL 分析・JOIN — **同じ Lance ファイル** — **後編**  
4. ODS 用語は使わないが、**3系統 glue の drift** は distributed data 読者にも刺さる  

---

## 前編 構成

| § | 内容 |
| :---: | :--- |
| 1 | vec DB + object store 分割、drift |
| 2 | WM がデータに求めるもの（~25%） |
| 3 | MP4/HDF5 vs Lance（Fig.3 数値） |
| 4 | なぜ Lance か（5項） |
| 5 | stable-worldmodel シグナル |
| 6 | チェックリスト5項目 |

## 後編 構成

| § | 内容 |
| :---: | :--- |
| 1 | 前編おさらい — query 面の必要性 |
| 2 | 3層役割分担 |
| 3 | DuckDB × Lance 5要点 + SQL |
| 4 | LanceDB 側（対照表） |
| 5 | スキーマ2例（カタログ / trajectory） |
| 6 | query 面チェックリスト +3 |

---

## 数値（前編に必須）

Push-T（論文 Fig.3, samples/sec）:

| Format | local | S3 |
| :--- | ---: | ---: |
| HDF5 | 1,416 | 9 |
| Video MP4 | 1,331 | — |
| Lance | 4,815 | 3,184 |

---

## 成功基準

- [ ] ODS 未読でも読める
- [ ] ODS 経験者が「Pull 前の中身の置き方」として理解できる
- [ ] Lance 採用理由が **論文 empirics** に根拠づいている（前編）
- [ ] DuckDB 連携が **ブログ5要点** に沿っている（後編）
- [ ] WM は前編のみ（全体の ~25%）

---

## 公開後

- `season-wm-lance-series-plan.md` 第1部執筆時に前編へリンク可
- 7月会合前の「書いておく2本」として使用可
