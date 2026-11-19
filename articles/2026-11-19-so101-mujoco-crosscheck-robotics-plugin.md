---
title: "SO-101の順運動学をAntigravity Roboticsプラグインで照合したら、モデル間で手先基準点が19.9 mmずれていた話"
emoji: "🤖"
type: "tech"
topics: ["so-arm101", "mujoco", "antigravity", "ロボット"]
published: false
---

個人で SO-101 ロボットアームの古典制御を試すにあたり、土台となる MuJoCo シミュレーションの順運動学（FK）とカメラ姿勢を別の実装と照合しました。その結果、**自分のモデルの FK と手首カメラの取り付け姿勢は浮動小数点精度で一致し、一方で参照する SO-101 モデルの違いによって手先の基準点が 19.9 mm ずれる**ことが分かりました。

## 古典制御の土台として FK とカメラ姿勢を照合した理由

古典制御の検証では、シミュレーション上の手先姿勢やカメラから見た座標系がずれていると、制御則以前に前提が崩れます。そのため、自分が組んだシミュレーションの数値が正しいかを、独立した別の手順で作った結果と突き合わせて確かめることにしました。

自分のシミュレーションには `mujoco_menagerie` の `robotstudio_so101`（commit `370c43965323c0944b433b202aac5058b5f907a9`）と MuJoCo 4.0.1 を使いました。答え合わせの相手には Google Antigravity（`agy`）を使い、プラグインなしの状態と Robotics プラグインを導入した状態の 2 回に分けて同じ計算を依頼しました。

## 比較した対象と誤差の定義

照合では同じ関節角のテスト姿勢 5 パターン（`q0`〜`q4`）を入力し、以下の 3 項目を比べました。

- 手先（`gripperframe`）のベース座標系での姿勢（FK）
- 手首カメラの取り付け姿勢 `T_gripper_wristcam`
- 上カメラの姿勢 `T_base_topcam`

位置の差は mm、回転の差は $R_a^T R_b$ の回転角（deg）で測りました。カメラ座標系はどちらも MuJoCo の規約（-Z が前、+X が右、+Y が上）に従っていたため、座標軸の変換は行っていません。

## 1 回目（プラグインなし）の結果と基準点の差

1 回目はプラグインを入れずに `agy` へ依頼しました。すると `agy` は `TheRobotStudio/SO-ARM100` の `Simulation/SO101/so101_new_calib_camera.xml`（commit `a758567c`）を自分で clone し、素の `mujoco` 4.0.1 で計算しました。

| 比較項目 | 位置の差 | 回転の差 | 備考 |
| --- | --- | --- | --- |
| FK（5 パターン `q0`〜`q4`） | 19.9 mm（一定） | 1e-13 deg 程度 | 一定差を除くと 8.7e-6 mm 以下 |
| 手首カメラ `T_gripper_wristcam` | 67.6 mm | 90.8 deg | 本家 XML に `<camera>` 要素がなく `agy` が配置 |
| 上カメラ `T_base_topcam` | 86.6 mm | 9.7 deg | `agy` 側の配置選択であり比較対象外 |

FK は 5 パターンすべてで位置が 19.9 mm ずれ、回転のずれは 1e-13 deg 程度に収まりました。この 19.9 mm のずれは姿勢によらず一定で、取り除くと残差は 8.7e-6 mm 以下でした。

原因を調べたところ、**手先の基準点 `gripperframe` の定義がモデル間で異なっていました**。`mujoco_menagerie` 版は `pos x=0.012` であるのに対し、本家 `SO-ARM100` 版は `x=-0.0079` です。腕の運動学であるリンク長と関節の可動範囲は同じで、可動範囲の差は丸めによる最大 2.2e-6 rad でした。

カメラについては、本家 XML には手首カメラの body が定義されているものの `<camera>` 要素が含まれていませんでした。`agy` が手首カメラと上カメラを自分で配置したため、この回ではカメラ取り付けの正しさを比較できませんでした。

## Robotics プラグインの導入手順

2 回目は、参照モデルとシーン構築の手順を揃えるために Google Antigravity の Robotics プラグイン（v0.1.11）を導入しました。導入は `agy` の `/plugin` からマーケットプレイスの Robotics を選ぶだけで完了しました。

GitHub から直接インストールする場合は、以下のコマンドを実行します。

```bash
agy plugin install https://github.com/google-deepmind/robotics-antigravity-plugin
npx skills add google-deepmind/mujoco
```

## 2 回目（プラグインあり）の結果とシーンの扱い

プラグインを導入した状態で再度依頼したところ、`agy` はプラグインの `mujoco-playground` スキル（`build_playground_spec(robot="so101")` と `so101_aloha_table` シーン）を使い、`mujoco_playground` 経由で同じ `mujoco_menagerie` の commit `370c4396` を自動取得しました。実行環境は MuJoCo 4.0.2 でした。

| 比較項目 | 位置の差 | 回転の差 | 備考 |
| --- | --- | --- | --- |
| FK（5 パターン `q0`〜`q4`） | 1.8e-13 mm 以下 | 3.6e-14 deg 以下 | リンク長と可動範囲は完全一致 |
| 手首カメラ `T_gripper_wristcam` | 5.2e-14 mm | 7.7e-15 deg | 浮動小数点精度で一致 |
| 上カメラ `T_base_topcam` | 370 mm | 73.4 deg | 配置方針の違い（真上 vs 斜め） |

FK は 5 パターンすべてで位置差 1.8e-13 mm 以下、回転差 3.6e-14 deg 以下になり、リンク長と可動範囲も完全に一致しました。手首カメラも 5.2e-14 mm / 7.7e-15 deg と浮動小数点の精度で一致しました。なお、MuJoCo 4.0.1 と 4.0.2 のバージョン差は今回の結果には出ませんでした。

プラグインのシーンではロボットのベースを world の `(0, -0.27, 0.75)` に置き Z 軸周りに +90 deg 回転させていましたが、FK をベース座標系で出力していたため比較への影響はありませんでした。上カメラの 370 mm / 73.4 deg の差は、プラグインのシーンがベースの 0.6 m 真上から真下を向いているのに対し、自分のシーンではマーカーに向けて斜めに置いているためであり、配置方針の違いであってどちらも誤りではありません。

一方で、再現性の面では気になる点も 2 つ見つかりました。出力されたシーン XML はメッシュ 21 個を参照していましたがメッシュファイルが同梱されておらず、単体では読み込めませんでした。また、出力された JSON には比較に使った関節角が含まれていませんでした。

## 照合から見えたモデル選択と再現性の注意点

今回の 2 回の照合から、シミュレーションの検証で意識すべき点が 3 つ分かりました。

1. 自分のモデルの FK と手首カメラの取り付けは、プラグインを使った別の構築手順でも浮動小数点の精度で一致しました。
2. SO-101 のモデルは本家版と `mujoco_menagerie` 版で `gripperframe` の基準点が 19.9 mm 異なります。どちらを使ったかを明記しないと約 2 cm のずれが生じます。
3. プラグインを入れない状態では、`agy` は自分で別のモデルを探して計算に使います。照合を依頼する際は、**使用する XML のパスと commit ハッシュを指定し、入力した関節角と計算結果の姿勢をセットで JSON に出力させる**ことで再現性を保てます。

## 次のステップ: 実機での手先位置の計測

`mujoco_menagerie` 版と本家 `SO-ARM100` 版のどちらの `gripperframe` 定義が実機の手先に近いかは、今回のシミュレーション照合だけでは未計測のままです。近日中に実機で手先の位置を測り、シミュレーションの基準点と突き合わせる予定です。

## 参考

- [google-deepmind/robotics-antigravity-plugin](https://github.com/google-deepmind/robotics-antigravity-plugin)
- [Antigravity Plugins ドキュメント](https://antigravity.google/docs/plugins/)
- [mujoco_menagerie - robotstudio_so101](https://github.com/google-deepmind/mujoco_menagerie/tree/main/robotstudio_so101)
- [TheRobotStudio/SO-ARM100](https://github.com/TheRobotStudio/SO-ARM100)
