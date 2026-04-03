# Maintainer: Chris Singley <csingley@gmail.com>
pkgname=k8sdoom-git
pkgver=1.0.0
pkgrel=1
pkgdesc="Doom-based Kubernetes administration tool"
arch=('x86_64' 'aarch64')
url="https://github.com/csingley/k8sdoom"
license=('GPL2')
depends=('sdl2' 'sdl2_mixer' 'sdl2_net' 'kubectl' 'jq')
makedepends=('git' 'cmake' 'autoconf' 'automake')
provides=('k8sdoom')
conflicts=('k8sdoom')
source=('git+https://github.com/csingley/k8sdoom.git')
sha256sums=('SKIP')

build() {
  cd "$srcdir/k8sdoom"
  # We use the Makefile but force it to use system dependencies
  make build FORCE_VENDORED=0 PREFIX=/usr
}

package() {
  cd "$srcdir/k8sdoom"
  # Use the Makefile install target with the package destination directory
  make install PREFIX="$pkgdir/usr"
  
  # Ensure the wrapper script points to the correct system-wide data dir
  sed -i "s|DATA_DIR=.*|DATA_DIR=/usr/share/k8sdoom|" "$pkgdir/usr/bin/k8sdoom"
}
