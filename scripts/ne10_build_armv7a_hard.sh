#!/bin/bash
set -e

# =============================================== #
# Ne10 Cross-Compilation Script for ARMv7-A
#
# Автоматизированная сборка библиотеки Ne10 и бенчмарка
# - Режимы: hard float (NEON)
# - Автоматическая установка кросс-компиляторов и CMake
# - Клонирование исходников с GitHub
# - Очистка старых флагов архитектуры
# - Статическая сборка и вывод результата в текущий каталог
#
# Требуется наличие файла 'ne10_bench.c'
# в рабочем каталоге — при отсутствии будет скопирован автоматически
# =============================================== #

NE10_REPO="https://github.com/projectNe10/Ne10.git"
NE10_SRC_DIR="Ne10"
BENCH_SOURCE="ne10_bench.c"   # исходник бенчмарка

# echo "=== [Ne10 Cross Compilation Universal Script: ARMv7-A] ==="

TARGET_TRIPLET="arm-linux-gnueabihf"
CFLAGS="-O3 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
NEON_FLAG="ON"
BUILD_NAME="ne10_bench_armv7a_hard_float"
REQUIRED_PKGS=("gcc-arm-linux-gnueabihf" "g++-arm-linux-gnueabihf" "cmake" "git" "build-essential")

# --- 1. Установка зависимостей ---
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        sudo apt-get install -y "$pkg"
    fi
done

# --- 2. Клонирование Ne10 ---
if [[ ! -d "$NE10_SRC_DIR" ]]; then
    git clone "$NE10_REPO"
fi


# --- 4. Очистка и подготовка сборки ---
cd "$NE10_SRC_DIR"
# cd Ne10
unset CFLAGS CXXFLAGS
sed -i 's/-march=[^ ]*//g' CMakeLists.txt
find . -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i 's/-march=[^ ]*//g' {} +

# 5. Очистка и создание build-директории
rm -rf build
mkdir build
cd build


# --- 5. Toolchain ---
cat > ../armv7a-toolchain.cmake <<EOL
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
set(CMAKE_FIND_ROOT_PATH /usr/arm-linux-gnueabihf)
set(CMAKE_C_FLAGS "\${CMAKE_C_FLAGS} -mcpu=cortex-a9 -mfpu=neon -O3 -ffast-math")
set(CMAKE_CXX_FLAGS "\${CMAKE_CXX_FLAGS} -mcpu=cortex-a9 -mfpu=neon -O3 -ffast-math")
EOL

# --- 6. Конфигурация и сборка Ne10 ---
cmake -DCMAKE_TOOLCHAIN_FILE=../armv7a-toolchain.cmake \
      -DGNULINUX_PLATFORM=ON \
      -DNE10_BUILD_STATIC=ON \
      -DNE10_BUILD_UNIT_TEST=OFF \
      -DNE10_ENABLE_NEON=${NEON_FLAG} \
      ..

make -j$(nproc)

echo "Ne10 успешно собрана с максимальными оптимизациями NEON для Cortex-A9!"
echo "Библиотека: Ne10/build/modules/libNE10.a"


cd ../..
echo "$(pwd)"
# --- 7. Компиляция бенчмарка ---
BIN_NAME="${BUILD_NAME}"
${TARGET_TRIPLET}-gcc "../$BENCH_SOURCE" \
    -I${NE10_SRC_DIR}/inc \
    -L${NE10_SRC_DIR}/build/modules \
    -lNE10 -lm ${CFLAGS} -static \
    -o "$BIN_NAME"

# --- 8. Копирование бинарника ---
mkdir -p bin
mv "$BIN_NAME" "bin/$BIN_NAME"
echo "✅ Готово: $(realpath bin/$BIN_NAME)"
