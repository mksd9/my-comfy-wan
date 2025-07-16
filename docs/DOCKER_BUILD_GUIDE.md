# Docker Build & Deploy Guide
## ComfyUI WAN RunPod Template

### 🎯 **概要**
このガイドでは、ComfyUI WAN RunPod Template のDockerイメージをビルドし、DockerHubにデプロイする手順を説明します。

### 📋 **前提条件**
- Docker Desktop がインストールされていること
- DockerHub アカウントを持っていること
- 十分なディスク容量（約20-22GB）があること

### 🚀 **推奨: GitHub Actions自動ビルド**
Macローカルでのストレージ不足を回避するため、GitHub Actionsでの自動ビルドを推奨します。

#### セットアップ手順
1. **GitHub Secrets設定**
   - `DOCKER_USERNAME`: DockerHubユーザー名
   - `DOCKER_PASSWORD`: DockerHubアクセストークン

2. **Docker Hubアクセストークン取得**
   ```
   1. Docker Hub → Account Settings → Security
   2. "New Access Token"をクリック
   3. Token Name: "github-actions-wan-build"
   4. Permissions: "Read, Write, Delete"
   5. 生成されたトークンをコピー
   ```

3. **GitHub Secrets設定**
   ```
   1. GitHubリポジトリ → Settings → Secrets and variables → Actions
   2. "New repository secret"をクリック
   3. Name: DOCKER_USERNAME, Value: nobukoyo
   4. Name: DOCKER_PASSWORD, Value: [上記で取得したトークン]
   ```

4. **自動ビルド実行**
   ```bash
   # mainブランチにプッシュするだけで自動ビルド開始
   git push origin main
   
   # または手動実行
   # GitHub → Actions → "Build and Push Docker Image" → "Run workflow"
   ```

### 🔥 **RunPod上でのビルド（高速・大容量対応）**
GitHub Actionsの制限を回避し、RunPod上で直接ビルドする方法です。

#### セットアップ手順
1. **RunPodインスタンス起動**
   ```
   Template: RunPod PyTorch 2.0
   GPU: RTX 4090+ (推奨)
   Container Disk: 50GB+
   ```

2. **リポジトリクローン**
   ```bash
   git clone https://github.com/your-username/my-comfy-wan.git
   cd my-comfy-wan
   ```

3. **Docker Hub認証設定**
   ```bash
   # Docker Hubトークンを環境変数に設定
   export DOCKER_PASSWORD='your_docker_hub_token'
   ```

4. **ビルド実行**
   ```bash
   # 自動ビルドスクリプト実行
   ./build-on-runpod.sh
   
   # 手動ビルドの場合
   docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push .
   ```

#### メリット
- **高速ビルド**: 高性能GPU環境での高速処理
- **大容量対応**: 50GB+の十分なストレージ
- **無制限**: GitHub Actionsの時間制限なし
- **直接操作**: ビルドプロセスの直接監視・制御

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