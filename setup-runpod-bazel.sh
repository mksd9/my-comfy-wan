#!/bin/bash
# RunPod Bazel Docker Build - Complete Automation Script (rules_oci)

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
BAZELISK_VERSION="v1.20.0"

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
echo -e "${PURPLE}🚀 RunPod Bazel Docker Build${NC}"
echo -e "${PURPLE}   Complete Automation (rules_oci)${NC}"
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
    wget \
    unzip \
    ca-certificates \
    build-essential \
    git

success_msg "システムパッケージインストール完了"

# Step 4: Bazeliskインストール
step_msg "4. Bazeliskインストール"
if command -v bazel >/dev/null 2>&1; then
    info_msg "Bazel already installed: $(bazel version 2>/dev/null | head -1 || echo 'Version check failed')"
else
    info_msg "Bazelisk ${BAZELISK_VERSION} をダウンロード中..."
    wget -q "https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-linux-amd64" -O bazelisk
    
    info_msg "Bazeliskをインストール中..."
    chmod +x bazelisk
    cp bazelisk /usr/local/bin/bazel
    rm -f bazelisk
    
    success_msg "Bazeliskインストール完了"
fi

# Step 5: Bazelバージョン確認
step_msg "5. Bazelバージョン確認"
info_msg "Bazelバージョンを確認中..."
if bazel version >/dev/null 2>&1; then
    success_msg "Bazel準備完了: $(bazel version 2>/dev/null | head -1 || echo 'Bazel ready')"
else
    error_exit "Bazelの動作確認に失敗しました"
fi

# Step 6: Docker認証（crane使用のため）
step_msg "6. Docker認証設定"
info_msg "Docker Hub認証情報を設定中..."

# crane用の認証ファイル作成
mkdir -p ~/.docker
cat > ~/.docker/config.json << EOF
{
    "auths": {
        "https://index.docker.io/v1/": {
            "auth": "$(echo -n "${DOCKER_USER}:${DOCKER_PASSWORD}" | base64)"
        }
    }
}
EOF

success_msg "Docker Hub認証設定完了"

# Step 7: 実行権限設定
step_msg "7. スクリプトファイルの実行権限設定"
chmod +x start.sh
if [ -f "scripts/download_models.sh" ]; then
    chmod +x scripts/download_models.sh
fi
success_msg "実行権限設定完了"

# Step 8: Bazelワークスペースクリーン
step_msg "8. Bazelワークスペースクリーン"
info_msg "Bazelキャッシュをクリーンアップ中..."
bazel clean --expunge >/dev/null 2>&1 || true
success_msg "Bazelワークスペースクリーンアップ完了"

# Step 9: ビルド実行
step_msg "9. OCI イメージビルド・プッシュ実行"
echo ""
echo -e "${YELLOW}⚠️ ビルドを開始します。完了まで25-35分かかる場合があります。${NC}"
echo ""
read -p "続行しますか？ (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo "ビルドを中止しました。"
    exit 0
fi

info_msg "OCI イメージビルド・プッシュを開始中..."
echo "推定完了時間: 25-35分（初回）、15-20分（キャッシュあり）"
echo "RunPod推定コスト: $2-4（RTX 4090）"
echo ""

START_TIME=$(date +%s)

# ビルドをトラップで監視
trap 'echo -e "\n${RED}❌ ビルドが中断されました${NC}"; exit 1' INT TERM

# メインビルドコマンド実行
info_msg "Bazel OCI Push を実行中..."
if bazel run //:push_custom_image --verbose_failures; then
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    echo ""
    success_msg "🎉 ビルド完了！"
    echo ""
    echo "📊 ビルド結果:"
    echo "   ⏱️  ビルド時間: $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
    echo "   🏷️  イメージ: ${DOCKER_USER}/${IMAGE_NAME}:latest"
    
    # 日付タグ付きビルドも実行
    info_msg "日付タグ付きイメージもプッシュ中..."
    if bazel run //:push_custom_image_dated --verbose_failures; then
        success_msg "日付タグ付きイメージプッシュ完了: $(date +%Y%m%d)"
    else
        warning_msg "日付タグ付きイメージプッシュに失敗（メインビルドは成功）"
    fi
    
    # コスト計算
    COST_PER_MINUTE=0.06  # RTX 4090のおおよその料金
    ESTIMATED_COST=$(echo "scale=2; $BUILD_TIME * $COST_PER_MINUTE / 60" | bc 2>/dev/null || echo "計算不可")
    echo "   💰 推定コスト: \$${ESTIMATED_COST}"
    echo ""
    
    # 確認方法
    echo "🔍 確認方法:"
    echo "   Docker Hub: https://hub.docker.com/r/${DOCKER_USER}/${IMAGE_NAME}"
    echo "   RunPod設定:"
    echo "     Container Image: ${DOCKER_USER}/${IMAGE_NAME}:latest"
    echo "     Container Start Command: /start.sh"
    echo "     Ports: 6006, 8888"
    echo ""
    
    success_msg "🎬 Ready to deploy on RunPod!"
    
else
    error_exit "ビルドに失敗しました。ログを確認してください"
fi

# Step 10: 完了メッセージ
echo ""
echo "=================================================================="
success_msg "🎉 RunPod Bazel Docker Build 完了！"
echo "=================================================================="
echo ""
echo -e "${GREEN}✅ 次のステップ：${NC}"
echo "1. RunPodでテンプレートを作成"
echo "2. Container Image: ${DOCKER_USER}/${IMAGE_NAME}:latest"
echo "3. Container Start Command: /start.sh"
echo "4. Ports: 6006, 8888"
echo ""