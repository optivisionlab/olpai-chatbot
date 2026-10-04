#!/usr/bin/env bash
# Tạo môi trường conda với CUDA 12.6 (nvcc) và cài các thư viện trong requirements.txt
# Cách dùng: bash setup_env.sh            (đặt requirements.txt cùng thư mục)
# Tuỳ chọn:  ENV_NAME=thi PYTHON_VERSION=3.11 bash setup_env.sh
set -euo pipefail

ENV_NAME="${ENV_NAME:-ml}"
PYTHON_VERSION="${PYTHON_VERSION:-3.11}"
CONDA_BASE_DEFAULT="/data/miniconda"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ_FILE="${SCRIPT_DIR}/requirements.txt"

# --- Nạp conda ---
if command -v conda >/dev/null 2>&1; then
  CONDA_BASE="$(conda info --base)"
else
  CONDA_BASE="${CONDA_BASE_DEFAULT}"
fi
# shellcheck disable=SC1091
source "${CONDA_BASE}/etc/profile.d/conda.sh"

[[ -f "${REQ_FILE}" ]] || { echo "Không thấy ${REQ_FILE}" >&2; exit 1; }

# --- Tạo môi trường ---
if conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
  echo "==> Môi trường ${ENV_NAME} đã tồn tại, dùng lại."
else
  echo "==> Tạo môi trường ${ENV_NAME} (python ${PYTHON_VERSION})"
  conda create -y -n "${ENV_NAME}" "python=${PYTHON_VERSION}"
fi
conda activate "${ENV_NAME}"

# --- CUDA 12.6 (nvcc) + cuDNN trong conda ---
echo "==> Cài CUDA toolkit 12.6 (nvcc) vào môi trường"
conda install -y -c "nvidia/label/cuda-12.6.3" cuda-toolkit
echo "==> Cài cuDNN"
conda install -y -c conda-forge cudnn

# Tự đặt biến môi trường mỗi lần activate env
mkdir -p "${CONDA_PREFIX}/etc/conda/activate.d" "${CONDA_PREFIX}/etc/conda/deactivate.d"
cat > "${CONDA_PREFIX}/etc/conda/activate.d/cuda.sh" <<'EOF'
export CUDA_HOME="$CONDA_PREFIX"
export LD_LIBRARY_PATH="$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}"
EOF
cat > "${CONDA_PREFIX}/etc/conda/deactivate.d/cuda.sh" <<'EOF'
unset CUDA_HOME
EOF
# shellcheck disable=SC1091
source "${CONDA_PREFIX}/etc/conda/activate.d/cuda.sh"

# --- pip ---
python -m pip install --upgrade pip setuptools wheel

echo "==> Cài PyTorch bản CUDA 12.6"
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu126

echo "==> Cài các thư viện còn lại"
pip install -r "${REQ_FILE}"

echo "==> Cài autoviz (nếu xung đột sẽ bỏ qua)"
pip install autoviz || echo "!! autoviz cài không thành công, bỏ qua."

# --- Dữ liệu bổ sung cho nltk / spacy (không bắt buộc) ---
python -m nltk.downloader punkt punkt_tab stopwords wordnet || true
python -m spacy download en_core_web_sm || true

# --- Kiểm tra ---
echo
echo "==> Kiểm tra"
nvcc -V || true
python - <<'EOF'
import torch
print("torch:", torch.__version__, "| CUDA build:", torch.version.cuda,
      "| GPU khả dụng:", torch.cuda.is_available())
try:
    import tensorflow as tf
    print("tensorflow:", tf.__version__, "| GPU:", tf.config.list_physical_devices("GPU"))
except Exception as e:
    print("tensorflow lỗi:", e)
EOF

echo
echo "Xong. Kích hoạt môi trường bằng:  conda activate ${ENV_NAME}"
