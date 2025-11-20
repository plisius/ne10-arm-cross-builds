#!/bin/bash

set -e

# =============================================== #
# Ne10 Cross-Compilation Script for ARMv7-A fixed point
# Режимы: hard float (NEON), fixed point (Q15)
# Автоматическая установка кросс-компиляторов и CMake
# Клонирование исходников с GitHub
# Очистка старых флагов архитектуры
# Статическая сборка и вывод результата в текущий каталог
#
#
# Требуется наличие файла 'ne10_fix16.c'
# =============================================== #

NE10_REPO="https://github.com/projectNe10/Ne10.git"
NE10_SRC_DIR="Ne10"
BENCH_SOURCE="ne10_fix16.c"   # исходник бенчмарка

# echo "=== [Ne10 Cross Compilation Universal Script: ARMv7-A] ==="

TARGET_TRIPLET="arm-linux-gnueabihf"
CFLAGS="-O3 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
NEON_FLAG="ON"
FIXED_POINT_FLAG="ON"
PLATFORM="armv7a"

BUILD_NAME="ne10_bench_armv7_hard_fixed"

REQUIRED_PKGS=("gcc-arm-linux-gnueabihf" "g++-arm-linux-gnueabihf" "cmake" "git" "build-essential")

# --- 1. Установка зависимостей ---
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    echo "Installing $pkg..."
    sudo apt-get install -y "$pkg"
  fi
done

# --- 2. Клонирование Ne10 ---
if [[ ! -d "$NE10_SRC_DIR" ]]; then
  git clone "$NE10_REPO"
fi

# --- 3. Очистка и подготовка сборки ---
cd "$NE10_SRC_DIR"

unset CFLAGS CXXFLAGS
sed -i 's/-march=[^ ]*//g' CMakeLists.txt
find . -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i 's/-march=[^ ]*//g' {} +

rm -rf build
mkdir build
cd build

# --- 4. Создание файла toolchain для кросс-компиляции ---
cat > ../armv7a-toolchain.cmake << EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER   arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
set(CMAKE_ASM_COMPILER arm-linux-gnueabihf-as)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_C_FLAGS "-O3 -march=armv7-a -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard")
set(CMAKE_CXX_FLAGS "-O3 -march=armv7-a -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard")

EOF

echo "Текущая директория сборки: $(pwd)"
echo "Запуск cmake с передачей параметров..."
  
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=../armv7a-toolchain.cmake \
  -DENABLE_NEON=ON \
  -DENABLE_FIXED_POINT=ON \
  -DPLATFORM=armv7a \
  -DGNULINUX_PLATFORM=TRUE \
  -DCMAKE_BUILD_TYPE=Release
  
  

make -j$(nproc)

echo "Сборка NE10 для fixed point под ARMv7 (Cortex-A9) завершена."

cd ../..
echo "$(pwd)"
# --- 7. Компиляция бенчмарка ---
BIN_NAME="${BUILD_NAME}"
${TARGET_TRIPLET}-gcc "$BENCH_SOURCE" \
    -I${NE10_SRC_DIR}/inc \
    -L${NE10_SRC_DIR}/build/modules \
    -lNE10 -lm ${CFLAGS} -static \
    -o "$BIN_NAME"

# --- 8. Копирование бинарника ---
mkdir -p bin
mv "$BIN_NAME" "bin/$BIN_NAME"
echo "✅ Готово: $(realpath bin/$BIN_NAME)"