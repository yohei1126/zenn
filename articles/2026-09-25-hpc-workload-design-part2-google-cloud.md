---
title: "HPCワークロード設計の勘所（後編）：Google Cloudの既存機能を組み合わせて罠を突破する"
emoji: "🚀"
type: "tech"
topics: ["gcp", "hpc", "slurm", "computeengine", "architecture"]
published: true
---

:::message
**連載：Google Cloud での HPC ワークロード設計ベストプラクティス（全2回）**

Web/API向けに最適化されたクラウドエンジニアの「成功体験」をそのまま持ち込むと、HPC基盤はなぜ破綻するのか？ その物理特性とメカニズムを理解し、Google Cloudの既存機能を適切に組み合わせて解決するまでの実践ガイドです。

| 回 | 記事 | 主なテーマ |
| :--- | :--- | :--- |
| **第1回（前編）** | [クラウドエンジニアが直面する罠とHPCの本質](2026-09-25-hpc-workload-design-part1-fundamentals) | クラウドエンジニアが陥る6つの罠、HPCの特徴とWeb/APIの決定的ギャップ、満たすべき4大要件 |
| **第2回（後編）** | 本記事 | 罠を回避するGCP機能の組み合わせ（Compute/Network/Storage/Orchestration） |
:::

## 1. はじめに：前編の課題をGoogle Cloudでどう解決するか

[第1回（前編）](2026-09-25-hpc-workload-design-part1-fundamentals) では、Web/APIインフラの前提（マルチAZ冗長化、動的オートスケール、マネージドNFS、vCPU仮想化、Live Migration）をそのままHPCに持ち込んだ際に生じる以下の問題を整理しました。

* **問題1【配置】マルチAZ分散配置**：ゾーン間通信遅延によりバリア同期が遅延し、計算時間が大幅に延伸する。
* **問題2【スケール】MIGによる動的オートスケール**：計算途中のノード増減によりMPIプロセス全体が異常終了する。
* **問題3【ストレージ】単一マネージドNAS（NFS）依存**：数千プロセスのメタデータ集中とN-to-1バーストによりI/Oが待機状態に陥る。
* **問題4【コスト】耐障害設計なきSpot VM採用**：All-or-Nothing特性により、1台の中断で数十時間の計算状態が失われる。
* **問題5【仮想化】vCPUとコンテナによる過密集約**：SMTとNUMA不整合によるキャッシュ競合・メモリ帯域の競合で性能が低下する。
* **問題6【運用】Live Migrationへの依存**：移行時の数十ミリ秒のCPU一時停止によりノード間通信が途絶し、ジョブが強制終了する。

これらの課題を解決するために、オンプレミスのような専用機を独自に組み上げる必要はありません。Google Cloud の既存機能を適切に組み合わせることで、密結合HPCの物理要件を満たす基盤を構成できます。

本稿では、Google Cloudの公式ドキュメントやアーキテクチャガイドを踏まえ、各領域の機能をどのように組み合わせてHPC基盤を実現するかを解説します。

---

## 2. コンピュート設計：近接配置と物理コア専有

マルチAZによる通信遅延、vCPU競合、Live Migrationによる一時停止を、Google Cloudのコンピュート機能の組み合わせで解決します。

| 前編で整理した課題 | 発生する事象 | Google Cloud での解決策 |
| :--- | :--- | :--- |
| **問題1【配置】マルチAZ分散配置** | ゾーン間通信遅延（数ms）によりバリア同期が崩壊する | **Compact Placement Policy**<br>物理的に同一ラックスイッチ配下にVMを集約（Colocation） |
| **問題5【仮想化】vCPU集約とSMT** | ハイパースレッディングによるキャッシュ競合と性能低下 | **H3 マシンシリーズ**（SMT無効・88物理コア専有・DDR5）<br>※他シリーズの場合は `--threads-per-core: 1` |
| **問題6【運用】Live Migrationへの依存** | 移行時の一時停止によるハートビート途絶・ジョブ強制終了 | **`--maintenance-policy=TERMINATE`**<br>無停止移行を無効化し、クリーンな終了とスケジューラ再実行へ |

### 2.1 Compact Placement Policy による同一ラックスイッチへの集約

ゾーン間通信による遅延増大を回避し、ノード間レイテンシをマイクロ秒オーダーに抑えるため、Google Cloud の **Compact Placement Policy（近接配置ポリシー）** を適用します。

> **公式ドキュメント引用:**
> *“A compact placement policy specifies that your VM instances are placed physically close together inside the data center to reduce network latency. Compact placement policies are ideal for tightly coupled HPC workloads and high-performance distributed computing.”*
> — [Google Cloud Documentation: Define placement policies](https://cloud.google.com/compute/docs/instances/placement-policies)

```hcl
# TerraformによるCompact Placement Policyの定義
resource "google_compute_resource_policy" "hpc_compact_policy" {
  name   = "hpc-compact-placement"
  region = "us-central1"
  
  group_placement_policy {
    collocation  = "COLLOCATED"
    vm_count     = 64 # 同一ラックスイート内に集約するノード数
  }
}
```

このポリシーをインスタンス作成時に指定することで、物理的に同一のラックまたは同一のTop-of-Rack（ToR）スイッチ配下のホストにVMが集約配置（Colocation）されます。これにより、ゾーンをまたいだルーティング遅延を排除できます。

### 2.2 H3 マシンタイプによる物理コア専有とDDR5帯域の確保

vCPUの時分割共有による性能低下を避けるには、HPC向けに設計された **H3 マシンシリーズ** を採用します。

> **公式ドキュメント引用:**
> *“The H3 machine series is designed for compute-intensive High-Performance Computing (HPC) workloads like computational fluid dynamics (CFD), molecular dynamics, and weather forecasting. H3 VMs are powered by 4th Gen Intel Xeon Scalable processors (Sapphire Rapids) and DDR5 memory.”*
> — [Google Cloud Compute Engine Documentation: H3 machine series](https://cloud.google.com/compute/docs/compute-optimized-machines#h3_series)

* **物理コア1:1マッピング（SMT無効化済み）**: `h3-standard-88` では、88個の物理コアがそのまま88個のvCPUとして割り当てられています。ハイパースレッディングが無効化されているため、スレッド間でのキャッシュ競合（Cache Thrashing）が発生しません。
* **DDR5 メモリ**: CFDや気象予測など、メモリ帯域幅が性能上限を左右するワークロードで高いスループットを維持します。
* **他シリーズでの代替**: C3 や C2 を使用する場合は、作成時に明示的に `--threads-per-core=1` を指定してSMTを無効化します。

### 2.3 TERMINATE ポリシーによる Live Migration ジッターの排除

物理ホスト保守時のマイクロ停止によるジョブ停止を防ぐため、HPCクラスタのノードには明示的に **マイグレーションの無効化** を設定します。

> **公式ドキュメント引用:**
> *“For tightly coupled HPC workloads, the brief latency jitter introduced by live migration can disrupt node-to-node synchronization and cause MPI timeouts. To avoid this, configure the host maintenance policy to terminate instead of migrate.”*
> — [Best practices for running tightly coupled HPC applications](https://cloud.google.com/architecture/best-practices-for-tightly-coupled-hpc-applications)

```bash
# メンテナンス発生時にLive Migrationを行わず終了（TERMINATE）させる
gcloud compute instances create hpc-node-01 \
    --zone=us-central1-a \
    --machine-type=h3-standard-88 \
    --maintenance-policy=TERMINATE \
    --restart-on-failure \
    --resource-policies=projects/MY_PROJECT/regions/us-central1/resourcePolicies/hpc-compact-placement
```

密結合HPCでは、Live Migrationによる数十ミリ秒の一時停止で全ノードが同期エラーを起こすよりも、対象ノードを正常終了させ、後述するジョブスケジューラ（Slurm）によって最新チェックポイントから健全なノードで再起動する構成が安全です。

---

## 3. ネットワーク設計：高帯域化とレイテンシの極小化

ネットワーク遅延の揺らぎ（Jitter）や帯域不足を、Google Cloudのネットワークスタックの最適化によって解決します。

### 3.1 Tier_1 高帯域ネットワーキング（最大200Gbps）

Compute Engine では、デフォルトの帯域上限を超えて最大 200 Gbps の帯域を利用できる **Tier_1 ネットワーキング** が提供されています。

```bash
# Tier_1 ネットワーキングを有効化してVMを作成
gcloud compute instances create hpc-node-01 \
    --machine-type=h3-standard-88 \
    --network-performance-configs=total-egress-bandwidth-tier=TIER_1
```

AllReduce や境界値交換（Halo Exchange）など、ノード間で高頻度にデータ転送が発生する処理において、帯域飽和によるパケット破棄を防止します。

### 3.2 gVNIC と IDPF によるCPUオフロード

仮想NICには、VirtIO ではなく、Google の Titanium IPU に最適化された **gVNIC（Google Virtual NIC）** または **IDPF（Infrastructure Data Path Function）** を採用します。パケット送受信処理がハードウェアにオフロードされ、仮想化に伴うCPU負荷が低減されます。

### 3.3 Jumbo Frames（MTU 8896）の設定

HPCノードを接続するVPCネットワークでは、MTU（Maximum Transmission Unit）を標準の 1460/1500 から **8896 バイト（Jumbo Frames）** に拡大します。

```bash
# MTU 8896 のHPC専用VPCを作成
gcloud compute networks create hpc-vpc \
    --subnet-mode=custom \
    --mtu=8896
```

1パケットあたりの転送データ量が増大するため、処理すべきパケット数（PPS: Packets Per Second）が削減され、CPU割り込み負荷の軽減と実効帯域の向上が得られます。

### 3.4 Linuxカーネルパラメータの最適化

Google Cloud公式の [hpc-tools](https://github.com/GoogleCloudPlatform/hpc-tools) や HPC VM イメージでは、以下のような低遅延カーネルチューニングが推奨されています。

```ini
# /etc/sysctl.d/99-hpc-network.conf

# 1. TCPバッファサイズの拡大（広帯域・低遅延通信でのウィンドウ枯渇防止）
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# 2. ビジーポーリングの有効化（割り込み遅延を排除し、パケット到着を直接ポーリング）
net.core.busy_read = 50
net.core.busy_poll = 50

# 3. 輻輳制御アルゴリズム
net.ipv4.tcp_congestion_control = bbr
```

また、プロセスがメモリをロックして予期せぬスワップ（遅延の主因）が発生するのを防ぐため、`/etc/security/limits.conf` で `memlock` を無制限に設定します。

```text
# /etc/security/limits.conf
* soft memlock unlimited
* hard memlock unlimited
* soft nofile 1048576
* hard nofile 1048576
```

---

## 4. ストレージ設計：Parallelstoreと4階層アクセス分離

単一マネージドNAS（NFS）へのI/O集中を避けるため、アクセス特性に応じた **4階層ストレージ構成** を導入します。

```mermaid
flowchart LR
    subgraph Storage_Layers["HPC 4階層ストレージ戦略"]
        direction TB
        LSSD["Tier 0: Local SSD (NVMe)<br/>・遅延: 数μs<br/>・用途: /tmp, ローカルScratch"]
        PStore["Tier 1: Parallelstore (DAOS)<br/>・数千万IOPS / 数十GB/s<br/>・用途: チェックポイント, 超並列I/O"]
        File["Tier 2: Filestore (NFS)<br/>・用途: /home, /apps 共通領域"]
        GCS["Tier 3: Cloud Storage<br/>・耐久性 11 9s<br/>・用途: 長期保管, 大規模生データ"]
    end

    App["HPC Compute Nodes"]

    App <-->|ローカルI/O| LSSD
    App <-->|超高速N-to-1バースト| PStore
    App -->|共通バイナリ参照| File
    App -.->|GCSFuse マウント| GCS
    PStore -.->|高速同期・ステージング| GCS
```

### 4.1 Parallelstore（Managed DAOS）の導入

数千プロセスによるN-to-1チェックポイントバーストや微小ファイルの大量走査（Millions of Small Files）に対応するため、Google Cloud のマネージド並列ファイルシステム **Parallelstore** を活用します。

> **公式ドキュメント引用:**
> *“Parallelstore is a fully managed parallel file system based on DAOS (Distributed Asynchronous Object Storage) architecture. It is designed to deliver ultra-high IOPS and massive throughput for demanding HPC and AI/ML workloads, eliminating storage bottlenecks during training and simulation.”*
> — [Google Cloud Documentation: Parallelstore overview](https://cloud.google.com/parallelstore/docs/overview)

#### DAOS アーキテクチャの特徴
* **カーネルバイパス**: DAOSはOSカーネルのVFSやブロックレイヤを経由せず、ユーザー空間ライブラリ（libfabric）を通じてNVMeストレージと直接通信します。
* **分散メタデータエンジン**: 単一のメタデータサーバーに負荷が集中する従来のNFSと異なり、メタデータ自体が全ストレージノードに分散配置されます。大量のファイルを並列に走査しても、メタデータ処理がボトルネックになりません。
* **Cloud Storage との双方向連携**: Parallelstoreは高速キャッシュ（バーストバッファ）として機能し、Cloud Storage との間でデータを高速にインポート・エクスポートできます。

### 4.2 4階層の役割分担

| 階層 | サービス | 代表的なマウント先 | 役割と設計基準 |
| :--- | :--- | :--- | :--- |
| **Tier 0: Scratch** | Local SSD (NVMe) | `/tmp`, `/scratch/local` | ノード単体で完結する中間ファイル。インスタンス停止で消去 |
| **Tier 1: Hot/Burst** | **Parallelstore (DAOS)** | `/mnt/parallel` | ジョブ実行中の全ノード共有入出力、**チェックポイントの一斉ダンプ** |
| **Tier 2: Warm/Shared**| Filestore (Enterprise/SSD) | `/home`, `/apps/modules` | ユーザーのホームディレクトリ、環境設定、コンパイル済み共通ライブラリ |
| **Tier 3: Cold/Archive**| Cloud Storage (GCS) | `/mnt/gcs` (GCSFuse) | 実験データの恒久保存、元データセットの保管、解析結果の長期アーカイブ |

この階層分離により、計算ノードのI/Oバーストによってホームディレクトリ（NFS）が応答不能となり、クラスタ全体の操作が停止する事態を防止できます。

---

## 5. オーケストレーション設計：SlurmによるBulk確保とフォールトトレランス

Web流の動的オートスケールによるジョブ停止（問題2）と、Spot VM採用に伴う計算損失（問題4）を、HPC専用スケジューラとフォールトトレランス設計によって解決します。

### 5.1 Slurm on Google Cloud：キュー駆動型のBulkプロビジョニング

HPCの世界標準スケジューラである **Slurm** と Google Cloud は、公式の統合プラグイン（`schedmd-slurm-gcp-v6`）を提供しています。

```mermaid
sequenceDiagram
    autonumber
    actor Engineer as 研究者 / エンジニア
    participant Slurm as Slurm Controller
    participant Autoscaler as Slurm GCP Autoscaler
    participant GCE as Compute Engine (Bulk API)
    participant Nodes as H3 Compute Nodes (同一ラック)

    Engineer->>Slurm: sbatch my_job.sh (要求: 64ノード)
    Slurm->>Autoscaler: キューに64ノードの要求を検知
    Autoscaler->>GCE: Bulk VM Creation API (64台一括・同一ラック集約要求)
    GCE-->>Nodes: 64台のH3ノードをアトミックに同時起動
    Nodes->>Slurm: ノードレディ (slurmd起動)
    Slurm->>Nodes: ジョブ投入・MPI計算開始
    Note over Nodes: 計算完了 & Parallelstoreへ結果保存
    Nodes->>Slurm: ジョブ正常完了通知
    Note over Slurm,Autoscaler: アイドル待機タイマー経過 (例: 5分)
    Autoscaler->>GCE: ノード削除リクエスト
    GCE-->>Nodes: インスタンス破棄 (課金停止)
```

### 密結合HPCに Managed Instance Group（MIG）が適さない3つの理由

Compute Engine 標準の **Managed Instance Group（MIG）** は、タスク間に依存関係のない **疎結合（HTC）** ワークロードであれば有効に機能します。

しかし、密結合（MPI型）ワークロードにおいてステートレスMIGの採用が適さない理由は3点あります。

1. **スケーリングトリガーの不一致（メトリクス駆動 vs キュー駆動）**:
   * **MIG**: CPU使用率などの負荷メトリクス平均値が閾値を超えた段階で、後追いで1台ずつ増減させます。
   * **HPC**: 「投入されたジョブが64ノードを要求している」という **ジョブキュー駆動** です。計算開始前に指定ノード数が揃っている必要があり、実行途中にノードが削減されるとMPIプロセス全体が異常終了します。
2. **近接配置（Compact Placement）とのライフサイクルの不一致**:
   * 同一ラックスイッチ配下（Compact Placement）に64ノードを集約配置するには、ラックの空き容量を同時に確保する必要があります。
   * 1台ずつ順次プロビジョニングすると、途中で同一ラック内の空きスロットが枯渇し、離れたラックにノードが分散配置（断片化）されて通信遅延が大幅に悪化します。
3. **ノードの識別性（ランダム名 vs 固定Hostfile）**:
   * MIGはステートレスVMをランダムサフィックス（例: `hpc-node-a1b2`）で管理します。
   * 一方、MPIアプリケーションは起動時に参加全ノードのホスト名一覧（`hostfile`）を確定し、ノード間での相互名前解決とパスワードレスSSH通信を前提とします。

このため、Google Cloud は密結合HPCのオーケストレーションとして MIG ではなく、**Compute Engine の `Bulk VM Creation API` を呼び出す Slurm 公式プラグイン** を提供・推奨しています。

* **アトミック一括確保**: ジョブが必要とするノード数（例: 64台）を `Bulk VM Creation API` で同一の Compact Placement グループ内に一斉に起動します。全台が揃うまでジョブを開始しません。
* **完全破棄によるコスト最適化**: ジョブが終了し、一定のアイドル時間（例: 5分）が経過したノードは自動的に削除されます。アイドル時のコストを最小化できます。

### 5.2 Spot VM のフォールトトレランス設計

Spot VM を密結合HPCで安全に運用するためには、スケジューラとアプリケーションを連携させる必要があります。

1. **Slurm の自動再投入（Requeue）設定**:
   ノードがプリエンプト（強制停止）された際、Slurmがジョブをエラー終了させず、自動的に待機キューへ戻して別のノード群で再実行させます。
   ```bash
   # ジョブスクリプト内での設定
   #SBATCH --requeue
   ```
2. **停止前30秒のシグナルトラップ（Graceful Checkpointing）**:
   Compute Engine の Spot VM は、停止の **30秒前** に ACPI シャットダウンシグナルを発行します。シミュレーションコード側でこのシグナル（SIGTERM等）をハンドリングし、メモリ上の直前状態を Parallelstore にダンプして終了します。再投入されたジョブはそのチェックポイントから再開するため、計算の損失を最小限に抑えられます。

### 5.3 Cluster Toolkit（`ghpc`）による宣言的インフラ構築

ここまで解説した「Compact Placement」「Tier_1」「MTU 8896」「Parallelstore」「Slurm」の構成をWebコンソールから手作業で設定すると、設定漏れや構成の不整合が生じやすくなります。

Google Cloud が提供するオープンソースツール **Cluster Toolkit（`ghpc`）** を使用すれば、クラスタ全体を1つの YAML Blueprint として宣言的に定義・デプロイできます。

> **公式ドキュメント引用:**
> *“The Cluster Toolkit is an open-source tool that makes it easy to deploy high-performance computing (HPC) environments on Google Cloud using Infrastructure as Code (IaC). You define your cluster using a YAML blueprint, and the toolkit generates and applies Terraform modules adhering to Google Cloud best practices.”*
> — [Google Cloud Documentation: Cluster Toolkit overview](https://cloud.google.com/cluster-toolkit/docs/overview)

#### Blueprint の定義例（`hpc-cluster.yaml`）

```yaml
blueprint_name: production-hpc-cluster

vars:
  project_id: my-gcp-project
  deployment_name: hpc-cluster
  region: us-central1
  zone: us-central1-a

deployment_groups:
  - group: primary
    modules:
      # 1. 低遅延 VPC ネットワーク (Jumbo Frames MTU 8896)
      - id: network
        source: modules/network/vpc
        settings:
          mtu: 8896

      # 2. 共有ホームディレクトリ (Filestore)
      - id: homefs
        source: modules/file-system/filestore
        use: [network]
        settings:
          filestore_tier: BASIC_SSD
          size_gb: 2560

      # 3. 超並列バーストストレージ (Parallelstore / DAOS)
      - id: scratchfs
        source: modules/file-system/parallelstore
        use: [network]
        settings:
          capacity_gb: 12000

      # 4. Slurm コントローラ
      - id: slurm_controller
        source: community/modules/scheduler/schedmd-slurm-gcp-v6-controller
        use: [network, homefs, scratchfs]

      # 5. H3 コンピュートノードパーティション (Compact Placement 自動適用)
      - id: h3_partition
        source: community/modules/compute/schedmd-slurm-gcp-v6-partition
        use: [network, slurm_controller]
        settings:
          partition_name: h3-compute
          max_node_count: 64
          machine_type: h3-standard-88
          enable_placement: true  # Compact Placement Policy を自動設定
          bandwidth_tier: tier_1  # Tier_1 ネットワーキング (200Gbps) を自動設定
```

デプロイはコマンド2行で完了します。Toolkit が内部で最適な Terraform コードを生成し、Google Cloud のベストプラクティスに沿った構成を展開します。

```bash
# Blueprint からデプロイメントコードを生成
ghpc create blueprints/hpc-cluster.yaml -w /work/hpc-deployment

# クラスタを一括プロビジョニング
ghpc deploy /work/hpc-deployment
```

### 5.4 疎結合（HTC）における選択肢：Google Cloud Batch との使い分け

密結合（MPI型）のクラスタ設計を中心に解説してきましたが、HPCにはプロセス間通信を行わない **疎結合（HTC / 自明並列）** のワークロードも多く存在します。

対象のワークロードが、プロセス間通信を伴わないパラメータスタディやモンテカルロシミュレーション、ゲノム解析などの疎結合である場合、Slurmクラスタを常設・構築する必要はありません。Google Cloud のフルマネージドバッチサービスである **Google Cloud Batch** を活用できます。

```mermaid
flowchart TD
    Start["HPCワークロードの要件確認"] --> Q1{"プロセス間のリアルタイム通信<br/>(MPI / AllReduce) が必要か？"}
    
    Q1 -- "NO (疎結合 / HTC)<br/>タスク同士が独立" --> Batch["【推奨】Google Cloud Batch<br/>・サーバレスなジョブ実行<br/>・Spot VM を大規模に自動投入<br/>・クラスタ管理運用コストゼロ<br/>・コンテナ / スクリプト実行"]
    
    Q1 -- "YES (密結合 / MPI)<br/>超低遅延・バリア同期" --> Slurm["【推奨】Cluster Toolkit + Slurm on GCP<br/>・H3 / H4D 物理コア専有<br/>・Compact Placement (同一ラック)<br/>・Tier_1 (最大200Gbps)<br/>・Parallelstore (DAOS) 連携"]
```

| 比較項目 | Google Cloud Batch（疎結合・HTC向け） | Slurm on Google Cloud（密結合・MPI向け） |
| :--- | :--- | :--- |
| **主な用途** | パラメータ探索、モンテカルロ、レンダリング、ゲノム解析 | 流体解析（CFD）、構造解析（FEM）、気象予測、LLM分散学習 |
| **通信要件** | 不要（タスク間通信なし） | 必須（マイクロ秒オーダー・同一ラック近接配置） |
| **インフラ管理** | **不要（完全マネージド）**<br>コントローラVMの管理やOS保守は不要 | **必要（半マネージド）**<br>Slurmコントローラやパーティションの定義が必要 |
| **Spot VM親和性** | **高い**<br>中断されたタスク単位で自動再試行が可能 | **設計が必要**<br>Slurm `--requeue` とチェックポイントの設計が必要 |
| **ストレージ** | Cloud Storage（GCS）中心で構成可能 | Parallelstore（DAOS）やローカルSSDが推奨される |

ワークロードの通信特性に応じて適切な基盤サービスを選択することが、クラウドにおけるコストと性能の最適化に直結します。疎結合であれば Google Cloud Batch を選択して運用負荷を最小化し、密結合であれば Cluster Toolkit、Slurm、H3、Parallelstore を組み合わせて要求性能を満たす基盤を構成します。

---

## 6. まとめ：Google Cloud における機能対応一覧

前編・後編を通じて整理した課題とHPCの特性、およびGoogle Cloudの対応機能を総括表としてまとめます。

| レイヤ | Webインフラの前提から生じる問題 | HPCの物理的特徴・要求 | Google Cloud での推奨構成 |
| :--- | :--- | :--- | :--- |
| **Compute** | 可用性のためのマルチAZ分散配置 | マイクロ秒単位の低遅延通信 | **`Compact Placement Policy`（`COLLOCATED`）** |
| | vCPU仮想化とコンテナ詰め込み | 物理コア専有・キャッシュ競合防止 | **`H3` マシンシリーズ**（または `--threads-per-core: 1`） |
| | Live Migration によるマイクロ停止 | ハートビート途絶・ジョブ強制終了の防止 | **`--maintenance-policy=TERMINATE`** |
| **Network** | 標準ネットワークとTCPの遅延・帯域不足 | 高帯域・割り込みオーバーヘッド削減 | **`Tier_1 ネットワーキング`（最大200Gbps）** ＋ **`gVNIC/IDPF`** |
| | パケットヘッダによるCPU負荷 | PPS削減と実効帯域の向上 | VPC の **`MTU = 8896`（Jumbo Frames）** |
| | ソケットバッファの枯渇・割り込み遅延 | Jitterの排除と決定論的通信 | **Linux カーネルチューニング**（`busy_poll`、`memlock unlimited`） |
| **Storage** | 単一マネージドNAS（NFS）への依存 | N-to-1バーストI/O、大量微小ファイル走査 | **`Parallelstore`（Managed DAOS）** による超並列I/O |
| | ストレージ競合によるホーム領域停止 | 役割に応じたアクセス分離 | **4階層ストレージ戦略**（Local SSD / Parallelstore / Filestore / GCS） |
| **Orchestration** | Web流の動的オートスケール（MIG） | トポロジアウェアな静的一括割り当て | **`Slurm on Google Cloud`**（Bulk VMプロビジョニング） |
| | Spot VM の中断による計算全損 | All-or-Nothingへの耐性確保 | Slurm **`--requeue`** ＋ 30秒前シグナルトラップによる緊急チェックポイント |
| | 手作業構築による設定ミス・不均一 | 宣言的で再現性のある基盤構築 | **`Cluster Toolkit`（`ghpc`）** による YAML Blueprint 自動化 |

Web/APIシステムで培われたクラウドインフラの知見は有用ですが、密結合・同期型のHPCワークロードを扱う際は、物理レイヤの制約と通信トポロジを前提に設計を見直す必要があります。

Google Cloud の既存機能を適切に組み合わせることで、クラウドの弾力性を活かしながら、物理スーパーコンピュータに匹敵する計算基盤を構成できます。

---

### 公式参考リンク
* [Google Cloud Architecture Center: Best practices for running tightly coupled HPC applications on Compute Engine](https://cloud.google.com/architecture/best-practices-for-tightly-coupled-hpc-applications)
* [Google Cloud Compute Engine Documentation: H3 machine series](https://cloud.google.com/compute/docs/compute-optimized-machines#h3_series)
* [Google Cloud Documentation: Cluster Toolkit overview](https://cloud.google.com/cluster-toolkit/docs/overview)
* [Google Cloud Documentation: Parallelstore overview](https://cloud.google.com/parallelstore/docs/overview)
* [Google Cloud Documentation: Define placement policies](https://cloud.google.com/compute/docs/instances/placement-policies)
* [GitHub: GoogleCloudPlatform/cluster-toolkit](https://github.com/GoogleCloudPlatform/cluster-toolkit)
* [GitHub: GoogleCloudPlatform/hpc-tools](https://github.com/GoogleCloudPlatform/hpc-tools)
