#!/bin/bash
set -e

echo "==================================================="
echo "🚀 ComfyUI WAN RunPod Template Starting..."
echo "==================================================="

# ── 環境変数設定 ─────────────────────────────────────
export PYTHONUNBUFFERED=1
export HF_HOME="/tmp/huggingface"
export COMFYUI_MODEL_PATH="/ComfyUI/models"

# Initialize models directory if using persistent storage
if [ -n "$RUNPOD_VOLUME_PATH" ] && [ -d "$RUNPOD_VOLUME_PATH" ]; then
    echo "[INFO] Using persistent storage: $RUNPOD_VOLUME_PATH"
    MODELS_PATH="$RUNPOD_VOLUME_PATH/models"
    mkdir -p $MODELS_PATH/{unet,clip,vae,loras}
    
    # Copy built-in models to persistent storage if they don't exist
    if [ ! -f "$MODELS_PATH/unet/wan2.1-t2v-14b-Q4_K_S.gguf" ]; then
        echo "[INFO] Copying WAN models to persistent storage..."
        cp -r $COMFYUI_MODEL_PATH/* $MODELS_PATH/
        echo "[INFO] WAN models copied to persistent storage"
    fi
    
    # Create symlinks to persistent storage
    rm -rf $COMFYUI_MODEL_PATH
    ln -sf $MODELS_PATH $COMFYUI_MODEL_PATH
    echo "[INFO] Models linked to persistent storage"
else
    echo "[INFO] Using built-in models (models are pre-installed in image)"
fi

# ── 事前組み込み済みコンポーネント確認 ─────────────────────────────────────
echo "[INFO] Verifying pre-installed components..."

# Quick verification of models and custom nodes
model_count=$(find $COMFYUI_MODEL_PATH -name "*.gguf" -o -name "*.safetensors" 2>/dev/null | wc -l)
custom_nodes_count=$(ls -d /ComfyUI/custom_nodes/*/ 2>/dev/null | wc -l)

echo "[INFO] ✅ Found $model_count WAN model files"
echo "[INFO] ✅ Found $custom_nodes_count custom nodes"

cd /ComfyUI

# ── Status summary ─────────────────────────────────────
echo ""
echo "📊 Ready to Launch:"
echo "   ✅ WAN Models: $model_count files ready"
echo "   ✅ Custom nodes: $custom_nodes_count installed"
echo "   ✅ CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'Unknown')"
echo ""

# ── Jupyter Lab の起動 ─────────────────────────────────────
echo "🔬 Starting Jupyter Lab..."
mkdir -p /workspace/notebooks
cd /workspace

# Jupyter Lab をバックグラウンドで起動
nohup jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    --NotebookApp.allow_origin='*' \
    --NotebookApp.disable_check_xsrf=True \
    > /tmp/jupyter.log 2>&1 &

echo "[INFO] Jupyter Lab started on port 8888"

# ── ComfyUIの起動 ─────────────────────────────────────
echo "🎨 Starting ComfyUI..."
cd /ComfyUI

# ── Provide stub for torch_directml on non-DirectML environments ───────────────
python -c "
import importlib, sys, types
try:
    import torch
    # If torch_directml is unavailable (e.g., CUDA server) create a safe stub
    try:
        importlib.import_module('torch_directml')
    except ModuleNotFoundError:
        stub = types.ModuleType('torch_directml')
        # Return a CUDA device if available, else CPU – enough for ComfyUI to proceed
        stub.device = lambda *args, **kwargs: torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        sys.modules['torch_directml'] = stub
        print('[INFO] torch_directml stub created for CUDA environment')
except Exception as e:
    print(f'[WARNING] torch_directml stub creation failed: {e}')
"

# プロセス終了時のクリーンアップ関数
cleanup() {
    echo "[INFO] Shutting down services..."
    pkill -f "jupyter lab" 2>/dev/null || true
    pkill -f "python main.py" 2>/dev/null || true
    exit 0
}

# シグナルハンドラーを設定
trap cleanup SIGTERM SIGINT

echo "[INFO] ComfyUI and Jupyter Lab are now running:"
echo "  - ComfyUI: http://localhost:6006"
echo "  - Jupyter Lab: http://localhost:8888"
echo ""
echo "🎬 Ready to generate videos with WAN!"

# ComfyUI をフォアグラウンドで起動（メインプロセス）
python main.py \
    --listen 0.0.0.0 \
    --port 6006 \
    --preview-method auto \
    --use-split-cross-attention