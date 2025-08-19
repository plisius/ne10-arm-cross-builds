#!/bin/bash
set -e

# =============================================== #
# Ne10 Cross-Compilation Script for ARMv8-A (aarch64)
#
# Автоматизированная сборка библиотеки Ne10 и бенчмарка
# - Режим: ARMv8-A с оптимизациями
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

TARGET_TRIPLET="aarch64-linux-gnu"
CFLAGS="-march=armv8-a -O3 -ffast-math"
BUILD_NAME="ne10_bench_armv8a_hard_float"

REQUIRED_PKGS=("gcc-aarch64-linux-gnu" "g++-aarch64-linux-gnu" "cmake" "git" "build-essential")

# 1. Установка зависимостей
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    sudo apt-get install -y "$pkg"
  fi
done

# 2. Клонирование Ne10, если нет
if [[ ! -d "$NE10_SRC_DIR" ]]; then
  git clone "$NE10_REPO"
fi

# 4. Очистка и подготовка сборки
cd "$NE10_SRC_DIR"
unset CFLAGS CXXFLAGS

# Удаляем любые -march= из CMake-файлов (чтобы избежать конфликтов)
sed -i 's/-march=[^ ]*//g' CMakeLists.txt
find . -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i 's/-march=[^ ]*//g' {} +

rm -rf build && mkdir build && cd build

# 5. Генерация toolchain-файла для ARMv8-A
cat > ../armv8-toolchain.cmake << EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER /usr/bin/${TARGET_TRIPLET}-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/${TARGET_TRIPLET}-g++)
set(CMAKE_C_FLAGS "${CFLAGS}")
set(CMAKE_CXX_FLAGS "\${CMAKE_C_FLAGS}")
EOF

# 6. Конфигурация и сборка
cmake -DCMAKE_TOOLCHAIN_FILE=../armv8-toolchain.cmake \
      -DGNULINUX_PLATFORM=ON -DNE10_BUILD_STATIC=ON -DNE10_BUILD_UNIT_TEST=OFF ../

make -j$(nproc)

echo "Ne10 успешно собрана для ARMv8-A с оптимизациями!"

cd ../..
echo "$(pwd)"

# 7. Компиляция бенчмарка
if [ ! -f "../$BENCH_SOURCE" ]; then
  echo "! Файл $BENCH_SOURCE не найден рядом со скриптом!"
  exit 1
fi

${TARGET_TRIPLET}-gcc "../$BENCH_SOURCE" \
    -INe10/inc -LNe10/build/modules -lNE10 -lm \
    -march=armv8-a -O3 -ffast-math \
    -o "../${BUILD_NAME}_bench"

echo "=== Готово ==="
echo "Бинарник бенчмарка: ../${BUILD_NAME}_bench"
