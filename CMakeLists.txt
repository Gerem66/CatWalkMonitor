cmake_minimum_required(VERSION 3.20 FATAL_ERROR)
project(catwalk)

set(QT_MAJOR_VERSION 6)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${ECM_KDE_MODULE_DIR})

include(KDEInstallDirs)

find_package(Plasma REQUIRED)
find_package(KF6I18n NO_MODULE)

plasma_install_package(package com.github.gerem66.catwalkmonitor)
ki18n_install(translations)
