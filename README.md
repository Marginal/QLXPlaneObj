QuickLook XPlane Object
=======================

This package allows OSX Finder to display thumbnails and QuickLook previews for [X-Plane](http://www.x-plane.com) 3D Object files.

Installation
------------
* Download the `.pkg` file (the green button) of the [latest release](https://github.com/Marginal/QLXPlaneObj/releases/latest).
* Double-click on it.
* The Installer app will walk you through the installation process.

Screenshots
-----------
![Finder screenshot](img/finder.jpeg) ![Get Info](img/getinfo.jpeg) ![Preview](img/preview.jpeg) ![Multiple](img/multiple.jpeg)

Uninstall
---------
* Run the Terminal app (found in Applications → Utilities).
* Copy the following and paste into the Terminal app:

        sudo rm -rf "/Library/Application Support/QLXPlaneObj" "/Library/QuickLook/XPlaneObj.qlgenerator" "/Library/Spotlight/XPlaneObj.mdimporter"

* Press Enter.
* Type your password and press Enter.

Limitations
-----------
* To see thumbnails you may need to relaunch Finder (ctrl-⌥-click on the Finder icon in the Dock and choose Relaunch) or log out and back in again.
* Requires OSX 10.6 or later.

Acknowledgements
----------------
* Uses [xptools](https://github.com/X-Plane/xptools) © Laminar Research, licensed under the MIT/X11 license.
* Uses [QLdds](https://github.com/Marginal/QLdds) © Jonathan Harris, licensed under the GPL version 2 or later.
* Uses [Mesa](http://mesa3d.org/) © Brian Paul et al, licensed under the MIT license.
* Packaged using [Packages](http://s.sudre.free.fr/Software/Packages/about.html).

License
-------
Copyright © 2016 Jonathan Harris.

Licensed under the [GNU Public License (GPL)](http://www.gnu.org/licenses/gpl-2.0.html) version 2 or later.

