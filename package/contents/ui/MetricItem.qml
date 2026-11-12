// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

/**
 * One reading: an optional icon, a usage, and a temperature if there is one.
 *
 * It is exactly as wide as what it shows. Its texts are StableText, so the
 * width does not change at each reading for all that.
 */
Item {
    id: metric

    /** In percent; NaN when there is no reading. */
    property real usage: NaN
    /** In degrees Celsius; NaN when there is none to show. */
    property real temperature: NaN
    /** Font size, in pixels. */
    property real fontSize: 12
    /** Color of the text and of the icon. */
    property color color
    /** The white picture that tells what the reading is, drawn before the text. */
    property url icon
    property bool showIcon: false
    /** Space between the usage and the temperature, in pixels; a share of the font size if negative. */
    property real temperatureSpacing: -1

    readonly property bool hasTemperature: isFinite(temperature)
    readonly property bool automaticTemperatureSpacing: temperatureSpacing < 0

    // Proportions, relative to the font size.
    readonly property real iconEm: 1.1
    readonly property real iconGapEm: 0.3
    readonly property real temperatureGapEm: 0.3

    // The item is at most `em * fontSize + pixels` wide: `em` is what grows
    // with the font, `pixels` what does not: a spacing given in pixels, and
    // what rounding each part to whole pixels can add.
    readonly property real em: (showIcon ? iconEm + iconGapEm : 0) + usageText.em
                               + (hasTemperature ? temperatureText.em + (automaticTemperatureSpacing ? temperatureGapEm : 0) : 0)
    readonly property real pixels: (showIcon ? 2 : 0) + 1
                                   + (hasTemperature ? 2 + (automaticTemperatureSpacing ? 0 : temperatureSpacing) : 0)
    /** Height of a line of text for a font size of one pixel. */
    readonly property real lineEm: usageText.lineEm

    implicitWidth: (showIcon ? image.width + Math.round(iconGapEm * fontSize) : 0) + texts.implicitWidth
    implicitHeight: usageText.implicitHeight

    Tinted {
        id: image
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(metric.iconEm * metric.fontSize)
        height: width
        visible: metric.showIcon
        color: metric.color

        Image {
            anchors.fill: parent
            // Not loaded as long as it is not shown.
            source: metric.showIcon ? metric.icon : ""
            sourceSize: Qt.size(width, height)
        }
    }

    // The icon is at the left edge and the text at the right one: in a
    // column, where every value is as wide as the widest, the icons line up
    // on one side and the numbers on the other.
    Row {
        id: texts
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: metric.automaticTemperatureSpacing ? Math.round(metric.temperatureGapEm * metric.fontSize)
                                                    : metric.temperatureSpacing

        StableText {
            id: usageText
            text: isFinite(metric.usage) ? metric.usage.toLocaleString(Qt.locale(), "f", 1) + "%" : "–"
            fontSize: metric.fontSize
            color: metric.color
            horizontalAlignment: Text.AlignRight
        }
        StableText {
            id: temperatureText
            visible: metric.hasTemperature
            text: metric.hasTemperature ? Math.round(metric.temperature) + "°C" : ""
            fontSize: metric.fontSize
            color: metric.color
        }
    }
}
