#!/bin/bash
# RunPod上でDockerイメージをビルド・プッシュするスクリプト

set -e

echo "==================================================="
echo "🚀 RunPod Docker Build & Push Script"
echo "==================================================="

# 設定
DOCKER_USER="nobukoyo"
IMAGE_NAME="comfyui-wan-runpod"
FULL_IMAGE_NAME="$DOCKER_USER/$IMAGE_NAME"

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# エラーハンドリング関数
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}"
    exit 1
}

success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning_msg() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# 環境変数チェック
if [ -z "$DOCKER_PASSWORD" ]; then
    error_exit "DOCKER_PASSWORD環境変数が設定されていません\n以下のコマンドで設定してください:\nexport DOCKER_PASSWORD='your_docker_hub_token'"
fi

# Dockerインストールチェック・自動インストール
if ! command -v docker >/dev/null 2>&1; then
    echo "🔧 Dockerがインストールされていません。自動インストールを開始します..."
    
    # Update package list
    apt-get update -qq
    
    # Install Docker
    echo "📦 Dockerをインストール中..."
    if curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh; then
        success_msg "Dockerインストール完了"
        
        # Start Docker daemon (RunPod compatible)
        echo "🚀 Dockerサービスを開始中..."
        
        # Check if Docker daemon is already running
        if ! docker info >/dev/null 2>&1; then
            # Start Docker daemon in background for RunPod environment
            echo "📡 Docker daemonをバックグラウンドで起動中..."
            nohup dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 >/dev/null 2>&1 &
            DOCKER_PID=$!
            
            # Wait for Docker to be ready with retry mechanism
            echo "⏳ Docker daemonの準備待ち..."
            DOCKER_READY=false
            for i in {1..30}; do
                if docker info >/dev/null 2>&1; then
                    DOCKER_READY=true
                    break
                fi
                echo "  待機中... ($i/30)"
                sleep 2
            done
            
            if [ "$DOCKER_READY" = true ]; then
                success_msg "Docker daemon起動完了（PID: $DOCKER_PID）"
            else
                error_exit "Docker daemonの起動がタイムアウトしました"
            fi
        else
            success_msg "Docker daemon already running"
        fi
        
        # Verify Docker installation
        if docker --version; then
            success_msg "Docker準備完了: $(docker --version)"
        else
            error_exit "Dockerの動作確認に失敗しました"
        fi
        
        # Clean up install script
        rm -f get-docker.sh
    else
        error_exit "Dockerのインストールに失敗しました"
    fi
else
    echo "✅ Docker already installed: $(docker --version)"
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo "🚀 既存のDockerでdaemonを起動中..."
        nohup dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 >/dev/null 2>&1 &
        DOCKER_PID=$!
        
        # Wait for Docker to be ready
        echo "⏳ Docker daemonの準備待ち..."
        DOCKER_READY=false
        for i in {1..15}; do
            if docker info >/dev/null 2>&1; then
                DOCKER_READY=true
                break
            fi
            echo "  待機中... ($i/15)"
            sleep 2
        done
        
        if [ "$DOCKER_READY" = true ]; then
            success_msg "Docker daemon起動完了（PID: $DOCKER_PID）"
        else
            error_exit "Docker daemonの起動がタイムアウトしました"
        fi
    else
        success_msg "Docker daemon already running"
    fi
fi

# 必要なコマンドの存在チェック
command -v git >/dev/null 2>&1 || error_exit "gitがインストールされていません"
command -v curl >/dev/null 2>&1 || error_exit "curlがインストールされていません"

# ネットワーク接続チェック
echo "🌐 Checking network connectivity..."
NETWORK_RETRIES=3
for i in $(seq 1 $NETWORK_RETRIES); do
    if curl -s --max-time 10 https://hub.docker.com >/dev/null 2>&1; then
        success_msg "Docker Hub接続確認"
        break
    else
        if [ $i -eq $NETWORK_RETRIES ]; then
            error_exit "Docker Hubへの接続に失敗しました。ネットワーク接続を確認してください"
        else
            warning_msg "Docker Hub接続確認失敗 ($i/$NETWORK_RETRIES)、再試行中..."
            sleep 3
        fi
    fi
done

# GitHub接続確認
for i in $(seq 1 $NETWORK_RETRIES); do
    if curl -s --max-time 10 https://github.com >/dev/null 2>&1; then
        success_msg "GitHub接続確認"
        break
    else
        if [ $i -eq $NETWORK_RETRIES ]; then
            warning_msg "GitHubへの接続に失敗しました。一部の機能が制限される可能性があります"
        else
            warning_msg "GitHub接続確認失敗 ($i/$NETWORK_RETRIES)、再試行中..."
            sleep 3
        fi
    fi
done

# システム情報表示
echo "📊 System Information:"
echo "   OS: $(uname -a)"
echo "   Docker Version: $(docker --version)"
echo "   Available Space: $(df -h / | tail -1 | awk '{print $4}')"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "   GPU Info: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)"
else
    warning_msg "GPU情報を取得できません（nvidia-smi未検出）"
fi
echo ""

# ディスク容量チェック
AVAILABLE_SPACE=$(df --output=avail / | tail -1)
MIN_SPACE=20000000  # 20GB in KB
if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE" ]; then
    error_exit "ディスク容量不足です。最低20GB必要です。現在: $(df -h / | tail -1 | awk '{print $4}')"
fi

# Check if there's an existing build that can be resumed
if docker buildx ls | grep -q "runpod-builder"; then
    warning_msg "既存のビルダーが見つかりました。継続しますか？"
    echo "既存ビルダーの情報:"
    docker buildx ls | grep "runpod-builder" || true
    echo ""
fi

# Docker環境準備
echo "🔧 Setting up Docker environment..."
docker system prune -f || warning_msg "Docker pruneでエラーが発生しましたが続行します"
docker buildx prune -f || warning_msg "BuildKit pruneでエラーが発生しましたが続行します"

# Docker Hub認証
echo "🔑 Authenticating with Docker Hub..."
if echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin; then
    success_msg "Docker Hub認証成功"
else
    error_exit "Docker Hub認証に失敗しました。トークンを確認してください"
fi

# BuildKitビルダー作成
echo "🏗️ Creating BuildKit builder..."

# Remove existing builder if it's in a bad state
if docker buildx ls | grep -q "runpod-builder"; then
    BUILDER_STATUS=$(docker buildx ls | grep "runpod-builder" | awk '{print $3}' || echo "unknown")
    if [ "$BUILDER_STATUS" = "inactive" ] || [ "$BUILDER_STATUS" = "unknown" ]; then
        warning_msg "既存ビルダーが不安定な状態です。再作成します..."
        docker buildx rm runpod-builder >/dev/null 2>&1 || true
    fi
fi

# Create or use existing builder
if ! docker buildx ls | grep -q "runpod-builder"; then
    echo "新しいビルダーを作成中..."
    if docker buildx create --name runpod-builder \
        --driver docker-container \
        --driver-opt network=host \
        --buildkitd-flags '--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host' \
        --use; then
        success_msg "BuildKitビルダー作成完了"
    else
        error_exit "BuildKitビルダーの作成に失敗しました"
    fi
else
    echo "既存のビルダーを使用します..."
    if docker buildx use runpod-builder; then
        success_msg "既存ビルダーに切り替え完了"
    else
        error_exit "既存ビルダーへの切り替えに失敗しました"
    fi
fi

# Bootstrap the builder with retry mechanism
echo "ビルダーを初期化中..."
BOOTSTRAP_RETRIES=3
for i in $(seq 1 $BOOTSTRAP_RETRIES); do
    if docker buildx inspect --bootstrap; then
        success_msg "BuildKitビルダー初期化完了"
        break
    else
        if [ $i -eq $BOOTSTRAP_RETRIES ]; then
            error_exit "BuildKitビルダーの初期化に失敗しました（$BOOTSTRAP_RETRIES回試行）"
        else
            warning_msg "初期化失敗 ($i/$BOOTSTRAP_RETRIES)、再試行中..."
            sleep 5
        fi
    fi
done

# ビルド実行
echo "🔨 Building Docker image..."
echo "推定完了時間: 25-35分（初回）、15-20分（キャッシュあり）"
echo "RunPod推定コスト: $2-4（RTX 4090）"
echo ""

START_TIME=$(date +%s)

# ビルドをトラップで監視
trap 'echo -e "\n${RED}❌ ビルドが中断されました${NC}"; docker buildx rm runpod-builder >/dev/null 2>&1 || true; exit 1' INT TERM

# Enhanced build with better cache strategy and error recovery
echo "📊 ビルド設定:"
echo "   プラットフォーム: linux/amd64"
echo "   タグ: $FULL_IMAGE_NAME:latest, $FULL_IMAGE_NAME:$(date +%Y%m%d)"
echo "   キャッシュ: Registry cache (Docker Hub)"
echo "   進捗表示: 詳細モード"
echo ""

# Build with enhanced configuration
if docker buildx build \
    --platform linux/amd64 \
    --tag "$FULL_IMAGE_NAME:latest" \
    --tag "$FULL_IMAGE_NAME:$(date +%Y%m%d)" \
    --push \
    --cache-from type=registry,ref="$FULL_IMAGE_NAME:cache" \
    --cache-to type=registry,ref="$FULL_IMAGE_NAME:cache",mode=max \
    --progress=plain \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --metadata-file /tmp/build-metadata.json \
    .; then
    
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    echo ""
    success_msg "🎉 Build completed successfully!"
    echo ""
    echo "📊 ビルド結果:"
    echo "   ⏱️  ビルド時間: $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
    echo "   🏷️  イメージ: $FULL_IMAGE_NAME:latest"
    echo "   📅 日付タグ: $FULL_IMAGE_NAME:$(date +%Y%m%d)"
    
    # Extract build metadata if available
    if [ -f "/tmp/build-metadata.json" ]; then
        echo "   📁 メタデータ: /tmp/build-metadata.json に保存"
    fi
    
    # Calculate estimated cost (approximate)
    COST_PER_MINUTE=0.06  # Approximate cost for RTX 4090 on RunPod
    ESTIMATED_COST=$(echo "scale=2; $BUILD_TIME * $COST_PER_MINUTE / 60" | bc 2>/dev/null || echo "計算不可")
    echo "   💰 推定コスト: \$${ESTIMATED_COST}"
    echo ""
    
    # Docker Hub確認
    echo "🔍 Verifying Docker Hub push..."
    VERIFY_RETRIES=3
    for i in $(seq 1 $VERIFY_RETRIES); do
        if docker manifest inspect "$FULL_IMAGE_NAME:latest" >/dev/null 2>&1; then
            success_msg "Docker Hubへのプッシュ成功を確認"
            
            # Get image size information
            IMAGE_SIZE=$(docker manifest inspect "$FULL_IMAGE_NAME:latest" | grep -o '"size":[0-9]*' | cut -d':' -f2 | head -1)
            if [ -n "$IMAGE_SIZE" ] && [ "$IMAGE_SIZE" -gt 0 ]; then
                IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
                echo "   📦 イメージサイズ: ${IMAGE_SIZE_MB}MB"
            fi
            break
        else
            if [ $i -eq $VERIFY_RETRIES ]; then
                warning_msg "Docker Hubプッシュの確認に失敗（ネットワーク遅延の可能性）"
                echo "   手動確認URL: https://hub.docker.com/r/$DOCKER_USER/$IMAGE_NAME"
            else
                echo "検証中... ($i/$VERIFY_RETRIES)"
                sleep 10
            fi
        fi
    done
    
else
    error_exit "ビルドに失敗しました。ログを確認してください"
fi

# クリーンアップ
echo "🧹 Cleaning up..."
docker buildx rm runpod-builder >/dev/null 2>&1 || warning_msg "ビルダーの削除に失敗（既に削除済みの可能性）"
docker system prune -f || warning_msg "システムクリーンアップに失敗"

echo ""
success_msg "🎬 Ready to deploy on RunPod!"
echo "Container Image: $FULL_IMAGE_NAME:latest"
echo "Container Start Command: /start.sh"
echo "Ports: 6006, 8888"
echo ""
echo "🔗 Docker Hub: https://hub.docker.com/r/$DOCKER_USER/$IMAGE_NAME"
echo "📚 Deploy Guide: https://github.com/mksd9/my-comfy-wan#readme"