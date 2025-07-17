# RunPod Bazel Docker Build Guide

## 🚀 自動化ビルド手順（次回用）

### 1. RunPodインスタンス起動
```
Template: RunPod PyTorch 2.4.0（またはそれ以上）
GPU: RTX 4090+ (推奨)
Container Disk: 50GB+
Volume: 不要（ビルドのみ）
```

### 2. プロジェクトセットアップ
```bash
# rootディレクトリに移動
cd /root

# プロジェクトをクローン
git clone https://github.com/mksd9/my-comfy-wan.git
cd my-comfy-wan

# 環境変数設定（Docker Hub認証）
export DOCKER_PASSWORD='your_docker_hub_token'
```

### 3. 完全自動化ビルド実行
```bash
# ワンコマンド実行（全自動）
./setup-runpod-bazel.sh
```

### 4. 期待される結果
- ⏱️ **ビルド時間**: 25-50分（初回）、15-20分（キャッシュあり）
- 🏷️ **イメージ**: `nobukoyo/comfyui-wan-runpod:latest`
- ✅ **Docker Hub自動プッシュ**
- 💰 **推定コスト**: $2-4（RTX 4090）

### 5. RunPodテンプレート設定
```
Container Image: nobukoyo/comfyui-wan-runpod:latest
Container Start Command: /start.sh
Ports: 6006, 8888
```

---

## 🛠️ プロジェクト構成（修正時参考）

### 重要なファイル構成
```
my-comfy-wan/
├── WORKSPACE                    # Bazel旧形式設定（互換性用）
├── MODULE.bazel                 # Bazel新形式設定（推奨）
├── BUILD.bazel                  # Bazelビルド設定
├── setup-runpod-bazel.sh       # 完全自動化ビルドスクリプト
├── Dockerfile                   # 参考用（実際はBazelでビルド）
├── start.sh                     # コンテナ起動スクリプト
├── runpod.yaml                  # RunPod設定
└── scripts/
    └── download_models.sh       # モデルダウンロードスクリプト
```

### Bazel設定詳細

#### MODULE.bazel（メイン設定）
- `rules_oci@1.7.5`: OCI準拠イメージビルド
- `rules_pkg@1.0.1`: ファイルパッケージング
- `rules_python@0.31.0`: Python環境（root対応）
- CUDAベースイメージ: `nvidia/cuda:12.3.2-devel-ubuntu22.04`

#### BUILD.bazel（ビルド設定）
- `oci_image`: OCIイメージ作成
- `oci_push`: Docker Hubプッシュ
- `pkg_tar`: ファイルパッケージング

### 技術スタック
- **ビルドシステム**: Bazel 8+ with Bazelisk
- **コンテナ規格**: OCI準拠（rules_oci）
- **ベースイメージ**: NVIDIA CUDA 12.3.2 Ubuntu 22.04
- **プラットフォーム**: linux/amd64
- **レジストリ**: Docker Hub

---

## ⚙️ カスタマイズ方法

### Docker Hubユーザー変更
```bash
# BUILD.bazelを編集
repository = "index.docker.io/YOUR_USERNAME/comfyui-wan-runpod"

# setup-runpod-bazel.shを編集
DOCKER_USER="YOUR_USERNAME"
```

### モデル・スクリプト追加
```bash
# BUILD.bazelのpkg_tarに追加
pkg_tar(
    name = "new_files",
    srcs = ["new_file.sh"],
    mode = "0755",
    package_dir = "/path/to/destination",
)

# oci_imageのtarsに追加
tars = [
    ":app_files",
    ":scripts",
    ":new_files",  # 追加
],
```

### CUDAバージョン変更
```bash
# MODULE.bazelとWORKSPACEの両方を編集
image = "index.docker.io/nvidia/cuda:NEW_VERSION-devel-ubuntu22.04"
```

---

## 🐛 トラブルシューティング

### よくあるエラーと対処法

#### 1. Python root user error
```
Error: The current user is root
```
**対処**: 既に`ignore_root_user_error = True`で解決済み

#### 2. Multi-architecture image error
```
Error: platforms attribute is required
```
**対処**: 既に`platforms = ["linux/amd64"]`で解決済み

#### 3. Docker Hub認証エラー
```
Error: authentication required
```
**対処**: `DOCKER_PASSWORD`環境変数を正しく設定

#### 4. ディスク容量不足
```
Error: No space left on device
```
**対処**: Container Diskを50GB+に設定

### デバッグコマンド
```bash
# Bazelキャッシュクリア
bazel clean --expunge

# 詳細ログでビルド
bazel run //:push_custom_image --verbose_failures

# Docker Hub確認
curl -s https://hub.docker.com/v2/repositories/nobukoyo/comfyui-wan-runpod/tags/
```

---

## 📋 チェックリスト

### ビルド前確認
- [ ] RunPodインスタンス起動済み（50GB+ Container Disk）
- [ ] Docker Hub Access Token準備済み
- [ ] `DOCKER_PASSWORD`環境変数設定済み

### ビルド後確認
- [ ] `✅ Build completed successfully!`メッセージ確認
- [ ] Docker Hubにイメージプッシュ確認
- [ ] RunPodテンプレート作成・テスト

### 継続的利用
- [ ] 定期的なベースイメージ更新
- [ ] Docker Hub容量・料金確認
- [ ] プロジェクト更新時の再ビルド

---

**🎬 Ready for next build!**