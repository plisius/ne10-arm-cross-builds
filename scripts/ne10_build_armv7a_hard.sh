#!/bin/bash
set -e

# =============================================== #
# Ne10 Cross-Compilation Script for ARMv7-A (hard float NEON)
#
# Автоматизированная сборка библиотеки Ne10 и бенчмарка
# - Режим: hard float (NEON)
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
BENCH_SOURCE="ne10_bench.c" # исходник бенчмарка

TARGET_TRIPLET="arm-linux-gnueabihf"
CFLAGS="-O3 -march=armv7-a -mfpu=neon -mfloat-abi=hard"
NEON_FLAG="ON"
BUILD_NAME="ne10_bench_armv7"

REQUIRED_PKGS=("gcc-arm-linux-gnueabihf" "g++-arm-linux-gnueabihf" "cmake" "git" "build-essential")

# 1. Установка зависимостей
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    sudo apt-get install -y "$pkg"
  fi
done

# 2. Клонирование Ne10, если ещё нет
if [[ ! -d "$NE10_SRC_DIR" ]]; then
  git clone "$NE10_REPO"
fi

# 3. Копирование бенчмарка, если отсутствует
if [[ ! -f "$BENCH_SOURCE" ]]; then
  if [[ -f "$NE10_SRC_DIR/examples/$BENCH_SOURCE" ]]; then
    cp "$NE10_SRC_DIR/examples/$BENCH_SOURCE" .
    echo "[*] Скопирован $BENCH_SOURCE из examples/"
  else
    echo "[ERROR] Исходник $BENCH_SOURCE не найден ни в текущей папке, ни в examples/"
    exit 1
  fi
fi

# 4. Очистка и подготовка сборки
cd "$NE10_SRC_DIR"
unset CFLAGS CXXFLAGS

# Удаляем любые -march= из CMake-файлов (чтобы не было конфликтов)
sed -i 's/-march=[^ ]*//g' CMakeLists.txt
find . -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i 's/-march=[^ ]*//g' {} +

rm -rf build && mkdir build && cd build

# 5. Генерация toolchain-файла для ARMv7-A hard float (NEON)
cat > ../armv7a-toolchain.cmake << EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER /usr/bin/${TARGET_TRIPLET}-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/${TARGET_TRIPLET}-g++)
set(CMAKE_C_FLAGS "${CFLAGS}")
set(CMAKE_CXX_FLAGS "\${CMAKE_C_FLAGS}")
EOF

# 6. Конфигурация и сборка
cmake -DCMAKE_TOOLCHAIN_FILE=../armv7a-toolchain.cmake \
      -DGNULINUX_PLATFORM=ON -DNE10_BUILD_STATIC=ON -DNE10_BUILD_UNIT_TEST=OFF ../

make -j$(nproc)

echo "Ne10 успешно собрана для ARMv7-A (hard float NEON) с оптимизациями!"

# 7. Компиляция бенчмарка
if [ ! -f "../../$BENCH_SOURCE" ]; then
  echo "! Файл $BENCH_SOURCE не найден рядом со скриптом!"
  exit 1
fi

aarch64-linux-gnu-gcc "../../$BENCH_SOURCE" \
    -I../inc -Lmodules -lNE10 -lm \
    -march=armv7-a -mfpu=neon -mfloat-abi=hard -O3 -ffast-math \
    -o "../../${BUILD_NAME}"

echo "=== Готово ==="
echo "Бинарник бенчмарка: ../../${BUILD_NAME}"
