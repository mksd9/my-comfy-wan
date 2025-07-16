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

# 環境変数チェック
if [ -z "$DOCKER_PASSWORD" ]; then
    echo "❌ Error: DOCKER_PASSWORD環境変数が設定されていません"
    echo "以下のコマンドで設定してください:"
    echo "export DOCKER_PASSWORD='your_docker_hub_token'"
    exit 1
fi

# システム情報表示
echo "📊 System Information:"
echo "   OS: $(uname -a)"
echo "   Docker Version: $(docker --version)"
echo "   Available Space: $(df -h / | tail -1 | awk '{print $4}')"
echo "   GPU Info: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)"
echo ""

# Docker環境準備
echo "🔧 Setting up Docker environment..."
docker system prune -f
docker buildx prune -f

# Docker Hub認証
echo "🔑 Authenticating with Docker Hub..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin

# BuildKitビルダー作成
echo "🏗️ Creating BuildKit builder..."
docker buildx create --name runpod-builder --driver docker-container --use || true
docker buildx inspect --bootstrap

# ビルド実行
echo "🔨 Building Docker image..."
START_TIME=$(date +%s)

docker buildx build \
    --platform linux/amd64 \
    --tag "$FULL_IMAGE_NAME:latest" \
    --tag "$FULL_IMAGE_NAME:$(date +%Y%m%d)" \
    --push \
    --cache-from type=gha \
    --cache-to type=gha,mode=max \
    --progress=plain \
    .

END_TIME=$(date +%s)
BUILD_TIME=$((END_TIME - START_TIME))

echo ""
echo "✅ Build completed successfully!"
echo "   Build time: $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
echo "   Image: $FULL_IMAGE_NAME:latest"
echo "   Daily tag: $FULL_IMAGE_NAME:$(date +%Y%m%d)"

# クリーンアップ
echo "🧹 Cleaning up..."
docker buildx rm runpod-builder || true
docker system prune -f

echo ""
echo "🎬 Ready to deploy on RunPod!"
echo "Container Image: $FULL_IMAGE_NAME:latest"
echo "Container Start Command: /start.sh"
echo "Ports: 6006, 8888"