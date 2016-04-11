# Building

## Dependencies

This project depends on three other projects:

- [xptools](https://github.com/X-Plane/xptools) by Laminar Research for object drawing.
- [QLdds](https://github.com/Marginal/QLdds) by the author for DDS texture handling.
- [Mesa](http://mesa3d.org/) by Brian Paul et al for rendering (since QuickLook plugins don't have access to Apple's windowing system and OpenGL implementation).

Initialize these projects with:

```
git submodule init
git submodule update
```

## Building Mesa

Mesa's most efficient offscreen rendering method depends on llvm. If you have [Homebrew](http://brew.sh/) you can install llvm with:

```
easy_install mako
brew install autoconf
brew install llvm --with-rtti
```

Build mesa with:

```
cd mesa
ACLOCAL="aclocal -I/usr/local/share/aclocal" autoreconf -vfi
./configure --enable-osmesa --disable-egl --disable-dri --disable-glx --enable-gallium-llvm --with-gallium-drivers=swrast --with-llvm-prefix=/usr/local/opt/llvm --disable-llvm-shared-libs
make -j4
```

## Building QLXPlaneObj

Build the Xcode project `QLQPlaneObj.xcodeproj`.


## Packaging

The [Packages](http://s.sudre.free.fr/Software/Packages/about.html) project `QLXPlaneObj.pkgproj` packages the above targets into a flat `.pkg` file for distribution.

