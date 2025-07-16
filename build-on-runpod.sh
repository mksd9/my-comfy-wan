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

# 必要なコマンドの存在チェック
command -v docker >/dev/null 2>&1 || error_exit "Dockerがインストールされていません"
command -v git >/dev/null 2>&1 || error_exit "gitがインストールされていません"

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
if docker buildx create --name runpod-builder --driver docker-container --use 2>/dev/null || docker buildx use runpod-builder; then
    success_msg "BuildKitビルダー準備完了"
else
    error_exit "BuildKitビルダーの作成に失敗しました"
fi

if docker buildx inspect --bootstrap; then
    success_msg "BuildKitビルダー初期化完了"
else
    error_exit "BuildKitビルダーの初期化に失敗しました"
fi

# ビルド実行
echo "🔨 Building Docker image..."
START_TIME=$(date +%s)

# ビルドをトラップで監視
trap 'echo -e "\n${RED}❌ ビルドが中断されました${NC}"; docker buildx rm runpod-builder >/dev/null 2>&1 || true; exit 1' INT TERM

if docker buildx build \
    --platform linux/amd64 \
    --tag "$FULL_IMAGE_NAME:latest" \
    --tag "$FULL_IMAGE_NAME:$(date +%Y%m%d)" \
    --push \
    --cache-from type=gha \
    --cache-to type=gha,mode=max \
    --progress=plain \
    .; then
    
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    echo ""
    success_msg "Build completed successfully!"
    echo "   Build time: $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
    echo "   Image: $FULL_IMAGE_NAME:latest"
    echo "   Daily tag: $FULL_IMAGE_NAME:$(date +%Y%m%d)"
    
    # Docker Hub確認
    echo "🔍 Verifying Docker Hub push..."
    if docker manifest inspect "$FULL_IMAGE_NAME:latest" >/dev/null 2>&1; then
        success_msg "Docker Hubへのプッシュ成功を確認"
    else
        warning_msg "Docker Hubプッシュの確認に失敗（ネットワーク遅延の可能性）"
    fi
    
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