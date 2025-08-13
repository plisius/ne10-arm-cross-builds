#!/bin/bash
set -e

# =============================================== #
# Ne10 Cross-Compilation Script for ARMv7-A
#
# Автоматизированная сборка библиотеки Ne10 и бенчмарка
# - Режимы: hard float (NEON) и soft float
# - Автоматическая установка кросс-компиляторов и CMake
# - Клонирование исходников с GitHub
# - Очистка старых флагов архитектуры
# - Статическая сборка и вывод результата в текущий каталог
#
# Требуется наличие файла 'ne10_bench.c' (или ne10_fast_conv.c)
# в рабочем каталоге — при отсутствии будет скопирован автоматически
# =============================================== #

NE10_REPO="https://github.com/projectNe10/Ne10.git"
NE10_SRC_DIR="Ne10"
BENCH_SOURCE="ne10_bench.c"   # исходник бенчмарка

echo "=== [Ne10 Cross Compilation Universal Script: ARMv7-A] ==="
echo "Выберите режим сборки:"
echo "1) ARMv7-A HARD float (arm-linux-gnueabihf, NEON, Cortex-A9)"
echo "2) ARMv7-A SOFT float (arm-linux-gnueabi)"
read -p "Введите 1 или 2: " mode

if [[ "$mode" == "1" ]]; then
    TARGET_TRIPLET="arm-linux-gnueabihf"
    CFLAGS="-O3 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
    NEON_FLAG="ON"
    BUILD_NAME="ne10_armv7a_hard_float"
    REQUIRED_PKGS=("gcc-arm-linux-gnueabihf" "g++-arm-linux-gnueabihf" "cmake" "git" "build-essential")
elif [[ "$mode" == "2" ]]; then
    TARGET_TRIPLET="arm-linux-gnueabi"
    CFLAGS="-O3 -march=armv7-a -mfloat-abi=soft"
    NEON_FLAG="OFF"
    BUILD_NAME="ne10_armv7a_soft_float"
    REQUIRED_PKGS=("gcc-arm-linux-gnueabi" "g++-arm-linux-gnueabi" "cmake" "git" "build-essential")
else
    echo "[ERROR] Неверный выбор."
    exit 1
fi

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

# --- 3. Автоматическое копирование .c, если нет ---
if [[ ! -f "$BENCH_SOURCE" ]]; then
    # пробуем взять из каталога Ne10/examples, если есть
    if [[ -f "$NE10_SRC_DIR/examples/$BENCH_SOURCE" ]]; then
        cp "$NE10_SRC_DIR/examples/$BENCH_SOURCE" .
        echo "[*] Скопирован $BENCH_SOURCE из examples/"
    else
        echo "[ERROR] Исходник $BENCH_SOURCE не найден ни в текущей папке, ни в examples/"
        exit 1
    fi
fi

# --- 4. Очистка и подготовка сборки ---
cd "$NE10_SRC_DIR"
unset CFLAGS CXXFLAGS
find . -type f \( -name "CMakeLists.txt" -o -name "*.cmake" \) -exec sed -i 's/-march=[^ ]*//g' {} +
sed -i '/message(FATAL_ERROR "You are trying to compile for non-ARM/,/endif()/ s/^/#/' CMakeLists.txt
rm -rf build && mkdir build && cd build

# --- 5. Toolchain ---
cat > ../armv7a-toolchain.cmake <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER /usr/bin/${TARGET_TRIPLET}-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/${TARGET_TRIPLET}-g++)
set(CMAKE_C_FLAGS "${CFLAGS}")
set(CMAKE_CXX_FLAGS "\${CMAKE_C_FLAGS}")
EOF

# --- 6. Конфигурация и сборка Ne10 ---
cmake -DCMAKE_TOOLCHAIN_FILE=../armv7a-toolchain.cmake \
      -DGNULINUX_PLATFORM=ON \
      -DNE10_BUILD_STATIC=ON \
      -DNE10_BUILD_UNIT_TEST=OFF \
      -DNE10_ENABLE_NEON=${NEON_FLAG} \
      ..
make -j$(nproc)
cd ../..

# --- 7. Компиляция бенчмарка ---
BIN_NAME="${BENCH_SOURCE%.*}_${BUILD_NAME}"
${TARGET_TRIPLET}-gcc "$BENCH_SOURCE" \
    -I${NE10_SRC_DIR}/inc \
    -L${NE10_SRC_DIR}/build/modules \
    -lNE10 -lm ${CFLAGS} -static \
    -o "$BIN_NAME"

# --- 8. Копирование бинарника ---
mkdir -p bin
mv "$BIN_NAME" "bin/$BIN_NAME"
echo "✅ Готово: $(realpath bin/$BIN_NAME)"
