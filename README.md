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

## Credits

CatWalk Monitor is a fork of
[CatWalk Neo](https://github.com/SpinningVinyl/CatWalkNeo) by Pavel Urusov,
itself based on the CatWalk plasmoid by Yuri Saurov
([Plasma 6](https://store.kde.org/p/2137844/),
[Plasma 5](https://store.kde.org/p/2055225/)). The history of both projects
is kept in this repository.
