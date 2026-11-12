import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasmoid

Item {
    id: compactRepresentation
    Layout.minimumHeight: root.inPanel ? Layout.preferredHeight : -1
    Layout.preferredWidth: grid.implicitWidth
    Layout.preferredHeight: grid.implicitHeight
    enum LayoutType {
        HorizontalPanel,
        VerticalPanel,
        HorizontalDesktop,
        VerticalDesktop,
        IconOnly
    }
    // The sensor has no value before its first reading, and nothing says it
    // stays under 100. Left as is, the first case gives the timer a NaN
    // interval and the second a null or negative one.
    readonly property real usage: typeof totalSensor.value === "number" && isFinite(totalSensor.value)
                                  ? Math.max(0, Math.min(totalSensor.value, 100)) : 0
    property int layoutForm
    Binding on layoutForm {
        delayed: true
        value: {
            if (root.inPanel) {
                return root.isVertical ? CompactRepresentation.LayoutType.VerticalPanel : CompactRepresentation.LayoutType.HorizontalPanel
            }
            if (compactRepresentation.parent.width - svgItem.Layout.preferredWidth >= label.contentWidth) {
                return CompactRepresentation.LayoutType.HorizontalDesktop
            }
            if (compactRepresentation.parent.height - svgItem.Layout.preferredHeight >= label.contentHeight) {
                return CompactRepresentation.LayoutType.VerticalDesktop
            }
            return CompactRepresentation.LayoutType.IconOnly
        }
    }
    GridLayout {
        id: grid
        layoutDirection: plasmoid.configuration.iconPosition === 1 ? Qt.RightToLeft : Qt.LeftToRight
        width: {
            switch (compactRepresentation.layoutForm) {
            case CompactRepresentation.LayoutType.HorizontalPanel:
            case CompactRepresentation.LayoutType.HorizontalDesktop:
                return implicitWidth
            case CompactRepresentation.LayoutType.VerticalPanel:
            case CompactRepresentation.LayoutType.VerticalDesktop:
                return compactRepresentation.parent.width
            default:
                return implicitWidth
            }
        }
        height: {
            switch (compactRepresentation.layoutForm) {
            case CompactRepresentation.LayoutType.HorizontalPanel:
            case CompactRepresentation.LayoutType.HorizontalDesktop:
            case CompactRepresentation.LayoutType.VerticalDesktop:
                return compactRepresentation.parent.height
            case CompactRepresentation.LayoutType.VerticalPanel:
                return implicitHeight
            case CompactRepresentation.LayoutType.IconOnly:
                return svgItem.Layout.preferredHeight
            default:
                return implicitHeight
            }
        }
        rowSpacing: 0
        columnSpacing: rowSpacing
        flow: {
            switch (compactRepresentation.layoutForm) {
            case CompactRepresentation.LayoutType.VerticalPanel:
            case CompactRepresentation.LayoutType.VerticalDesktop:
                return GridLayout.TopToBottom
            case CompactRepresentation.LayoutType.HorizontalPanel:
            case CompactRepresentation.LayoutType.HorizontalDesktop:
                return GridLayout.LeftToRight
            case CompactRepresentation.LayoutType.IconOnly:
                return GridLayout.LeftToRight
            default:
                return GridLayout.LeftToRight
            }
        }
        Cat {
            id: svgItem
            usage: compactRepresentation.usage
            idleThreshold: plasmoid.configuration.idle
            frameRate: plasmoid.configuration.frameRate
            color: plasmoid.configuration.highCpuColorEnabled && compactRepresentation.usage > plasmoid.configuration.highCpuThreshold
                ? plasmoid.configuration.highCpuColor : Kirigami.Theme.textColor
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Layout.preferredWidth: Math.min(compactRepresentation.parent.width,
                                            compactRepresentation.parent.height, 128)
            Layout.preferredHeight: Layout.preferredWidth
            Layout.maximumHeight: 128
            Layout.maximumWidth: 128
            visible: plasmoid.configuration.type !== 2
        }
            PlasmaComponents3.Label {
                property double fontHeightRatio: textMetrics.font.pixelSize / textMetrics.height
                id: label
                text: totalSensor.formattedValue
                visible: plasmoid.configuration.type !== 1
                Layout.fillWidth: layoutForm === CompactRepresentation.LayoutType.VerticalPanel
                              || layoutForm === CompactRepresentation.LayoutType.VerticalDesktop
                Layout.maximumWidth: {
                switch (layoutForm) {
                case CompactRepresentation.LayoutType.HorizontalPanel:
                    return textMetrics.width
                case CompactRepresentation.LayoutType.HorizontalDesktop:
                    return compactRepresentation.parent.width
                case CompactRepresentation.LayoutType.VerticalPanel:
                    return compactRepresentation.parent.width
                case CompactRepresentation.LayoutType.VerticalDesktop:
                    return compactRepresentation.parent.width
                case CompactRepresentation.LayoutType.IconOnly:
                    return compactRepresentation.parent.width
                default:
                    return compactRepresentation.parent.width
                }
            }
                Layout.minimumWidth: Layout.maximumWidth
                fontSizeMode: Text.Fit
                height: grid.height * 0.8
                // TODO
                font.pixelSize: isVertical ? Math.max(8, grid.height * 0.25) : Math.max(8, grid.height * 0.5)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }

            TextMetrics {
                id: textMetrics
                font.pixelSize: label.font.pixelSize
                text: "100,0%"
            }
            Sensors.Sensor {
                id: totalSensor
                sensorId: "cpu/all/usage"
                updateRateLimit: plasmoid.configuration.updateRateLimit
            }
    }
}
