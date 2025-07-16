# Multi-stage build for optimized image size
FROM nvidia/cuda:12.3.2-runtime-ubuntu22.04 as base

# Install system dependencies in a single layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-pip \
        python3-dev \
        git \
        wget \
        curl \
        libgl1-mesa-glx \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender-dev \
        libgomp1 && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Build stage for dependencies
FROM base as dependencies

# Create symbolic link for python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install PyTorch 2.7 nightly or later with CUDA support
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu121

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /ComfyUI

WORKDIR /ComfyUI

# Install ComfyUI requirements and additional packages in one layer with cache
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt \
        opencv-python \
        pillow \
        numpy \
        scipy \
        scikit-image \
        matplotlib \
        segment-anything \
        ultralytics \
        onnxruntime \
        jupyterlab \
        notebook \
        ipywidgets \
        pandas \
        seaborn \
        plotly \
        tqdm

# Model download stage
FROM dependencies as models

# Create model directories
RUN mkdir -p /ComfyUI/models/{unet,clip,vae,loras}

# Download WAN model files (optimized for size) with cache mount
RUN --mount=type=cache,target=/tmp/model_cache \
    echo "Downloading WAN model files..." && \
    wget -q --show-progress -O /ComfyUI/models/unet/wan2.1-t2v-14b-Q4_K_S.gguf \
        https://huggingface.co/city96/Wan2.1-T2V-14B-gguf/resolve/main/wan2.1-t2v-14b-Q4_K_S.gguf && \
    wget -q --show-progress -O /ComfyUI/models/clip/umt5-xxl-encoder-Q5_K_S.gguf \
        https://huggingface.co/city96/umt5-xxl-encoder-gguf/resolve/main/umt5-xxl-encoder-Q5_K_S.gguf && \
    wget -q --show-progress -O /ComfyUI/models/vae/wan_2.1_vae.safetensors \
        https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors && \
    wget -q --show-progress -O /ComfyUI/models/loras/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors \
        https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors

# Custom nodes stage
FROM models as custom_nodes

# Clone latest custom nodes from GitHub and install dependencies with cache
RUN --mount=type=cache,target=/root/.cache/pip \
    cd /ComfyUI/custom_nodes && \
    echo "Cloning latest custom nodes..." && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git comfyui-easy-use && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git comfyui-kjnodes && \
    git clone --depth 1 https://github.com/VrGamerDev/ComfyUI-VRGameDevGirl.git comfyui-vrgamedevgirl && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    find . -name "requirements.txt" -exec pip install -r {} \; || true && \
    find . -name "install.py" -exec python {} \; || true

# Final stage
FROM custom_nodes as final

# Copy scripts
COPY start.sh /start.sh
COPY runpod.yaml /runpod.yaml

# Make start script executable
RUN chmod +x /start.sh

EXPOSE 6006 8888
CMD ["/start.sh"]