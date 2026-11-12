// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.components as PlasmaComponents

/**
 * A text that does not change width each time its content does.
 *
 * It is as wide as the widest text it showed lately: it widens at once when
 * a wider text comes, and narrows only after `settleTime` without needing
 * the room. A value wavering between 9.9 and 10.0 therefore does not make
 * its neighbors jump at each reading, and yet no room is kept for digits
 * that never come.
 */
Item {
    id: stable

    property string text
    /** Font size, in pixels. */
    property real fontSize: 12
    property color color
    property int horizontalAlignment: Text.AlignLeft
    /** How long the text has to stay narrower before the width follows, in milliseconds. */
    property int settleTime: 10000

    /** Width of the item for a font size of one pixel. */
    property real em: 0
    /** Height of a line of text for a font size of one pixel. */
    readonly property real lineEm: metrics.height / metrics.font.pixelSize

    // The widest text shown since the timer started: what the width
    // narrows to when it fires.
    property real widestSince: 0

    function measure(string) {
        return metrics.advanceWidth(string) / metrics.font.pixelSize;
    }

    /** Take the width of the current text now, without waiting. */
    function fit() {
        settle.stop();
        em = measure(text);
    }

    onTextChanged: {
        const width = measure(text);
        if (width >= em) {
            em = width;
            settle.stop();
        } else if (settle.running) {
            widestSince = Math.max(widestSince, width);
        } else {
            widestSince = width;
            settle.start();
        }
    }
    Component.onCompleted: fit()

    implicitWidth: Math.ceil(em * fontSize)
    implicitHeight: label.implicitHeight

    PlasmaComponents.Label {
        id: label
        anchors.fill: parent
        text: stable.text
        textFormat: Text.PlainText
        color: stable.color
        font.pixelSize: stable.fontSize
        // Digits of equal width: the width then only depends on their number.
        font.features: { "tnum": 1 }
        horizontalAlignment: stable.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
    }

    // Measured at a fixed, large size: the result must not depend on
    // `fontSize`, which the layout derives from it.
    FontMetrics {
        id: metrics
        font.family: label.font.family
        font.weight: label.font.weight
        font.features: label.font.features
        font.pixelSize: 100
    }

    Timer {
        id: settle
        interval: stable.settleTime
        onTriggered: {
            stable.em = stable.widestSince;
            // Narrower still by now: wait again before following.
            const width = stable.measure(stable.text);
            if (width < stable.em) {
                stable.widestSince = width;
                start();
            }
        }
    }
}
