cmake_minimum_required(VERSION 3.16)

# The widget is made of QML and data files only. There is nothing to compile,
# so installing it needs neither a compiler nor the KDE development packages.
project(catwalk-monitor VERSION 4.0.0 LANGUAGES NONE)

install(DIRECTORY package/
        DESTINATION share/plasma/plasmoids/com.github.gerem66.catwalkmonitor)
