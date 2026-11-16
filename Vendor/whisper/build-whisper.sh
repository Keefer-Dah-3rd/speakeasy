#!/bin/bash
# Rebuilds the Whisper speech libraries in Vendor/whisper/lib from source.
#
# You only need this to update Whisper or move to a different Mac. The
# libraries are compiled for the processor of the Mac that runs this script
# (on this Intel Mac: AVX2, FMA, F16C, plus Apple's Accelerate framework).
#
# Needs CMake, which is not installed by default. One way to get it without
# installing anything system-wide:
#   python3 -m venv /tmp/cmake-venv && /tmp/cmake-venv/bin/pip install cmake
#   CMAKE=/tmp/cmake-venv/bin/cmake Vendor/whisper/build-whisper.sh
set -euo pipefail

VERSION="v1.9.5"  # commit d1be6fde11ac6e0407606b4e42fe72d34add8037
CMAKE="${CMAKE:-cmake}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"

git clone --quiet --depth 1 --branch "$VERSION" https://github.com/ggml-org/whisper.cpp "$WORK/src"

"$CMAKE" -S "$WORK/src" -B "$WORK/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 \
  -DGGML_NATIVE=ON \
  -DGGML_METAL=OFF \
  -DGGML_OPENMP=OFF \
  -DWHISPER_COREML=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF
"$CMAKE" --build "$WORK/build" --config Release -j 8 --target whisper

mkdir -p "$HERE/lib" "$PROJECT/Sources/CWhisper/include"
cp "$WORK/build/src/libwhisper.a" \
   "$WORK/build/ggml/src/libggml.a" \
   "$WORK/build/ggml/src/libggml-base.a" \
   "$WORK/build/ggml/src/libggml-cpu.a" \
   "$WORK/build/ggml/src/ggml-blas/libggml-blas.a" \
   "$HERE/lib/"
cp "$WORK/src/include/whisper.h" \
   "$WORK/src/ggml/include/ggml.h" \
   "$WORK/src/ggml/include/ggml-cpu.h" \
   "$WORK/src/ggml/include/ggml-backend.h" \
   "$WORK/src/ggml/include/ggml-alloc.h" \
   "$PROJECT/Sources/CWhisper/include/"
cp "$WORK/src/LICENSE" "$HERE/LICENSE"

rm -rf "$WORK"
echo "Whisper $VERSION libraries rebuilt in $HERE/lib"
