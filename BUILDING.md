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

## Building
If you want the project to work on older versions of OSX:

```
export CXXFLAGS=-stdlib=libc++
export MACOSX_DEPLOYMENT_TARGET=10.7
```

### Building Mesa

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

### Building QLXPlaneObj

The Xcode project `QLXPlaneObj.xcodeproj` builds the following targets:

* QLXPlaneObj.app - Launch Services won't read [Uniform Type Identifiers](http://developer.apple.com/library/mac/documentation/General/Conceptual/DevPedia-CocoaCore/UniformTypeIdentifier.html) from plugin bundles, so this dummy app serves to register the UTIs of the media types that the plugins understand. Should be installed in /Libarary/Application Support/QLXPlaneObj/.
* XPlaneObj.mdimporter - Spotlight plugin. Should be installed in /Library/Spotlight/.
* XPlaneObj.qlgenerator - QuickLook plugin. Should be installed in /Library/QuickLook/.


## Packaging

The [Packages](http://s.sudre.free.fr/Software/Packages/about.html) project `QLXPlaneObj.pkgproj` packages the above targets into a flat `.pkg` file for distribution.

