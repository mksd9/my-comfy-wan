#!/bin/bash
# Interactive Setup Guide for ComfyUI WAN RunPod Template
set -e

# Color codes
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

highlight_msg() {
    echo -e "${PURPLE}🎯 $1${NC}"
}

step_msg() {
    echo -e "${CYAN}📋 $1${NC}"
}

# Welcome screen
show_welcome() {
    clear
    echo "=================================================================="
    echo -e "${PURPLE}🚀 ComfyUI WAN RunPod Template${NC}"
    echo -e "${PURPLE}   Interactive Setup Guide${NC}"
    echo "=================================================================="
    echo ""
    echo -e "${BLUE}このガイドは以下をサポートします：${NC}"
    echo "  📦 Docker Hub認証の設定"
    echo "  🏗️ 最適化されたビルドプロセス"
    echo "  💡 初心者向けステップバイステップガイド"
    echo "  🔍 システム要件チェック"
    echo "  💰 コスト見積もり"
    echo ""
    echo -e "${GREEN}推定所要時間: 25-35分（初回）、15-20分（キャッシュあり）${NC}"
    echo -e "${GREEN}推定コスト: \$2-4（RTX 4090）${NC}"
    echo ""
}

# System requirements check
check_requirements() {
    step_msg "Step 1: システム要件チェック"
    echo ""
    
    # Check if we're on RunPod
    if [ -n "$RUNPOD_POD_ID" ]; then
        success_msg "RunPod環境を検出"
        echo "   Pod ID: $RUNPOD_POD_ID"
    else
        warning_msg "RunPod環境ではありません。続行しますか？"
        echo -n "続行する場合は 'yes' を入力: "
        read -r response
        if [ "$response" != "yes" ]; then
            echo "セットアップを中止しました。"
            exit 0
        fi
    fi
    
    # Check disk space
    echo ""
    info_msg "ディスク容量をチェック中..."
    AVAILABLE_SPACE=$(df --output=avail / | tail -1)
    AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
    MIN_SPACE_GB=20
    
    if [ "$AVAILABLE_GB" -ge "$MIN_SPACE_GB" ]; then
        success_msg "ディスク容量OK (${AVAILABLE_GB}GB利用可能)"
    else
        error_exit "ディスク容量不足です。最低${MIN_SPACE_GB}GB必要です。現在: ${AVAILABLE_GB}GB"
    fi
    
    # Check GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
        GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)
        success_msg "GPU検出: $GPU_INFO"
    else
        warning_msg "GPU情報を取得できません"
    fi
    
    echo ""
    highlight_msg "システム要件チェック完了！"
    echo ""
}

# Docker Hub setup
setup_docker_hub() {
    step_msg "Step 2: Docker Hub認証設定"
    echo ""
    
    info_msg "Docker Hubアカウントのアクセストークンが必要です"
    echo "   1. https://hub.docker.com にログイン"
    echo "   2. Account Settings > Security > New Access Token"
    echo "   3. トークンをコピー"
    echo ""
    
    # Check if DOCKER_PASSWORD is already set
    if [ -n "$DOCKER_PASSWORD" ]; then
        success_msg "Docker認証情報は既に設定済みです"
        echo -n "再設定しますか？ (y/N): "
        read -r response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            return 0
        fi
    fi
    
    echo -n "Docker Hubアクセストークンを入力してください: "
    read -s DOCKER_TOKEN
    echo ""
    
    if [ -z "$DOCKER_TOKEN" ]; then
        error_exit "トークンが入力されていません"
    fi
    
    # Validate token length (Docker Hub tokens are typically 36-40 characters)
    if [ ${#DOCKER_TOKEN} -lt 20 ]; then
        error_exit "トークンが短すぎます。正しいトークンを入力してください"
    fi
    
    export DOCKER_PASSWORD="$DOCKER_TOKEN"
    success_msg "Docker認証情報を設定しました"
    
    # Test authentication
    info_msg "認証をテスト中..."
    if echo "$DOCKER_PASSWORD" | docker login -u nobukoyo --password-stdin >/dev/null 2>&1; then
        success_msg "Docker Hub認証成功"
    else
        error_exit "認証に失敗しました。トークンを確認してください"
    fi
    
    echo ""
    highlight_msg "Docker Hub認証設定完了！"
    echo ""
}

# Build configuration
configure_build() {
    step_msg "Step 3: ビルド設定"
    echo ""
    
    info_msg "ビルド設定を確認してください："
    echo "   📦 イメージ名: nobukoyo/comfyui-wan-runpod"
    echo "   🏷️ タグ: latest, $(date +%Y%m%d)"
    echo "   🌐 プラットフォーム: linux/amd64"
    echo "   💾 キャッシュ: Docker Hub Registry"
    echo ""
    
    echo -n "この設定でビルドを開始しますか？ (Y/n): "
    read -r response
    if [ "$response" = "n" ] || [ "$response" = "N" ]; then
        echo "ビルドを中止しました。"
        exit 0
    fi
    
    echo ""
    highlight_msg "ビルド設定確認完了！"
    echo ""
}

# Execute build
execute_build() {
    step_msg "Step 4: ビルド実行"
    echo ""
    
    warning_msg "ビルドを開始します。完了まで25-35分かかる場合があります。"
    echo ""
    echo -n "続行しますか？ (Y/n): "
    read -r response
    if [ "$response" = "n" ] || [ "$response" = "N" ]; then
        echo "ビルドを中止しました。"
        exit 0
    fi
    
    echo ""
    info_msg "ビルドスクリプトを実行中..."
    
    # Make sure build script is executable
    chmod +x ./build-on-runpod.sh
    
    # Execute the build script
    if ./build-on-runpod.sh; then
        echo ""
        success_msg "🎉 ビルドが正常に完了しました！"
        echo ""
        echo "📋 次のステップ:"
        echo "  1. RunPodでテンプレートを作成"
        echo "  2. Container Image: nobukoyo/comfyui-wan-runpod:latest"
        echo "  3. Container Start Command: /start.sh"
        echo "  4. Ports: 6006 (ComfyUI), 8888 (Jupyter Lab)"
        echo ""
        echo "🔗 詳細なガイド: https://github.com/mksd9/my-comfy-wan#readme"
    else
        error_exit "ビルドに失敗しました。ログを確認してください"
    fi
}

# Show final instructions
show_final_instructions() {
    echo ""
    echo "=================================================================="
    echo -e "${GREEN}🎬 セットアップ完了！${NC}"
    echo "=================================================================="
    echo ""
    echo -e "${BLUE}RunPodでの使用方法：${NC}"
    echo "  1. RunPod Dashboard で 'New Template' をクリック"
    echo "  2. 以下の設定を入力："
    echo -e "     ${CYAN}Container Image:${NC} nobukoyo/comfyui-wan-runpod:latest"
    echo -e "     ${CYAN}Container Start Command:${NC} /start.sh"
    echo -e "     ${CYAN}Expose HTTP Ports:${NC} 6006,8888"
    echo "  3. 'Create Template' をクリック"
    echo "  4. テンプレートからPodを起動"
    echo ""
    echo -e "${BLUE}アクセス方法：${NC}"
    echo -e "  🎨 ${CYAN}ComfyUI:${NC} HTTP サービス Port 6006"
    echo -e "  🔬 ${CYAN}Jupyter Lab:${NC} HTTP サービス Port 8888"
    echo ""
    echo -e "${GREEN}Happy video generating! 🎬${NC}"
}

# Main execution
main() {
    show_welcome
    
    echo -n "セットアップを開始しますか？ (Y/n): "
    read -r response
    if [ "$response" = "n" ] || [ "$response" = "N" ]; then
        echo "セットアップを中止しました。"
        exit 0
    fi
    
    echo ""
    check_requirements
    setup_docker_hub
    configure_build
    execute_build
    show_final_instructions
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi