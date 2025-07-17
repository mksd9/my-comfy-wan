#!/bin/bash
# RunPod Bazel Docker Build Setup Script (公式ドキュメント準拠)

set -e

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 設定
DOCKER_USER="nobukoyo"
IMAGE_NAME="comfyui-wan-runpod"
FULL_IMAGE_NAME="$DOCKER_USER/$IMAGE_NAME"

# Functions
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

info_msg() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

step_msg() {
    echo -e "${CYAN}📋 Step: $1${NC}"
}

# Welcome screen
echo "=================================================================="
echo -e "${PURPLE}🚀 RunPod Bazel Docker Build Setup${NC}"
echo -e "${PURPLE}   公式ドキュメント準拠版${NC}"
echo "=================================================================="
echo ""

# Step 1: 環境変数チェック
step_msg "1. 環境変数チェック"
if [ -z "$DOCKER_PASSWORD" ]; then
    error_exit "DOCKER_PASSWORD環境変数が設定されていません\n以下のコマンドで設定してください:\nexport DOCKER_PASSWORD='your_docker_hub_token'"
fi
success_msg "Docker Hub認証情報確認完了"

# Step 2: システム情報表示
step_msg "2. システム情報確認"
echo "   OS: $(uname -a)"
echo "   Available Space: $(df -h / | tail -1 | awk '{print $4}')"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "   GPU Info: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)"
fi
echo ""

# Step 3: 必要なパッケージのインストール
step_msg "3. 必要なパッケージのインストール"
info_msg "システムパッケージを更新中..."
apt-get update -qq

info_msg "必要なパッケージをインストール中..."
apt-get install -y -qq \
    curl \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    build-essential \
    python3 \
    python3-pip

success_msg "システムパッケージインストール完了"

# Step 4: Bazelインストール
step_msg "4. Bazelインストール"
if command -v bazel >/dev/null 2>&1; then
    info_msg "Bazel already installed: $(bazel version --gnu_format | head -1)"
else
    info_msg "Bazel GPGキーを追加中..."
    curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg
    mv bazel.gpg /etc/apt/trusted.gpg.d/
    
    info_msg "Bazel APTリポジトリを追加中..."
    echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" > /etc/apt/sources.list.d/bazel.list
    
    info_msg "Bazelをインストール中..."
    apt-get update -qq
    apt-get install -y -qq bazel
    
    success_msg "Bazelインストール完了: $(bazel version --gnu_format | head -1)"
fi

# Step 5: Bazelワークスペースファイル作成
step_msg "5. Bazelワークスペースファイル作成"
info_msg "WORKSPACE.bazelファイルを作成中..."
cat > WORKSPACE.bazel << 'EOF'
# ComfyUI WAN RunPod Template - Bazel Workspace

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Docker rules for Bazel
http_archive(
    name = "io_bazel_rules_docker",
    sha256 = "b1e80761a8a8243d03ebca8845e9cc1ba6c82ce7c5179ce2b295cd36f7e394bf",
    urls = ["https://github.com/bazelbuild/rules_docker/releases/download/v0.25.0/rules_docker-v0.25.0.tar.gz"],
)

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load("@io_bazel_rules_docker//repositories:deps.bzl", container_deps = "deps")

container_deps()

load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_pull",
)

# Pull base image
container_pull(
    name = "cuda_base",
    registry = "index.docker.io",
    repository = "nvidia/cuda",
    tag = "12.3.2-devel-ubuntu22.04",
)
EOF

success_msg "WORKSPACE.bazelファイル作成完了"

# Step 6: BUILD.bazelファイル作成
step_msg "6. BUILD.bazelファイル作成"
info_msg "BUILD.bazelファイルを作成中..."
cat > BUILD.bazel << EOF
# ComfyUI WAN RunPod Template - Bazel Build Configuration

load("@io_bazel_rules_docker//container:container.bzl", "container_image", "container_push")

# Docker image build
container_image(
    name = "comfyui_wan_image",
    base = "@cuda_base//image",
    files = [
        "start.sh",
        "scripts/download_models.sh",
        "runpod.yaml",
    ],
    directory = "/",
    dockerfile = ":Dockerfile",
    visibility = ["//visibility:public"],
)

# Docker push to registry
container_push(
    name = "push_custom_image",
    image = ":comfyui_wan_image",
    format = "Docker",
    registry = "index.docker.io",
    repository = "$FULL_IMAGE_NAME",
    tag = "latest",
)

# Additional tags
container_push(
    name = "push_custom_image_dated",
    image = ":comfyui_wan_image",
    format = "Docker",
    registry = "index.docker.io",
    repository = "$FULL_IMAGE_NAME",
    tag = "$(date +%Y%m%d)",
)
EOF

success_msg "BUILD.bazelファイル作成完了"

# Step 7: .bazelrcファイル作成（最適化設定）
step_msg "7. Bazel設定ファイル作成"
info_msg ".bazelrcファイルを作成中..."
cat > .bazelrc << 'EOF'
# ComfyUI WAN RunPod Template - Bazel Configuration

# Build settings
build --show_progress_rate_limit=5
build --curses=yes
build --color=yes
build --verbose_failures
build --sandbox_debug

# Docker settings
build --host_jvm_args=-Dbazel.DigestFunction=SHA256

# Performance settings
build --jobs=auto
build --local_ram_resources=HOST_RAM*0.75
build --local_cpu_resources=HOST_CPUS*0.75

# Cache settings
build --repository_cache=/tmp/bazel_repository_cache
build --disk_cache=/tmp/bazel_disk_cache
EOF

success_msg ".bazelrcファイル作成完了"

# Step 8: Docker Hub認証
step_msg "8. Docker Hub認証"
info_msg "Docker Hubにログイン中..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin
success_msg "Docker Hub認証完了"

# Step 9: 実行権限設定
step_msg "9. スクリプトファイルの実行権限設定"
chmod +x start.sh
chmod +x scripts/download_models.sh
success_msg "実行権限設定完了"

# Step 10: 完了メッセージ
echo ""
echo "=================================================================="
success_msg "🎉 Bazelセットアップ完了！"
echo "=================================================================="
echo ""
echo -e "${BLUE}次のステップ：${NC}"
echo "1. Bazelビルドを実行："
echo -e "   ${CYAN}bazel run //:push_custom_image${NC}"
echo ""
echo "2. 日付タグ付きビルドを実行："
echo -e "   ${CYAN}bazel run //:push_custom_image_dated${NC}"
echo ""
echo "3. ビルド状況確認："
echo -e "   ${CYAN}bazel query //...${NC}"
echo ""
echo -e "${GREEN}推定ビルド時間: 25-35分${NC}"
echo -e "${GREEN}推定コスト: \$2-4 (RTX 4090)${NC}"
echo ""