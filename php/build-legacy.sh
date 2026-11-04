#!/usr/bin/env bash
# Compila um PHP 7.x antigo para o asdf no macOS 14 arm64, sem Homebrew.
# Não há binário pronto do 7.x para arm64 e o plugin do asdf depende do
# openssl@1.1, que o brew não oferece mais. Usa as bibliotecas do SDK do macOS
# (zlib, curl, libxml2, bzip2) e um OpenSSL 1.1 estático compilado junto.
# Sem iconv (o configure do 7.3 não acha a do SDK) nem intl/gd/sodium.
#
# Uso: build-legacy.sh <versão> <sha256-php> <versão-openssl> <sha256-openssl> <pasta-de-trabalho>
# Instala em ~/.asdf/installs/php/<versão>. PHP 7.x não recebe mais correções
# de segurança: só para desenvolvimento local.
set -euo pipefail

php_v="$1" php_sha="$2" ssl_v="$3" ssl_sha="$4" work="$5"
prefix="$HOME/.asdf/installs/php/$php_v"
sdk="$(xcrun --show-sdk-path)"

get() {
  curl -fsSL --proto '=https' --tlsv1.2 -o "$2" "$1"
  echo "$3  $2" | shasum -a 256 -c - >/dev/null || { echo "checksum não confere: $1" >&2; exit 1; }
}

mkdir -p "$work"
cd "$work"
get "https://github.com/openssl/openssl/releases/download/OpenSSL_${ssl_v//./_}/openssl-$ssl_v.tar.gz" ssl.tar.gz "$ssl_sha"
get "https://www.php.net/distributions/php-$php_v.tar.gz" php.tar.gz "$php_sha"
tar -xzf ssl.tar.gz
tar -xzf php.tar.gz

ssl_prefix="$prefix/openssl"
(cd "openssl-$ssl_v" &&
  ./Configure darwin64-arm64-cc no-shared no-tests --prefix="$ssl_prefix" --openssldir="$ssl_prefix/ssl" >/dev/null &&
  make -j4 >/dev/null && make install_sw >/dev/null)

cd "php-$php_v"
# o clang atual trata como erro construções que o código do 7.x usa
export CFLAGS="-O2 -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-int-conversion"
export LIBS="-lresolv" # dn_expand/res_search no macOS
./configure --prefix="$prefix" \
  --with-config-file-path="$prefix/etc" --with-config-file-scan-dir="$prefix/etc/conf.d" \
  --disable-cgi --enable-fpm --without-pear --disable-phpdbg --without-pcre-jit \
  --with-openssl="$ssl_prefix" --with-zlib="$sdk/usr" --with-curl="$sdk/usr" \
  --with-libxml-dir="$sdk/usr" --with-bz2="$sdk/usr" --without-iconv \
  --enable-mbstring --enable-bcmath --enable-calendar --enable-ctype --enable-exif \
  --enable-pcntl --enable-sockets --enable-zip --without-libzip --enable-soap --enable-opcache \
  --with-pdo-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-sqlite --with-sqlite3 >configure.log
make -j4 >make.log 2>&1
make install >install.log 2>&1

# certificados do macOS para HTTPS (o OpenSSL próprio não os conhece)
mkdir -p "$prefix/etc/conf.d"
printf 'openssl.cafile=/etc/ssl/cert.pem\ncurl.cainfo=/etc/ssl/cert.pem\n' >"$prefix/etc/conf.d/ca.ini"
echo 'zend_extension=opcache.so' >"$prefix/etc/conf.d/opcache.ini"
"$prefix/bin/php" -v
