# Building

## Dependencies

This project depends on two other projects:

- [xptools](https://github.com/X-Plane/xptools) by Laminar Research for object drawing.
- [QLdds](https://github.com/Marginal/QLdds) by the author for DDS texture handling.

Initialize these projects with:

```
git submodule init
git submodule update
```

## Building

The Xcode project `QLXPlaneObj.xcodeproj` builds the following targets:

* QLXPlaneObj.app - Launch Services won't read [Uniform Type Identifiers](http://developer.apple.com/library/mac/documentation/General/Conceptual/DevPedia-CocoaCore/UniformTypeIdentifier.html) from plugin bundles, so this dummy app serves to register the UTIs of the file types that the plugins understand. Should be installed in /Libarary/Application Support/QLXPlaneObj/.
* XPlaneObj.mdimporter - Spotlight plugin. Should be installed in /Library/Spotlight/.
* XPlaneObj.qlgenerator - QuickLook plugin. Should be installed in /Library/QuickLook/.


## Packaging

The [Packages](http://s.sudre.free.fr/Software/Packages/about.html) project `QLXPlaneObj.pkgproj` packages the above targets into a flat `.pkg` file for distribution.

