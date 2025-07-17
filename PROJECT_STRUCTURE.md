# ComfyUI WAN RunPod Template - Project Structure

## 📁 ファイル構成

### コアファイル
```
my-comfy-wan/
├── WORKSPACE                    # Bazel旧形式設定（互換性用）
├── MODULE.bazel                 # Bazel新形式設定（メイン）
├── BUILD.bazel                  # Bazelビルドルール定義
├── setup-runpod-bazel.sh       # 完全自動化ビルドスクリプト
├── Dockerfile                   # 参考用Docker設定
├── start.sh                     # コンテナ起動スクリプト
├── runpod.yaml                  # RunPod設定
├── RUNPOD_BUILD_GUIDE.md        # ビルド手順書
└── PROJECT_STRUCTURE.md         # このファイル
```

### スクリプト・設定
```
scripts/
├── download_models.sh           # モデルダウンロードスクリプト
└── (他の補助スクリプト)

docs/
├── DOCKER_BUILD_GUIDE.md        # 旧Docker直接ビルド手順（参考用）
├── QUICK_REFERENCE.md           # クイックリファレンス（参考用）
└── (その他ドキュメント)
```

---

## 🔧 技術仕様

### Bazelビルドシステム
- **Version**: Bazel 8+ (Bazelisk管理)
- **Rules**: rules_oci@1.7.5 (OCI準拠)
- **Build Mode**: MODULE.bazel（Bzlmod）+ WORKSPACE（互換性）

### コンテナ仕様
- **Base Image**: nvidia/cuda:12.3.2-devel-ubuntu22.04
- **Platform**: linux/amd64
- **Registry**: Docker Hub
- **Size**: 約15-18GB（圧縮後）

### 依存関係
```yaml
Bazel Dependencies:
  - rules_oci: 1.7.5          # OCI image building
  - rules_pkg: 1.0.1          # File packaging
  - rules_python: 0.31.0      # Python support (root compatible)

System Dependencies:
  - Bazelisk: v1.20.0         # Bazel version manager
  - CUDA: 12.3.2              # GPU support
  - Ubuntu: 22.04             # Base OS
```

---

## 🎯 ビルドフロー

### 1. 設定ファイル読み込み
```
MODULE.bazel → rules_oci deps → CUDA base image pull
```

### 2. ファイルパッケージング
```
pkg_tar(app_files) → start.sh, runpod.yaml
pkg_tar(scripts) → download_models.sh
```

### 3. OCIイメージビルド
```
oci_image → base: cuda_base + tars: [app_files, scripts]
```

### 4. プッシュ
```
oci_push → index.docker.io/nobukoyo/comfyui-wan-runpod:latest
```

---

## 🔄 修正時の重要ポイント

### ファイル修正優先度

#### 🔴 Critical（修正時必須確認）
- `MODULE.bazel`: 依存関係、ベースイメージ指定
- `BUILD.bazel`: ビルドルール、ファイル構成
- `setup-runpod-bazel.sh`: 自動化スクリプト

#### 🟡 Important（機能追加時）
- `start.sh`: コンテナ起動動作
- `scripts/download_models.sh`: モデル取得処理
- `runpod.yaml`: RunPod設定

#### 🟢 Reference（参考・互換性用）
- `WORKSPACE`: Bazel旧形式（互換性維持）
- `Dockerfile`: Docker直接ビルド用（参考）
- `docs/*`: 旧手順書（参考用）

### 修正時の注意点

#### ベースイメージ変更
```bash
# MODULE.bazel と WORKSPACE 両方を修正
image = "index.docker.io/nvidia/cuda:NEW_VERSION"
platforms = ["linux/amd64"]  # 必須
```

#### ファイル追加
```bash
# BUILD.bazel の pkg_tar に追加
srcs = ["existing_file.sh", "new_file.sh"]

# oci_image の tars に新しいpkg_tarを追加
tars = [":app_files", ":scripts", ":new_tar"]
```

#### Docker Hub設定変更
```bash
# BUILD.bazel
repository = "index.docker.io/NEW_USER/NEW_REPO"

# setup-runpod-bazel.sh
DOCKER_USER="NEW_USER"
IMAGE_NAME="NEW_REPO"
```

---

## 📊 パフォーマンス指標

### ビルド時間
- **初回**: 25-50分（依存関係ダウンロード含む）
- **キャッシュあり**: 15-20分
- **変更なし**: 1-2分（キャッシュ検証のみ）

### リソース使用量
- **CPU**: フル活用（32コア推奨）
- **Memory**: 最大16GB使用
- **Disk**: 20-25GB（キャッシュ含む）
- **Network**: 5-10GB（初回ダウンロード）

### コスト概算（RTX 4090）
- **時間単価**: 約$0.06/分
- **初回ビルド**: $2-4
- **更新ビルド**: $1-2
- **テストビルド**: $0.1-0.5

---

## 🔐 セキュリティ考慮事項

### 認証情報
- `DOCKER_PASSWORD`: 環境変数で管理（平文保存禁止）
- Docker Hub Token: 最小権限（Read/Write/Delete）

### イメージセキュリティ
- Base Image: NVIDIA公式イメージ使用
- Vulnerability Scan: Docker Hubで自動実行
- Root User: コンテナ内のみ（ホスト影響なし）

### ネットワーク
- Pull/Push: HTTPS通信（TLS暗号化）
- Registry: Docker Hub公式（信頼済み）

---

**📝 Document Version: 2.1 (Bazel rules_oci)**