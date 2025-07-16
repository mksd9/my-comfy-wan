# Docker Build & Deploy Guide
## ComfyUI WAN RunPod Template

### 🎯 **概要**
このガイドでは、ComfyUI WAN RunPod Template のDockerイメージをビルドし、DockerHubにデプロイする手順を説明します。

### 📋 **前提条件**
- Docker Desktop がインストールされていること
- DockerHub アカウントを持っていること
- 十分なディスク容量（約20-22GB）があること

### ⚠️ **GitHub Actions制限について**
GitHub Actionsは**ディスク容量不足**（14GB制限）により、WANモデルファイル（数GB〜十数GB）+ PyTorch + CUDAの組み合わせでは**ビルドに失敗**します。

#### 制限の詳細
- **GitHub Actions容量**: 約14GB
- **必要容量**: 20GB以上（WANモデル + PyTorch + CUDA + BuildKit）
- **結果**: `No space left on device`エラー

#### 現在の対応状況
- GitHub Actionsワークフローは一時無効化済み
- 手動実行のみ可能（ただし失敗する可能性が高い）

### 🔥 **RunPod上でのビルド（推奨方法）**
**GitHub Actionsの制限を回避**し、RunPod上で直接ビルドする**最も確実な方法**です。

#### 🚀 クイックスタート
```bash
# 1. RunPodインスタンス起動後
git clone https://github.com/mksd9/my-comfy-wan.git
cd my-comfy-wan

# 2. 環境変数設定
export DOCKER_PASSWORD='your_docker_hub_token'

# 3. ワンライナーで完了
./build-on-runpod.sh
```

#### 📋 詳細手順
1. **RunPodインスタンス起動**
   ```
   Template: RunPod PyTorch 2.0
   GPU: RTX 4090+ (推奨)
   Container Disk: 50GB+
   Volume: 不要（ビルドのみ）
   ```

2. **Web Terminal接続**
   - RunPodダッシュボードで **Connect** → **Start Web Terminal**
   - Jupyter Labが開いたら **Terminal** を選択

3. **プロジェクトセットアップ**
   ```bash
   # リポジトリクローン
   git clone https://github.com/mksd9/my-comfy-wan.git
   cd my-comfy-wan
   
   # 権限設定
   chmod +x build-on-runpod.sh
   ```

4. **Docker Hub認証設定**
   ```bash
   # Docker Hubアクセストークンを環境変数に設定
   export DOCKER_PASSWORD='your_docker_hub_token'
   
   # 認証確認
   echo "Docker password set: ${DOCKER_PASSWORD:0:10}..."
   ```

5. **ビルド実行**
   ```bash
   # 自動ビルドスクリプト実行（推奨）
   ./build-on-runpod.sh
   
   # 手動ビルドの場合
   docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push .
   ```

#### ✅ 期待される結果
```
🚀 RunPod Docker Build & Push Script
📊 System Information:
   GPU Info: NVIDIA GeForce RTX 4090, 24564
🔧 Setting up Docker environment...
🔑 Authenticating with Docker Hub...
🏗️ Creating BuildKit builder...
🔨 Building Docker image...
[プログレスバー表示]
✅ Build completed successfully!
   Build time: 28m 15s
   Image: nobukoyo/comfyui-wan-runpod:latest
🎬 Ready to deploy on RunPod!
```

#### 🎯 メリット
- **✅ 確実な成功**: 容量制限なし（50GB+）
- **⚡ 高速処理**: 高性能GPU環境での最適化
- **🔄 リアルタイム監視**: ビルドプロセスの直接確認
- **💰 コスト効率**: 必要な時のみRunPod使用
- **🚫 制限なし**: GitHub Actionsの時間・容量制限を回避

#### ⚠️ 注意事項
- **Docker Hubトークン**: 事前に取得・設定が必要
- **RunPod費用**: ビルド時間分のGPU使用料金が発生
- **ビルド時間**: 約25-35分（初回）、以降はキャッシュで高速化

### 🔧 **代替CIサービス検討**

GitHub Actionsの容量制限により、他のCIサービスでの実装を検討できます：

#### 🌟 **AWS CodeBuild**
- **容量制限**: 100GB～200GB
- **料金**: ビルド時間単位（約$0.005/分）
- **メリット**: 高容量、高性能、AWSとの統合
- **デメリット**: 設定が複雑、AWS知識が必要

#### 🌟 **Google Cloud Build**
- **容量制限**: 100GB
- **料金**: 1日120分無料、以降$0.003/分
- **メリット**: 高速、自動スケーリング、GCPとの統合
- **デメリット**: GCP知識が必要、設定が複雑

#### 🌟 **Azure Container Instances**
- **容量制限**: 20GB（カスタマイズ可能）
- **料金**: 実行時間単位
- **メリット**: Azureとの統合、柔軟性
- **デメリット**: 設定が複雑、Azure知識が必要

#### 🌟 **GitLab CI/CD**
- **容量制限**: 25GB（プレミアム）
- **料金**: 月額課金制
- **メリット**: GitLabとの統合、設定がシンプル
- **デメリット**: 月額費用、容量制限あり

#### 📋 **推奨度**
1. **RunPod直接ビルド**: ⭐⭐⭐⭐⭐ （最も確実）
2. **Google Cloud Build**: ⭐⭐⭐⭐
3. **AWS CodeBuild**: ⭐⭐⭐⭐
4. **Azure Container Instances**: ⭐⭐⭐
5. **GitLab CI/CD**: ⭐⭐⭐

### 🔧 **ローカルビルド手順（非推奨）**

#### 1. 準備作業
```bash
# 作業ディレクトリに移動
cd /path/to/my-comfy-wan

# 既存のイメージをクリーンアップ
docker system prune -a -f
docker buildx prune -a -f
```

#### 2. DockerHubログイン
```bash
docker login
# Username: nobukoyo
# Password: [your-token]
```

#### 3. マルチアーキテクチャビルダーの作成
```bash
docker buildx create --name multiarch-builder --use
docker buildx inspect --bootstrap
```

#### 4. イメージビルド & プッシュ
```bash
# WANモデルを含むイメージをビルド
docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push .

# 進捗確認
docker buildx ls
```

#### 5. クリーンアップ
```bash
# ビルダーを削除
docker buildx rm multiarch-builder

# システムクリーンアップ
docker system prune -a -f
docker buildx prune -a -f
```

### ⚡ **ワンライナー実行**
```bash
docker login && \
docker buildx create --name multiarch-builder --use && \
docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push . && \
docker buildx rm multiarch-builder && \
docker system prune -a -f && \
docker buildx prune -a -f && \
echo "✅ Deploy完了!"
```

### 🔍 **確認方法**

#### ローカル確認
```bash
# イメージが削除されていることを確認
docker images

# ファイル構造確認
ls -la
```

#### リモート確認
```bash
# DockerHub検索
docker search nobukoyo/comfyui-wan-runpod

# または https://hub.docker.com/ で確認
```

### 🛠️ **トラブルシューティング**

#### ビルドエラー
```bash
# 全削除してやり直し
docker system prune -a -f
docker buildx prune -a -f
docker buildx rm multiarch-builder 2>/dev/null || true

# 再ログイン
docker logout && docker login
```

#### 認証エラー
```bash
# トークンを確認
docker logout
docker login

# 再度ビルド
docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push .
```

#### 容量不足エラー
```bash
# 不要なイメージを削除
docker system prune -a -f
docker volume prune -f

# ディスク使用量確認
docker system df
```

### 📊 **予想スペック**
- **ビルド時間**: 25-35分（モデルダウンロード含む）
- **最終イメージサイズ**: 約15-18GB（軽量化済み）
- **必要ディスク容量**: 約20-22GB（ビルドキャッシュ含む）

### 🎯 **RunPod設定**
```
Container Image: nobukoyo/comfyui-wan-runpod:latest
Container Start Command: /start.sh
Ports: 6006
```

### 🔄 **更新時の注意点**
- カスタムノードの変更時は、`custom_nodes/` フォルダの内容を確認
- モデルファイルの更新時は、Dockerfile内のダウンロードURLを確認
- 新しいバージョンタグを使用する場合は、全てのファイルでタグを統一 