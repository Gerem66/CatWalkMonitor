// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Effects

/**
 * Paints what it contains in one color, the way a theme colors its icons.
 * Meant for white pictures: the result is `color` wherever they are opaque.
 *
 * This is done on the GPU, and unlike Kirigami.Icon it never swaps a picture
 * for an icon of the theme that happens to have the same file name.
 */
Item {
    id: tinted

    property color color

    // The software renderer has no effects: the pictures then stay white.
    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
    layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: tinted.color
    }
}
