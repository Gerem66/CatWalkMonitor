# CatWalk Monitor

A simple plasmoid showing the total CPU usage as a cat: the busier the
processor, the faster the cat runs.

## Installation

Requires KDE Plasma 6.

```sh
git clone https://github.com/Gerem66/CatWalkMonitor.git
cd CatWalkMonitor
kpackagetool6 --type Plasma/Applet --install package
```

Then add *CatWalk Monitor* to a panel or to the desktop from
*Add or Manage Widgets…*.

To update an existing installation, from the same directory:

```sh
git pull
kpackagetool6 --type Plasma/Applet --upgrade package
systemctl --user restart plasma-plasmashell
```

The last command matters: a running Plasma keeps the previous version of
the widget in memory. Without it, the settings page is the new one but the
widget, its translations and the list of its settings are still the old
ones, so new settings show in English and are not saved.

To remove it:

```sh
kpackagetool6 --type Plasma/Applet --remove com.github.gerem66.catwalkmonitor
```

The package can also be installed with CMake, which needs no compiler:
`cmake -B build && cmake --install build --prefix ~/.local`.

## Credits

CatWalk Monitor is a fork of
[CatWalk Neo](https://github.com/SpinningVinyl/CatWalkNeo) by Pavel Urusov,
itself based on the CatWalk plasmoid by Yuri Saurov
([Plasma 6](https://store.kde.org/p/2137844/),
[Plasma 5](https://store.kde.org/p/2055225/)). The history of both projects
is kept in this repository.

The cat was drawn by Takuto Nakamura for [RunCat](https://github.com/Kyome22/menubar_runcat)
(Apache License 2.0); these drawings very likely came to CatWalk through the
[RunCat GNOME extension](https://github.com/win0err/gnome-runcat) by Sergei
Kolesnikov (GPL-3.0).

## License

CatWalk Monitor is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version. See [LICENSE](LICENSE).

CatWalk and CatWalk Neo are distributed under the GNU General Public License,
version 2 or any later version; this fork uses version 3, the one that is
compatible with the licenses of the artwork.
