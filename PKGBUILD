# Maintainer: Mike Wey
pkgname=vibenews
pkgver=0.6.6
pkgrel=1
pkgdesc="The GtkD discussion group"
arch=( 'x86_64' )
url="https://github.com/MikeWey/vibenews/tree/gtkd"
license=('AGPL-3.0')
depends=('mongodb' 'libevent' 'openssl')
makedepends=('d-compiler' 'dub')
conflicts=()
install=$pkgname.install
source=("$pkgname"::'git://github.com/MikeWey/vibenews.git#branch=gtkd')
sha256sums=('SKIP')

build() {
  cd ${srcdir}/$pkgname
  dub build --build=plain
}

package() {
  mkdir -p $pkgdir/usr/local/bin/
  mkdir -p $pkgdir/srv/www/vibenews/
  mkdir -p $pkgdir/etc/vibe/
  mkdir -p $pkgdir/usr/lib/systemd/system/

  cp ${srcdir}/$pkgname/vibenews $pkgdir/usr/local/bin/
  cp ${srcdir}/$pkgname/vibe.conf $pkgdir/etc/vibe/
  cp ${srcdir}/$pkgname/vibenews.conf $pkgdir/etc/vibe/
  cp ${srcdir}/$pkgname/vibenews.service $pkgdir/usr/lib/systemd/system/

  cp -r ${srcdir}/$pkgname/public/* $pkgdir/srv/www/vibenews/
} 
