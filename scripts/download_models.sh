#!/bin/bash
# Optimized parallel model downloader with retry mechanism
set -e

# Configuration
MAX_RETRIES=3
RETRY_DELAY=5
DOWNLOAD_TIMEOUT=1800  # 30 minutes per file
CACHE_DIR="/tmp/model_cache"
MODELS_DIR="/ComfyUI/models"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
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

# Download function with retry mechanism
download_with_retry() {
    local url="$1"
    local output_path="$2"
    local filename="$3"
    local retry_count=0
    
    # Create cache path for this file
    local cache_path="${CACHE_DIR}/${filename}"
    
    # Check if file exists in cache and verify size
    if [ -f "$cache_path" ]; then
        info_msg "Found cached file: $filename"
        # Get remote file size for verification
        local remote_size=$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r' || echo "0")
        local local_size=$(stat --format=%s "$cache_path" 2>/dev/null || echo "0")
        
        if [ "$remote_size" -gt 0 ] && [ "$local_size" -eq "$remote_size" ]; then
            info_msg "Cache valid for $filename, copying..."
            cp "$cache_path" "$output_path"
            success_msg "✓ $filename (from cache)"
            return 0
        else
            warning_msg "Cache invalid for $filename, re-downloading..."
            rm -f "$cache_path"
        fi
    fi
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        info_msg "Downloading $filename (attempt $((retry_count + 1))/$MAX_RETRIES)..."
        
        # Download to cache first, then copy to final location
        if curl -L --fail --show-error --progress-bar \
            --max-time $DOWNLOAD_TIMEOUT \
            --retry 3 --retry-delay 2 \
            -o "$cache_path" "$url"; then
            
            # Verify download completed successfully
            if [ -f "$cache_path" ] && [ -s "$cache_path" ]; then
                cp "$cache_path" "$output_path"
                success_msg "✓ $filename downloaded successfully"
                return 0
            else
                warning_msg "Downloaded file is empty or corrupted: $filename"
                rm -f "$cache_path"
            fi
        else
            warning_msg "Download failed for $filename (attempt $((retry_count + 1)))"
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            info_msg "Retrying in ${RETRY_DELAY} seconds..."
            sleep $RETRY_DELAY
            # Exponential backoff
            RETRY_DELAY=$((RETRY_DELAY * 2))
        fi
    done
    
    error_exit "Failed to download $filename after $MAX_RETRIES attempts"
}

# Main download function
main() {
    echo "==================================================="
    echo "🚀 Optimized WAN Model Downloader"
    echo "==================================================="
    
    # Ensure cache directory exists
    mkdir -p "$CACHE_DIR"
    
    # Define model files with their URLs and paths
    declare -A models=(
        ["wan2.1-t2v-14b-Q4_K_S.gguf"]="https://huggingface.co/city96/Wan2.1-T2V-14B-gguf/resolve/main/wan2.1-t2v-14b-Q4_K_S.gguf|${MODELS_DIR}/unet/wan2.1-t2v-14b-Q4_K_S.gguf"
        ["umt5-xxl-encoder-Q5_K_S.gguf"]="https://huggingface.co/city96/umt5-xxl-encoder-gguf/resolve/main/umt5-xxl-encoder-Q5_K_S.gguf|${MODELS_DIR}/clip/umt5-xxl-encoder-Q5_K_S.gguf"
        ["wan_2.1_vae.safetensors"]="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors|${MODELS_DIR}/vae/wan_2.1_vae.safetensors"
        ["Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors"]="https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors|${MODELS_DIR}/loras/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors"
    )
    
    # Check available disk space
    local available_space=$(df --output=avail "$MODELS_DIR" | tail -1)
    local min_space=15000000  # 15GB in KB
    if [ "$available_space" -lt "$min_space" ]; then
        error_exit "Insufficient disk space. Required: 15GB, Available: $(df -h "$MODELS_DIR" | tail -1 | awk '{print $4}')"
    fi
    
    info_msg "Starting parallel download of ${#models[@]} model files..."
    
    # Start downloads in parallel (background processes)
    local pids=()
    local download_count=0
    
    for filename in "${!models[@]}"; do
        IFS='|' read -r url output_path <<< "${models[$filename]}"
        
        # Ensure output directory exists
        mkdir -p "$(dirname "$output_path")"
        
        # Skip if file already exists and has reasonable size
        if [ -f "$output_path" ] && [ -s "$output_path" ]; then
            success_msg "✓ $filename already exists, skipping"
            continue
        fi
        
        # Start download in background
        {
            download_with_retry "$url" "$output_path" "$filename"
        } &
        
        pids+=($!)
        download_count=$((download_count + 1))
        info_msg "Started download $download_count: $filename"
    done
    
    # Wait for all downloads to complete
    info_msg "Waiting for $download_count parallel downloads to complete..."
    local failed_downloads=0
    
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            failed_downloads=$((failed_downloads + 1))
        fi
    done
    
    # Check results
    if [ $failed_downloads -eq 0 ]; then
        echo ""
        success_msg "🎉 All model files downloaded successfully!"
        
        # Display download summary
        echo ""
        echo "📊 Download Summary:"
        for filename in "${!models[@]}"; do
            IFS='|' read -r url output_path <<< "${models[$filename]}"
            if [ -f "$output_path" ]; then
                local file_size=$(du -h "$output_path" | cut -f1)
                echo "   ✓ $filename ($file_size)"
            fi
        done
        
        local total_size=$(du -sh "$MODELS_DIR" | cut -f1)
        echo "   📦 Total size: $total_size"
        echo ""
        
    else
        error_exit "$failed_downloads download(s) failed. Check the logs above for details."
    fi
}

# Execute main function
main "$@"