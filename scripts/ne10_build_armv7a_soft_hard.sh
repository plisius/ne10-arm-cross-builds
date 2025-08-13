#!/bin/bash

set -e

# =============================================== #
# Ne10 Cross-Compilation Script for ARMv7-A       #
# (Hard/Soft float with automated setup)          #
# =============================================== #
# Автоматизированная сборка библиотеки Ne10
# - Режимы: hard float (NEON) и soft float
# - Автоматическая установка кросс-компиляторов и CMake
# - Клонирование исходников из GitHub
# - Очистка старых флагов архитектуры
# - Статическая сборка и вывод результата в cwd

NE10_REPO="https://github.com/projectNe10/Ne10.git"
NE10_SRC_DIR="Ne10"

echo "=== [Ne10 Cross Compilation Universal Script: ARMv7-A] ==="

# --- 1. Выбор режима сборки ---
echo "Выберите режим сборки:"
echo "1) ARMv7-A 32-bit HARD float (arm-linux-gnueabihf + NEON, Cortex-A9 и др.)"
echo "2) ARMv7-A 32-bit SOFT float (arm-linux-gnueabi, совместимый режим под ARMv8)"
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
    echo "[ERROR] Неверный выбор. Завершение."
    exit 1
fi

# --- 2. Установка необходимых пакетов ---
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo "[*] Устанавливаем ${pkg}..."
        sudo apt-get install -y "$pkg"
    else
        echo "[✓] ${pkg} уже установлен."
    fi
done

# --- 3. Загрузка исходников Ne10 ---
if [[ ! -d "$NE10_SRC_DIR" ]]; then
    echo "[*] Клонируем Ne10..."
    git clone "$NE10_REPO"
else
    echo "[✓] Исходники Ne10 уже есть."
fi

cd "$NE10_SRC_DIR"

# --- 4. Очистка переменных окружения ---
unset CFLAGS
unset CXXFLAGS

# --- 5. Удаление -march флагов из cmake-файлов ---
find . -type f \( -name "CMakeLists.txt" -o -name "*.cmake" \) -exec sed -i 's/-march=[^ ]*//g' {} +

# --- 6. Подготовка build-директории ---
rm -rf build
mkdir build
cd build

# --- 7. Создание toolchain-файла ---
cat > ../a9-neon-toolchain.cmake <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER ${TARGET_TRIPLET}-gcc)
set(CMAKE_CXX_COMPILER ${TARGET_TRIPLET}-g++)
set(CMAKE_FIND_ROOT_PATH /usr/${TARGET_TRIPLET})
set(CMAKE_C_FLAGS "${CFLAGS}")
set(CMAKE_CXX_FLAGS "${CFLAGS}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

# --- 8. Конфигурация сборки ---
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=../a9-neon-toolchain.cmake \
    -DGNNEON=${NEON_FLAG} \
    -DNE10_BUILD_TESTS=OFF \
    -DNE10_BUILD_EXAMPLES=OFF \
    -DCMAKE_BUILD_TYPE=Release

# --- 9. Сборка ---
make -j$(nproc)

# --- 10. Завершение ---
BIN_DIR="$(pwd)/modules"
echo "✅ Сборка завершена. Библиотеки находятся в: $BIN_DIR"

cd ../..
mkdir -p bin
cp -r "$NE10_SRC_DIR/build/modules" "bin/$BUILD_NAME"

echo "Готово: $(realpath bin/$BUILD_NAME)"
