# ComfyUI WAN RunPod Template

WAN video generation に最適化された高性能 ComfyUI 環境の RunPod テンプレートです。

## 📚 **ドキュメント**

### 🔧 **開発者向け**
- **[Docker Build & Deploy ガイド](docs/DOCKER_BUILD_GUIDE.md)** - 完全なビルド工程とトラブルシューティング
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - 素早いデプロイ用コマンド集

### 🎯 **ユーザー向け**
- **[README.md](README.md)** - 基本的な使用方法（このファイル）

---

## 🚀 特徴

### Core Models（事前インストール済み）
- **WAN 2.1 T2V-14B** - メインビデオ生成モデル（GGUF形式）
- **UMT5-XXL Encoder** - 高精度テキストエンコーダー（GGUF形式）
- **WAN 2.1 VAE** - 高品質ビデオエンコーディング
- **WAN LoRA** - 追加の機能拡張LoRA

### Professional Custom Nodes（最新版自動取得）
- **ComfyUI-Manager** - ノード管理システム（新規追加）
- **ComfyUI-GGUF** - GGUF形式ファイル対応
- **ComfyUI-Easy-Use** - 使いやすいUI
- **ComfyUI-KJNodes** - 追加ノード群
- **ComfyUI-VRGameDevGirl** - VR関連機能
- **RGThree-Comfy** - ワークフロー最適化

### Infrastructure
- **CUDA 12.3.2** 対応
- **PyTorch 2.7 nightly+** with CUDA support
- **Persistent Storage** 対応（オプション）
- **事前インストール済みモデル** - ダウンロード不要で高速起動
- **最新版Custom Nodes** - GitHubから自動取得

## 📋 セットアップ

### 🔥 **RunPod上でのビルド（推奨）**
**最新バージョン**を使用するため、RunPod上でのビルドを強く推奨します。

#### 🚀 クイックビルド
```bash
# 1. RunPodインスタンス起動（Container Disk: 50GB+）
# 2. Web Terminal で実行
git clone https://github.com/mksd9/my-comfy-wan.git
cd my-comfy-wan
export DOCKER_PASSWORD='your_docker_hub_token'
./build-on-runpod.sh
```

詳細な手順は **[Docker Build & Deploy ガイド](docs/DOCKER_BUILD_GUIDE.md)** を参照してください。

### 📦 **事前ビルド済みイメージ使用**
ビルドをスキップして、事前にビルドされたイメージを使用する場合：

**Container Image**:
```
nobukoyo/comfyui-wan-runpod:latest
```

**Container Start Command**:
```
/start.sh
```

**Ports**:
- ComfyUI: `6006`
- Jupyter Lab: `8888`

**⚠️ 注意**: 事前ビルド済みイメージは更新頻度が低い場合があります。最新機能には上記のビルド方法を推奨します。

### 3. 環境変数（オプション）

| Variable | Description | Required |
|----------|-------------|----------|
| `RUNPOD_VOLUME_PATH` | 永続ストレージパス | No |

### 4. 永続ストレージ（オプション）

永続ストレージを使用する場合：

1. **Volume Disk** を設定（推奨: 50GB+）
2. **Volume Mount Path**: `/workspace`
3. **Environment Variable**: 
   - `RUNPOD_VOLUME_PATH` = `/workspace`

この設定により、生成されたビデオファイルが保持されます。

## 🎯 使用方法

### 起動後のアクセス

1. RunPod でコンテナを起動
2. **ComfyUI**: HTTP サービス（Port 6006）の **Connect** をクリック
3. **Jupyter Lab**: HTTP サービス（Port 8888）の **Connect** をクリック
4. 両方のサービスが同時に利用可能です

### 起動時の動作

スクリプトが以下を自動実行します：

1. **環境セットアップ**: モデルディレクトリの確認
2. **モデル確認**: 事前インストールされたWANモデルの確認
3. **カスタムノード確認**: 最新版custom nodesの存在確認
4. **サービス起動**:
   - Jupyter Lab (Port 8888) をバックグラウンドで起動
   - ComfyUI (Port 6006) をメインプロセスで起動

**モデルは事前インストール済み、custom nodesは最新版が含まれるため、起動は約 1-2 分で完了します**

### Jupyter Lab の使用方法

**主な機能**:
- **Python コード実行**: リアルタイムでコードを実行・テスト
- **ComfyUI API 操作**: プログラムからワークフローを制御
- **ビデオ分析**: 生成ビデオの分析、メタデータ処理
- **モデル調査**: WAN モデルの動作確認、パラメータ調整
- **ワークフロー開発**: 新しいワークフローの作成・テスト

**推奨用途**:
1. **ComfyUI API での自動化**: バッチ処理、スケジュール実行
2. **生成ビデオの分析**: 品質評価、統計処理
3. **プロンプトエンジニアリング**: プロンプトの最適化実験
4. **カスタムノード開発**: 新機能の開発・テスト

**ライブラリ**:
- `pandas`, `numpy` - データ処理
- `matplotlib`, `seaborn`, `plotly` - 可視化
- `opencv-python`, `pillow` - 画像・ビデオ処理
- `jupyter widgets` - インタラクティブUI

### モデル配置

事前インストールされたモデル：

```
/ComfyUI/models/
├── unet/
│   └── wan2.1-t2v-14b-Q4_K_S.gguf
├── clip/
│   └── umt5-xxl-encoder-Q5_K_S.gguf
├── vae/
│   └── wan_2.1_vae.safetensors
└── loras/
    └── Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors
```

### カスタムノード配置

最新版が自動取得されるカスタムノード：

```
/ComfyUI/custom_nodes/
├── ComfyUI-Manager/
├── ComfyUI-GGUF/
├── comfyui-easy-use/
├── comfyui-kjnodes/
├── comfyui-vrgamedevgirl/
└── rgthree-comfy/
```

## 🛠️ 推奨仕様

### RunPod GPU インスタンス

**推奨最小仕様**:
- **GPU**: RTX 4090 (24GB VRAM)
- **Container Disk**: 40GB
- **Volume Disk**: 50GB+ (永続ストレージ使用時)

**性能重視**:
- **GPU**: RTX A6000 / H100
- **Container Disk**: 40GB
- **Volume Disk**: 100GB+

### 想定使用ケース

**適用分野**:
1. **ビデオ生成**: テキストからビデオの生成
2. **クリエイティブ制作**: アニメーション、映像作品
3. **プロトタイピング**: 概念実証、アイデア検証
4. **研究開発**: AI映像生成の実験・研究

**要求事項**:
1. **GPU VRAM が 16GB 以上であること**
2. **RunPodでのGPUメモリが十分か**
3. **ネットワーク接続が安定しているか**

## Troubleshooting

### Container Restart Issues

If the container fails to start both services:

1. **Check Port Conflicts**: Ensure ports 6006 and 8888 are available
2. **Check Logs**: 
   ```bash
   # ComfyUI logs
   docker logs <container_id>
   
   # Jupyter Lab logs
   docker exec <container_id> cat /tmp/jupyter.log
   ```
3. **Restart Services**: Both services restart automatically with the container

### Model Issues

If WAN models are not found:

1. **Check Model Files**: Look for error messages about missing models
2. **Verify Image**: Ensure you're using the correct image version
3. **Check Logs**: Look for model verification messages:
   ```
   [INFO] ✓ WAN T2V model found
   [INFO] ✓ UMT5 encoder found
   [INFO] ✓ WAN VAE found
   [INFO] ✓ WAN LoRA found
   ```

### Jupyter Lab Issues

**Cannot access Jupyter Lab on port 8888**:

1. **Check RunPod Port Settings**: Ensure port 8888 is properly exposed
2. **Verify Service Status**: 
   ```bash
   docker exec <container_id> ps aux | grep jupyter
   ```
3. **Check Logs**: Look for startup errors in `/tmp/jupyter.log`
4. **Manual Start**: If service failed to start:
   ```bash
   docker exec <container_id> jupyter lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser
   ```

---

## 🏷️ ライセンス

このテンプレートは MIT ライセンスの下で公開されています。
含まれるモデルやカスタムノードは各々のライセンスに従います。

---

**🎬 Ready to create amazing videos with WAN!** 