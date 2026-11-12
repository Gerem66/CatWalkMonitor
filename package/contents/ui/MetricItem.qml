// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

/**
 * One reading: a usage, and a temperature if there is one.
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
    /** Color of the text. */
    property color color

    readonly property bool hasTemperature: isFinite(temperature)

    // Proportions, relative to the font size.
    readonly property real temperatureGapEm: 0.3

    // The item is at most `em * fontSize + pixels` wide: `em` is what grows
    // with the font, `pixels` what does not, which here is only what
    // rounding each part to whole pixels can add.
    readonly property real em: usageText.em + (hasTemperature ? temperatureText.em + temperatureGapEm : 0)
    readonly property real pixels: 1 + (hasTemperature ? 2 : 0)
    /** Height of a line of text for a font size of one pixel. */
    readonly property real lineEm: usageText.lineEm

    implicitWidth: texts.implicitWidth
    implicitHeight: usageText.implicitHeight

    // The text is at the right edge: in a column, where every value is as
    // wide as the widest, the numbers line up there.
    Row {
        id: texts
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(metric.temperatureGapEm * metric.fontSize)

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
