# 🚀 Quick Reference
## ComfyUI WAN RunPod デプロイ

### 🎯 **v2.1 新機能ハイライト**
- **⚡ 並列ダウンロード**: 最大50%高速化
- **🔄 エラーリトライ**: 自動復旧機構
- **💾 強化キャッシュ**: Registry cache対応
- **🛠️ インタラクティブガイド**: 初心者サポート
- **📊 コスト見積もり**: ビルド時間・費用表示

### 🚀 **推奨: RunPod上でのビルド**
```bash
# Option A: インタラクティブガイド（推奨）
git clone https://github.com/mksd9/my-comfy-wan.git
cd my-comfy-wan
./setup-interactive.sh

# Option B: 直接実行
export DOCKER_PASSWORD='your_docker_hub_token'
./build-on-runpod.sh
```

### ⚡ **ワンライナー実行**
```bash
# 全工程を一度に実行
docker login && \
docker buildx create --name multiarch-builder --use && \
docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push . && \
docker buildx rm multiarch-builder && \
docker system prune -a -f && \
docker buildx prune -a -f && \
echo "✅ Deploy完了!"
```

### 🔧 **分割実行**
```bash
# 1. ログイン
docker login

# 2. ビルド & プッシュ
docker buildx create --name multiarch-builder --use
docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push .

# 3. クリーンアップ
docker buildx rm multiarch-builder
docker system prune -a -f
docker buildx prune -a -f
```

### 🎯 **RunPod設定**
```
イメージ: nobukoyo/comfyui-wan-runpod:latest
ポート: 6006
```

### 🔍 **確認コマンド**
```bash
# ローカル確認
docker images              # 空であることを確認
ls -la                     # プロジェクトファイル確認

# リモート確認
docker search nobukoyo/comfyui-wan-runpod
```

### 🆘 **トラブル時**
```bash
# 全削除してやり直し
docker system prune -a -f
docker buildx prune -a -f
docker buildx rm multiarch-builder 2>/dev/null || true

# 再ログイン
docker logout && docker login
```

---

## 🗂️ **リポジトリ管理**

### 古いリポジトリ削除
```bash
# DockerHubで手動削除:
# 1. https://hub.docker.com/ にアクセス
# 2. My Hub > Repositories > comfyui-wan-runpod 
# 3. Settings > Delete repository
# 4. リポジトリ名を入力して確認
```

### 統一名でのPush
```bash
# 常に同じ名前でPush（推奨）
docker buildx build --platform linux/amd64 -t nobukoyo/comfyui-wan-runpod:latest --push .
```

---

### 📊 **v2.1 パフォーマンス向上**
**所要時間**: 
- **初回ビルド**: 20-30分（v1: 25-35分）⚡ **20%高速化**
- **キャッシュあり**: 12-18分（v1: 15-20分）⚡ **25%高速化**

**容量**: 約15-18GB（軽量化済み、v1と同等）  
**プラットフォーム**: linux/amd64  
**推定コスト**: $2-4（RTX 4090 on RunPod）

### 🛠️ **新しいファイル構成**
```
my-comfy-wan/
├── scripts/
│   └── download_models.sh    # 並列ダウンロードスクリプト
├── setup-interactive.sh      # インタラクティブガイド
├── build-on-runpod.sh       # 強化ビルドスクリプト
└── Dockerfile               # 最適化されたマルチステージビルド
``` 