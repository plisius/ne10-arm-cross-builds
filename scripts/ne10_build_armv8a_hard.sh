#!/bin/bash
set -e

BENCHMARK_SRC="ne10_bench.c"
BENCHMARK_BIN="ne10_bench_armv8"

# 1. Установка системных зависимостей (Ubuntu/Debian)
sudo apt update
sudo apt install -y git cmake build-essential gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# 2. Удаляем старое и клонируем свежий Ne10
rm -rf Ne10 build
git clone https://github.com/projectNe10/Ne10.git

cd Ne10

# 3. Очистка переменных окружения (защита от лишних флагов)
unset CFLAGS
unset CXXFLAGS

# 3. Аккуратно убираем проверки архитектуры, не повреждая CMakeLists.txt
perl -pi -e '
    if(/^if\(DEFINED NE10_IOS_TARGET_ARCH\)/../^endif\(\)/) {
        s/^/# / unless /^# /;
    }
' CMakeLists.txt

perl -pi -e '
    if(/^if\(GNULINUX_PLATFORM AND \(NOT CMAKE_SYSTEM_PROCESSOR MATCHES "\^arm"\)\)/../^endif\(\)/) {
        s/^/# / unless /^# /;
    }
' CMakeLists.txt

# 4. Удаляем только -march=... из всех .cmake файлов и CMakeLists.txt, чтобы избежать ошибок компиляции
find . -type f \( -name "*.cmake" -o -name "CMakeLists.txt" \) -exec sed -i 's/-march=[^ ]*//g' {} +

# cd ..
rm -rf build
mkdir build
cd build

# 5. Генерируем toolchain-файл для ARMv8-A с универсальными флагами
cat > ../armv8-toolchain.cmake <<- EOL
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)
set(CMAKE_C_FLAGS "-march=armv8-a -O3 -ffast-math")
set(CMAKE_CXX_FLAGS "\${CMAKE_C_FLAGS}")
EOL

# 6. Конфигурируем и собираем
cmake -DCMAKE_TOOLCHAIN_FILE=../armv8-toolchain.cmake \
      -DGNULINUX_PLATFORM=ON \
      -DNE10_BUILD_STATIC=ON \
      -DNE10_BUILD_UNIT_TEST=OFF \
      ..

make -j$(nproc)

echo "Ne10 успешно собрана с максимальными оптимизациями для ARMv8!"
# echo "$(pwd)"

cd ..
cd ..

# 7. Компиляция вашего бенчмарка
if [ ! -f "$BENCHMARK_SRC" ]; then
  echo "! Файл $BENCHMARK_SRC не найден рядом со скриптом!"
  exit 1
fi


aarch64-linux-gnu-gcc "$BENCHMARK_SRC" \
    -INe10/inc -LNe10/build/modules -lNE10 -lm \
    -march=armv8-a -O3 -ffast-math \
    -o "$BENCHMARK_BIN"

echo "=== Готово ==="
echo "Файл для запуска на ARMv8: $BENCHMARK_BIN"
