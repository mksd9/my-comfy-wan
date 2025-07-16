# 🚀 Quick Reference
## ComfyUI WAN RunPod デプロイ

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
**所要時間**: 25-35分（モデルダウンロード含む）  
**容量**: 約15-18GB（軽量化済み）  
**プラットフォーム**: linux/amd64 