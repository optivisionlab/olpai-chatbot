#!/usr/bin/env bash
# Cài CUDA Toolkit 12.6 (nvcc) + driver NVIDIA trên Ubuntu 20.04 / 22.04 / 24.04 (x86_64)
# Cách dùng: sudo bash install_cuda_12.6.sh
set -euo pipefail

CUDA_PKG="cuda-toolkit-12-6"
DRIVER_PKG="${DRIVER_PKG:-cuda-drivers}"   # có thể đổi, ví dụ: DRIVER_PKG=cuda-drivers-560
CUDA_HOME_DIR="/usr/local/cuda-12.6"

if [[ $EUID -ne 0 ]]; then
  echo "Hãy chạy bằng sudo: sudo bash $0" >&2
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "Script này chỉ hỗ trợ x86_64." >&2
  exit 1
fi

. /etc/os-release
case "${VERSION_ID}" in
  20.04) DISTRO="ubuntu2004" ;;
  22.04) DISTRO="ubuntu2204" ;;
  24.04) DISTRO="ubuntu2404" ;;
  *) echo "Ubuntu ${VERSION_ID} chưa được hỗ trợ." >&2; exit 1 ;;
esac

echo "==> Cài các gói phụ thuộc"
apt-get update
apt-get install -y wget gnupg ca-certificates build-essential "linux-headers-$(uname -r)"

echo "==> Thêm kho NVIDIA CUDA (${DISTRO})"
TMP_DEB="$(mktemp --suffix=.deb)"
wget -q -O "${TMP_DEB}" \
  "https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/x86_64/cuda-keyring_1.1-1_all.deb"
dpkg -i "${TMP_DEB}"
rm -f "${TMP_DEB}"
apt-get update

echo "==> Cài CUDA Toolkit 12.6"
apt-get install -y "${CUDA_PKG}"

echo "==> Cài driver NVIDIA (${DRIVER_PKG})"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "    Driver đã hoạt động, bỏ qua bước cài driver."
else
  apt-get install -y "${DRIVER_PKG}"
fi

echo "==> Thiết lập biến môi trường"
cat > /etc/profile.d/cuda.sh <<EOF
export CUDA_HOME=${CUDA_HOME_DIR}
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\${LD_LIBRARY_PATH:-}
EOF
chmod 644 /etc/profile.d/cuda.sh

# Trỏ /usr/local/cuda về 12.6
ln -sfn "${CUDA_HOME_DIR}" /usr/local/cuda

export PATH="${CUDA_HOME_DIR}/bin:${PATH}"

echo "==> Kiểm tra"
nvcc -V || true
echo
echo "Xong. Hãy REBOOT để nạp driver:  sudo reboot"
echo "Sau khi khởi động lại, kiểm tra bằng:"
echo "  nvcc -V"
echo "  nvidia-smi"
echo "  nvidia-smi -l 12     # làm mới mỗi 12 giây"
