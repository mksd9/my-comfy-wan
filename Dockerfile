# Multi-stage build for optimized image size
FROM nvidia/cuda:12.3.2-runtime-ubuntu22.04 as base

# Install system dependencies in a single layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
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

# Install ComfyUI requirements with optimized caching
# First install requirements.txt (changes less frequently)
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Install additional packages in separate layer for better caching
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        opencv-python \
        pillow \
        numpy \
        scipy \
        scikit-image \
        matplotlib \
        segment-anything \
        ultralytics \
        onnxruntime

# Install Jupyter and data science packages in separate layer
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
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

# Download WAN model files with parallel downloads and retry mechanism
COPY scripts/download_models.sh /tmp/download_models.sh
RUN --mount=type=cache,target=/tmp/model_cache \
    chmod +x /tmp/download_models.sh && \
    /tmp/download_models.sh

# Custom nodes stage
FROM models as custom_nodes

# Clone latest custom nodes from GitHub with optimized caching
WORKDIR /ComfyUI/custom_nodes

# Clone custom nodes (separate layer for better caching)
RUN echo "Cloning latest custom nodes..." && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone --depth 1 https://github.com/city96/ComfyUI-GGUF.git && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git comfyui-easy-use && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git comfyui-kjnodes && \
    git clone --depth 1 https://github.com/VrGamerDev/ComfyUI-VRGameDevGirl.git comfyui-vrgamedevgirl && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git

# Install custom node dependencies (separate layer with cache)
RUN --mount=type=cache,target=/root/.cache/pip \
    echo "Installing custom node dependencies..." && \
    find . -name "requirements.txt" -exec pip install -r {} \; || true

# Run custom node install scripts (separate layer)
RUN echo "Running custom node install scripts..." && \
    find . -name "install.py" -exec python {} \; || true

WORKDIR /ComfyUI

# Final stage
FROM custom_nodes as final

# Add metadata for better cache management
LABEL maintainer="nobukoyo" \
      version="2.1" \
      description="ComfyUI WAN RunPod Template with optimized build" \
      models="WAN-2.1-T2V-14B,UMT5-XXL" \
      build-optimizations="parallel-downloads,enhanced-caching,error-recovery"

# Copy scripts and configuration (separate layers for better caching)
COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY runpod.yaml /runpod.yaml

# Set environment variables for optimization
ENV PYTHONUNBUFFERED=1 \
    HF_HOME="/tmp/huggingface" \
    COMFYUI_MODEL_PATH="/ComfyUI/models" \
    BUILDKIT_INLINE_CACHE=1

# Health check for better container management
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m --retries=3 \
    CMD curl -f http://localhost:6006/ || exit 1

EXPOSE 6006 8888
CMD ["/start.sh"]