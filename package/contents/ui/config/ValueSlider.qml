// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

/** A slider with its value written next to it. */
RowLayout {
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    /** Turns a value into the text written next to the slider. */
    property var format: value => value

    Controls.Slider {
        id: slider
        Layout.fillWidth: true
        snapMode: Controls.Slider.SnapAlways
    }
    Controls.Label {
        // As wide as the longest text, or the slider would resize as it moves.
        Layout.minimumWidth: widest.width
        horizontalAlignment: Text.AlignRight
        text: format(slider.value)
    }
    TextMetrics {
        id: widest
        text: format(slider.to)
    }
}
