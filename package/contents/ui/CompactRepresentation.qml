// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

/**
 * What the widget shows: the cat and the readings.
 *
 * A panel fixes one dimension of the widget, its thickness, and lets the
 * other one follow the content. Everything here is sized from the thickness.
 */
Item {
    id: compact

    /** The configuration of the widget. */
    required property var cfg
    /** The sensor readings, a Metrics. */
    required property var metrics
    /** Where the widget is, a PlasmaCore.Types.FormFactor. */
    required property int formFactor

    readonly property bool inPanel: formFactor === PlasmaCore.Types.Horizontal
                                    || formFactor === PlasmaCore.Types.Vertical
    // On the desktop, a widget taller than wide is laid out as in a vertical panel.
    readonly property bool vertical: inPanel ? formFactor === PlasmaCore.Types.Vertical : height > width
    // Capped, so that on the desktop, where the widget can be any size, the
    // cat and the text keep the proportions they have in a panel.
    readonly property real thickness: Math.min(vertical ? width : height, 128)

    readonly property bool showCat: cfg.type !== 2
    readonly property int valueCount: (cfg.showCpu ? 1 : 0) + (cfg.showGpu ? 1 : 0) + (cfg.showRam ? 1 : 0)
    readonly property bool showValues: cfg.type !== 1 && valueCount > 0
    readonly property bool showBoth: showCat && showValues

    // Everything follows the panel: side by side along a horizontal one,
    // one above the other down a vertical one. The cat can also be asked
    // to sit above or below the readings, and the readings to be in a row
    // or in a column, wherever the widget is.
    readonly property bool stacked: showBoth && (vertical || cfg.catPosition >= 2)
    readonly property bool valuesInColumn: cfg.valuesOrientation === 0 ? vertical : cfg.valuesOrientation === 2
    readonly property bool catFirst: cfg.catPosition % 2 === 0
    // The space between the elements is a share of the font size. Lines of
    // text already carry space above and below: none is added between them.
    readonly property real gapEm: 0.5
    readonly property real gap: Math.round(gapEm * fontSize)

    /** The load the cat reacts to. */
    readonly property real catUsage: {
        switch (cfg.catSource) {
        case 1:
            return metrics.gpuUsage;
        case 2:
            return metrics.ramUsage;
        case 3:
        case 4: {
            // The highest of the selected readings, or their average. Those
            // without a value are left out: they would turn either into NaN.
            const selected = [cfg.showCpu ? metrics.cpuUsage : NaN,
                              cfg.showGpu ? metrics.gpuUsage : NaN,
                              cfg.showRam ? metrics.ramUsage : NaN].filter(isFinite);
            if (selected.length === 0) {
                return NaN;
            }
            return cfg.catSource === 3 ? Math.max(...selected)
                                       : selected.reduce((sum, usage) => sum + usage, 0) / selected.length;
        }
        default:
            return metrics.cpuUsage;
        }
    }

    // Sizes are chosen from the room there is.
    readonly property real catSize: {
        // Above or below the readings, the cat leaves them half the thickness.
        return stacked && !vertical ? Math.round(thickness / 2) : thickness;
    }
    readonly property real fontSize: {
        const values = [];
        if (cfg.showCpu) {
            values.push(cpuValue);
        }
        if (cfg.showGpu) {
            values.push(gpuValue);
        }
        if (cfg.showRam) {
            values.push(ramValue);
        }
        if (values.length === 0) {
            // No text to size, and nothing to divide the room by.
            return 6;
        }
        // A length is `em * size + pixels`: what grows with the font, and
        // what does not. The spacing is of the first kind, up to the pixel
        // its rounding can add.
        const spacingEm = gapEm;
        const spacingPixels = 1;
        let em;
        let pixels;
        // A single line takes half the thickness. More than that has to fit...
        let size = thickness / 2;
        if (vertical && valuesInColumn) {
            // ...in the width of the panel, each value on its own line,
            size = Math.min(size, ...values.map(value => (thickness - value.pixels) / value.em));
        } else if (vertical) {
            // ...or all of them side by side,
            const gaps = values.length - 1;
            em = values.reduce((sum, value) => sum + value.em, 0) + gaps * spacingEm;
            pixels = values.reduce((sum, value) => sum + value.pixels, 0) + gaps * spacingPixels;
            size = Math.min(size, (thickness - pixels) / em);
        } else {
            // ...or in the height of the panel, less what the cat takes above or below.
            const lines = valuesInColumn ? values.length : 1;
            em = lines * cpuValue.lineEm;
            pixels = 0;
            if (stacked) {
                em += spacingEm;
                pixels += catSize + spacingPixels;
            }
            size = Math.min(size, (thickness - pixels) / em);
        }
        return Math.max(6, Math.floor(size));
    }

    readonly property color catColor: {
        if (cfg.highUsageColorEnabled && catUsage > cfg.highUsageThreshold) {
            return cfg.highUsageColor;
        }
        return Kirigami.Theme.textColor;
    }

    // In a panel the widget is exactly as long as its content.
    Layout.minimumWidth: inPanel && !vertical ? content.implicitWidth : -1
    Layout.preferredWidth: content.implicitWidth
    Layout.minimumHeight: inPanel && vertical ? content.implicitHeight : -1
    Layout.preferredHeight: content.implicitHeight

    GridLayout {
        id: content

        anchors.centerIn: parent
        // On the desktop the widget can be made smaller than its content.
        scale: Math.min(1, compact.width / Math.max(1, implicitWidth), compact.height / Math.max(1, implicitHeight))
        columns: compact.stacked ? 1 : 2
        columnSpacing: compact.gap
        rowSpacing: compact.gap

        Cat {
            Layout.row: compact.stacked && !compact.catFirst ? 1 : 0
            Layout.column: compact.showBoth && !compact.stacked && !compact.catFirst ? 1 : 0
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: compact.catSize
            Layout.preferredHeight: compact.catSize
            visible: compact.showCat
            usage: compact.catUsage
            idleThreshold: compact.cfg.idle
            walkThreshold: compact.cfg.walkThreshold
            frameRate: compact.cfg.frameRate
            color: compact.catColor
        }

        GridLayout {
            Layout.row: compact.stacked && compact.catFirst ? 1 : 0
            Layout.column: compact.showBoth && !compact.stacked && compact.catFirst ? 1 : 0
            Layout.alignment: Qt.AlignCenter
            visible: compact.showValues
            flow: compact.valuesInColumn ? GridLayout.TopToBottom : GridLayout.LeftToRight
            columnSpacing: compact.gap
            rowSpacing: 0

            MetricItem {
                id: cpuValue
                visible: compact.cfg.showCpu
                usage: compact.metrics.cpuUsage
                temperature: compact.metrics.cpuTemperature
                fontSize: compact.fontSize
                color: Kirigami.Theme.textColor
                Layout.fillWidth: compact.valuesInColumn
            }
            MetricItem {
                id: gpuValue
                visible: compact.cfg.showGpu
                usage: compact.metrics.gpuUsage
                temperature: compact.metrics.gpuTemperature
                fontSize: compact.fontSize
                color: Kirigami.Theme.textColor
                Layout.fillWidth: compact.valuesInColumn
            }
            MetricItem {
                id: ramValue
                visible: compact.cfg.showRam
                usage: compact.metrics.ramUsage
                temperature: compact.metrics.ramTemperature
                fontSize: compact.fontSize
                color: Kirigami.Theme.textColor
                Layout.fillWidth: compact.valuesInColumn
            }
        }
    }
}
