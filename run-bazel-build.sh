#!/bin/bash
# RunPod Bazel Docker Build Execution Script

set -e

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo -e "${CYAN}📋 $1${NC}"
}

# Welcome screen
echo "=================================================================="
echo -e "${PURPLE}🚀 RunPod Bazel Docker Build Execution${NC}"
echo -e "${PURPLE}   公式ドキュメント準拠版${NC}"
echo "=================================================================="
echo ""

# 前提条件チェック
step_msg "前提条件チェック"

# Bazelインストール確認
if ! command -v bazel >/dev/null 2>&1; then
    error_exit "Bazelがインストールされていません。./setup-bazel-build.sh を先に実行してください"
fi

# 必要ファイル確認
required_files=("WORKSPACE.bazel" "BUILD.bazel" ".bazelrc" "Dockerfile")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        error_exit "必要なファイルが見つかりません: $file\n./setup-bazel-build.sh を先に実行してください"
    fi
done

success_msg "前提条件チェック完了"

# システム情報表示
step_msg "システム情報"
echo "   Bazel Version: $(bazel version --gnu_format | head -1)"
echo "   Available Space: $(df -h / | tail -1 | awk '{print $4}')"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "   GPU Info: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)"
fi
echo ""

# ビルド開始確認
echo -e "${YELLOW}⚠️ ビルドを開始します。完了まで25-35分かかる場合があります。${NC}"
echo ""
read -p "続行しますか？ (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo "ビルドを中止しました。"
    exit 0
fi

# ビルド実行
step_msg "Bazelビルド実行"
START_TIME=$(date +%s)

info_msg "ビルドを開始中..."
echo "推定完了時間: 25-35分（初回）、15-20分（キャッシュあり）"
echo "RunPod推定コスト: $2-4（RTX 4090）"
echo ""

# ビルドをトラップで監視
trap 'echo -e "\n${RED}❌ ビルドが中断されました${NC}"; exit 1' INT TERM

# メインビルドコマンド実行
info_msg "Docker イメージをビルド中..."
if bazel run //:push_custom_image --verbose_failures --show_progress; then
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    
    echo ""
    success_msg "🎉 ビルド完了！"
    echo ""
    echo "📊 ビルド結果:"
    echo "   ⏱️  ビルド時間: $((BUILD_TIME / 60))m $((BUILD_TIME % 60))s"
    echo "   🏷️  イメージ: nobukoyo/comfyui-wan-runpod:latest"
    
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
    echo "   Docker Hub: https://hub.docker.com/r/nobukoyo/comfyui-wan-runpod"
    echo "   RunPod設定:"
    echo "     Container Image: nobukoyo/comfyui-wan-runpod:latest"
    echo "     Container Start Command: /start.sh"
    echo "     Ports: 6006, 8888"
    echo ""
    
    success_msg "🎬 Ready to deploy on RunPod!"
    
else
    error_exit "ビルドに失敗しました。ログを確認してください"
fi

# クリーンアップ（オプション）
echo ""
read -p "ビルドキャッシュをクリーンアップしますか？ (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    step_msg "クリーンアップ実行"
    bazel clean --expunge
    success_msg "クリーンアップ完了"
fi

echo ""
echo "=================================================================="
success_msg "🎉 Bazelビルドプロセス完了！"
echo "=================================================================="