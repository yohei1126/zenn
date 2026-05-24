---
title: "判断の証跡 — CVは座標だけ、物理エンジンがリスクを決め、BLAKE3+Ed25519で連鎖する"
emoji: "🔏"
type: "tech"
topics: ["rust", "edge", "security", "onnx", "oss"]
published: false
---
<!-- markdownlint-disable MD013 MD060 -->

## この記事について

エッジ AI のデモでは「検知した！」が主役になりがちですが、保険・労働安全・港湾規制の現場では **「その記録を第三者が信じられるか」** が先に問われます。暗号署名があっても、**何を署名したか**（モデルの確信度か、測定値か）で証拠能力は変わります。

筆者は [EdgeSentry](https://github.com/edgesentry) の [edgesentry-rs](https://github.com/edgesentry/edgesentry-rs) とエッジ製品 [clarus](https://github.com/edgesentry/clarus)、CV アダプタ [specula](https://github.com/edgesentry/specula) で、**判断・封印・検証**を分離したスタックを組んでいます。本記事はその技術選択を、特定の顧客案件や公募に依存しない形で説明します。

---

## 背景：「AI が危ないと判定した」は証拠になりにくい

多くの映像ベース安全システムは、エンドツーエンドの深層学習に **危険度の分類**まで任せています。問題は次のとおりです。

- モデル更新で同じ映像でも出力が変わる（再現性が弱い）
- 確信度は校正されていても、**物理量（距離・TTC）ではない**
- 監査人・保険調査では「なぜその閾値か」がブラックボックスになる

対照的に、産業安全や海事では **測定可能な量**（クリアランス 3.2 m、TTC 2.0 s）と **公開規程の閾値** の組み合わせが求められます。ここを OSS で実装するのが、本スタックの出発点です。

---

## 原則：CV は座標、物理が判断、監査が封印

```text
Camera / センサ
      │
      ▼
┌──────────────────┐
│  CV adapter       │  specula: YOLO + ONNX Runtime + トラッキング
│  役割: クラスと   │  GPU ベンダー非依存・エアギャップ可
│        座標だけ   │
└────────┬─────────┘
         │  EntityFrame JSONL
         │  { id, class, x_m, y_m, vx, vy, confidence }
         ▼  ←── ここが境界。CV はリスクを決めない
┌──────────────────┐
│  Rust 物理・      │  edgesentry-rs: TTC, 制動距離, ゾーン
│  ルールエンジン   │  決定論・再現可能
└────────┬─────────┘
         │  RiskEvent
         ▼
┌──────────────────┐
│  AuditRecord      │  BLAKE3(payload) + Ed25519 + prev_hash 連鎖
│  → WORM / R2      │
└──────────────────┘
         │
         ▼（任意・非同期）
┌──────────────────┐
│  LLM 説明         │  規制条文の自然言語化（スコアは変更しない）
└──────────────────┘
```

CV が 0.3 m ずれても、物理エンジンの誤差は **座標誤差の大きさに比例**します。パターン認識の「不確実性がそのまま危険度に乗る」構造ではありません。設計メモ: [cv-layer-strategy.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/products/clarus/analysis/cv-layer-strategy.md)。

---

## OSS スタックの選び方（エッジ向け）

| 層 | 採用例 | 理由 |
|----|--------|------|
| 検出 | YOLO v11 (Ultralytics, Apache 2.0) | ARM エッジでも実用精度 |
| 実行 | ONNX Runtime | NVIDIA / クラウド API 不要 |
| 追跡 | BoT-SORT / ByteTrack | オクルージョン多い現場 |
| 座標 | OpenCV (PnP) | 単眼カメラから地上座標 |
| 出力 | EntityFrame → UDP / JSONL | エンジンは CV 非依存 |

[specula](https://github.com/edgesentry/specula) はこの適合層を担い、[edgesentry-ingest](https://github.com/edgesentry/edgesentry-rs) が標準フレームに載せます。ベンダー CV を差し替えるときも、**EntityFrame 契約**さえ守ればエンジンはそのままです。

---

## 監査レコード：何を連鎖するか

PoC では単一ティアの `AuditRecord` に、デバイス ID・単調増加 sequence・タイムスタンプ・payload の BLAKE3 ハッシュ・Ed25519 署名・前レコードハッシュを含めます。

```text
AuditRecord {
  device_id
  sequence          // 0, 1, 2, …
  timestamp_ms
  payload_hash      // BLAKE3(RiskEvent JSON)
  signature         // Ed25519
  prev_record_hash  // 改ざんすると以降すべて無効
  object_ref        // 例: "risk-event:{rule_id}"
}
```

CLI で全件検証:

```bash
eds audit verify-chain --chain /path/to/chain.jsonl
```

HTTP でも第三者検証用エンドポイントを公開できます（例: `clarus.edgesentry.io` の verify API）。**「署名できる」ことと「法廷・監督官庁が受理する」ことは別問題**なので、シンガポール Evidence Act s.116A などの要件マッピングは [legal-admissibility.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/products/clarus/analysis/legal-admissibility.md) に整理しています（法律助言ではなくエンジニアリングチェックリストです）。

---

## エッジ封印とクラウド解釈の分離（将来形も含む）

理想的には次の二段です。

1. **エッジ（同期）** — 測定値をその場で封印。プロファイルバージョンも記録（後から「どの閾値が有効だったか」を証明するため）  
2. **クラウド（非同期）** — どの rule_id・規程条項に該当するか、LLM による引用文、月次レポート  

測定と法的解釈を別レコードにすると、保険者は **物理事実**だけを先に検証できます。詳細な二段構造は [audit-record-design.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/products/clarus/analysis/audit-record-design.md) を参照。

現行 PoC ではエッジ上でルール評価まで行い 1 レコードにまとめる簡略形ですが、**改ざん検知の性質は同じ**です。

---

## 実測：Raspberry Pi 5 クラスでも回る理由

エッジ向けの訴求ポイントは、クラウド GPU ではなく **SWaP（サイズ・重量・電力）** です。実測例（開発ボード上）:

| 指標 | 目安 |
|------|------|
| デーモン RSS | 約 30 MB（DuckDB + 監査連鎖込み） |
| バイナリサイズ | 約 36 MB（DuckDB・暗号同梱） |
| CPU（アイドル付近） | 約 1% 台 |

DuckDB はエッジの **ローカル運用キャッシュ**、ブラウザ分析は **DuckDB-WASM**（[arktrace](https://github.com/edgesentry/arktrace)）、バッチは **Lance + R2 publish**（[indago](https://github.com/edgesentry/indago)）——同じデータモデルを層で分けています。

---

## DomainProfile：規程をコードにする

「正しい状態」はドメインごとに違います（港湾安全、BCA 省エネ閾値、船舶行動ベースラインなど）。エンジンは共通で、**DomainProfile** だけ差し替えます。プロファイルは公開規程から起こしたルールセットを OSS として配布し、**現場校正データ**を commercial 側に置く Red Hat 型の切り分けも検討しています（[domain-agnostic-platform-thesis.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/strategy/domain-agnostic-platform-thesis.md)）。

---

## ISO/IEC 42001 Annex A.4 との接続（エネルギー制御ではない）

AI ガバナンス標準の **A.4 リソース**は、HVAC を直接制御する話ではなく、**データ・ツール・計算資源・人の能力が文書化・監査可能か**に焦点があります。EdgeSentry は「省エネ SaaS」ではなく、**ingest provenance・profile manifest・エッジのリソース表・HITL 署名**を証跡として出す立場です（[iso-42001-a4-resource-governance.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/strategy/iso-42001-a4-resource-governance.md)）。自社が 42001 認証済みであると主張はしていません。

---

## 3 本シリーズとの関係

| 記事 | 焦点 |
|------|------|
| [判断の再現性](https://zenn.dev/yohei/articles/2026-05-19-reproducible-judgment-metrics) | メトリクス artefact・CI publish |
| [判断の説明](https://zenn.dev/yohei/articles/2026-05-19-explainable-judgment-score-llm-separation) | スコア固定 + グラフ/LLM 分離 |
| **本記事** | エッジ封印 + verify |

---

## まとめ

証跡の質は暗号アルゴリズムだけで決まりません。**CV に判断を任せない**、**物理・ルールで決定論的に判定する**、**その結果だけを連鎖署名する**——この順序が揃って初めて、「AI 検知システム」ではなく **測定と規程に基づく記録システム**として語れます。OSS（Rust・ONNX・YOLO）で足りる部分と、現場校正で差がつく部分を分けるのも、同じ思想の延長です。

---

## 参考リンク

- [edgesentry-rs](https://github.com/edgesentry/edgesentry-rs) — 監査・ingest・profile・CLI `eds`  
- [clarus](https://github.com/edgesentry/clarus) — エッジデーモン・デモ  
- [specula](https://github.com/edgesentry/specula) — CV → EntityFrame  
- [cv-layer-strategy.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/products/clarus/analysis/cv-layer-strategy.md) — 責務分離の詳細  
- [legal-admissibility.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/products/clarus/analysis/legal-admissibility.md) — 証拠能力の要件マップ
