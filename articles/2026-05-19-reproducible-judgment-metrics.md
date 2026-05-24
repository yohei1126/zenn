---
title: "判断の再現性 — MLメトリクスをREADMEに書かず、CIとオブジェクトストレージで凍結する"
emoji: "📊"
type: "tech"
topics: ["mlops", "githubactions", "duckdb", "dataengineering", "oss"]
published: false
---
<!-- markdownlint-disable MD013 MD060 -->

## この記事について

監査や第三者検証が求められるバッチ型の異常検知・リスクスコアリングでは、「今の精度は何％か」という数字そのものより、**同じ入力と手順で同じ判断が再現できるか**が問われることが多いです。

筆者は [EdgeSentry](https://github.com/edgesentry) プロジェクトで、マルチソースの公開データを取り込み、ウォッチリストを生成して公開する OSS パイプライン [indago](https://github.com/edgesentry/indago) を運用しています。本記事では、**ライブの Precision@50 やリードタイムを git の Markdown に書かない**という運用方針と、その裏側にある **GitHub Actions + R2 スナップショット + 解釈用スクリプト** の設計を、公募や顧客名に依存せずに説明します。

---

## 背景：「README に書いた数字」がすぐ嘘になる

バッチパイプラインを週次で回すと、次のような変更だけで評価指標が動きます。

- グラフのシードデータを足した（所有関係のエッジが増えた）
- 評価用の正例ラベル集合を更新した
- リージョン別のウォッチリストサイズの閾値を変えた

モデルの重みを再学習していなくても、**ランキングの上位50件に何が入るか**は変わり得ます。にもかかわらず、README や提案書に「P@50 = 0.62」と書いてしまうと、翌週の data-publish のあと、その文書はもう正確ではありません。

こうした問題は、クラウド DWH のダッシュボードだけを見ている組織でも起きます。違いは、**オンプレや主権バッチ**では「公式ダッシュボードの URL」すら社外に渡せないケースがあることです。だからこそ、**数値の正（source of truth）をどこに置くか**を先に決める必要があります。

---

## 設計原則

### 1. 閾値（gate）と実測（performance）を分ける

トライアル目標（例: P@50 ≥ 0.60）や CI の回帰検知しきい値（例: 前日比 −0.02）は、**どのリポジトリのドキュメントにも書いてよい**「契約上のゲート」です。

一方、**「いまの本番パイプラインの P@50 はいくつか」**はゲートではなく観測値です。観測値は git に固定しない。

### 2. 正は「最後に成功した publish の artefact」

indago では、週次（および手動）の `data-publish` ワークフローがパイプライン全体を実行し、終了時にメトリクスを R2 に書き出します。

| 置き場所 | 内容 | git に書く？ |
|----------|------|--------------|
| ドキュメント | 仕組み・閾値・手順 | 仕組みのみ |
| R2 `metrics/YYYYMMDD.json` | その日のスナップショット | いいえ |
| R2 `metrics/index.json` | 直近 N 日のインデックス | いいえ |
| CI アーティファクト | 単一 run のデバッグ用 JSON | いいえ |
| 提出用 PDF 凍結時のみ | その時点の数値をコピー | PDF だけ |

公開読み取り用の例（認証不要）:

```text
https://pub-e088008b61ee432b906ef710d52af28c.r2.dev/metrics/index.json
```

詳細は indago の [ref-data-publish-metrics.md](https://github.com/edgesentry/indago/blob/main/docs/ref-data-publish-metrics.md) を参照してください。

### 3. 人間とエージェントは同じコマンドで最新値を取る

ドキュメントを開いて数字を探すのではなく、**常に fetch スクリプト**を使います。

```bash
cd indago
uv run python scripts/fetch_publish_metrics.py --interpret
uv run python scripts/fetch_publish_metrics.py --days 7 --json
```

エージェント向けには [indago-interpret-metrics](https://github.com/edgesentry/indago/blob/main/.agents/skills/indago-interpret-metrics/SKILL.md) スキルが同じ手順をラップしています。CI 完了後のメール要約と R2 スナップショットの対応関係も、上記 ref ドキュメントに表形式でまとめてあります。

---

## パイプラインの流れ（抽象）

```text
[1] 多ソース ingest（AIS・制裁リスト・ニュース等）
         ↓
[2] 正規化・特徴量・グラフ構築
         ↓
[3] バッチスコアリング → リージョン別ウォッチリスト（Parquet）
         ↓
[4] バックテスト・リードタイム検証
         ↓
[5] R2 へデータ + metrics/YYYYMMDD.json を publish
         ↓
[6] メール通知（maintainer）・index.json 更新
```

ステップ [3] のスコアは **その run の入力データとコードのコミット**に束縛されます。第三者が再現するには、「どの workflow run URL で、どの `YYYYMMDD.json` を見たか」をセットで示すのが筋です。

11 ステップのカタログは [ref-pipeline-catalog.md](https://github.com/edgesentry/indago/blob/main/docs/ref-pipeline-catalog.md) にあります。

---

## 学び：モデル再学習なしで指標が動いた

運用で印象的だったのは、**Isolation Forest の再学習をしていない週**にも、公開 P@50 が変動しうることです。要因の例は次のとおりです。

- **グラフシードの拡充** — 公開の船舶所有データを CSV で取り込み、CI で `MANAGED_BY` / `OWNED_BY` エッジを生成。合成スコアのうちグラフ成分の重みが効いて、制裁に近いクラスタが上位に来やすくなる
- **正例ラベルの更新** — OFAC/EU/UN の評価マニフェストが増えると、リコールや P@50 の分母・分子の解釈が変わる
- **リージョンのスキップ** — ウォッチリストが小さすぎる地域はバックテストから除外される。除外リストの変化は「性能低下」ではない

つまり **「ML モデルを触ったから数字が変わった」だけが原因ではない** ということです。データエンジニアリングと評価設計の変更も、同じく「判断の再現性」の説明責任の対象になります。再現性を語るときは、**モデルバージョン**だけでなく **データ publish の run ID** をセットで示すのが誠実です。

---

## 読み取り専用 UI との役割分担

スコアリングと評価は [indago](https://github.com/edgesentry/indago)（バッチ）に集約し、分析 UI の [arktrace](https://github.com/edgesentry/arktrace) は **R2 に publish 済みの Parquet を DuckDB-WASM で読むだけ**です。フロントエンドに検出ロジックを載せないことで、

- デモで見ている数字が、必ず某回の publish と一致する
- UI のデプロイとパイプラインのデプロイを独立できる

という副次効果があります。メトリクスポリシーの要約は、commercial リポジトリ内の [ref-metrics-policy.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/ref-metrics-policy.md)（内部運用向け）にもあります。

---

## 他ドメインへの転用チェックリスト

| 問い | 推奨 |
|------|------|
| ライブ KPI を README に書いていないか？ | 閾値だけ README、実測は artefact |
| 第三者は同じ run を再実行できるか？ | workflow URL + manifest / 入力ハッシュ |
| ダッシュボードと git のどちらが正か？ | 1 つに決める（ここでは R2 スナップショット） |
| 指標が下がったとき、データかモデルか？ | スナップショット差分とリージョンスキップを先に見る |

---

## まとめ

判断の再現性は、「再現可能なスコアリング手順」と「その手順の出力を凍結したメトリクス artefact」の組み合わせで示せます。git は **コードとゲート** に使い、**観測された性能** は publish ごとの JSON と CI run に寄せる。シンプルですが、オンプレ・監査・OSS 公開を同時にやるチームでは効きます。

次の記事 [判断の説明](https://zenn.dev/yohei/articles/2026-05-19-explainable-judgment-score-llm-separation) では、**説明層（グラフ・SHAP・LLM）をスコアから切り離す** 設計を扱います。シリーズ最終回は [判断の証跡](https://zenn.dev/yohei/articles/2026-05-19-tamper-evident-judgment-audit-chain) です。

---

## 参考リンク

- [indago](https://github.com/edgesentry/indago) — バッチパイプライン・data-publish
- [arktrace](https://github.com/edgesentry/arktrace) — 読み取り専用分析 UI
- [ref-data-publish-metrics.md](https://github.com/edgesentry/indago/blob/main/docs/ref-data-publish-metrics.md) — メールと R2 フィールドの対応表
