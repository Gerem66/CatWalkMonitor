// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    property alias cfg_showCpu: showCpu.checked
    property alias cfg_showGpu: showGpu.checked
    property alias cfg_showRam: showRam.checked
    property alias cfg_showCpuTemp: showCpuTemp.checked
    property alias cfg_showGpuTemp: showGpuTemp.checked
    property alias cfg_showRamTemp: showRamTemp.checked
    property alias cfg_type: type.currentIndex
    property alias cfg_catSource: catSource.currentIndex
    property alias cfg_catPosition: catPosition.currentIndex
    property alias cfg_highUsageColorEnabled: catHighUsage.active
    property alias cfg_highUsageThreshold: catHighUsage.threshold
    property alias cfg_highUsageColor: catHighUsage.color
    property alias cfg_idle: idle.value
    property alias cfg_updateRateLimit: updateRateLimit.value
    property alias cfg_frameRate: frameRate.value

    Kirigami.FormLayout {
        Controls.ComboBox {
            id: type
            Kirigami.FormData.label: i18n("Display:")
            model: [i18n("Cat and values"), i18n("Cat only"), i18n("Values only")]
        }

        GridLayout {
            Kirigami.FormData.label: i18n("Values:")
            Kirigami.FormData.buddyFor: showCpu
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing

            Controls.CheckBox {
                id: showCpu
                text: i18n("CPU usage")
            }
            Controls.CheckBox {
                id: showCpuTemp
                text: i18n("and temperature")
                enabled: showCpu.checked
            }
            Controls.CheckBox {
                id: showGpu
                text: i18n("GPU usage")
            }
            Controls.CheckBox {
                id: showGpuTemp
                text: i18n("and temperature")
                enabled: showGpu.checked
            }
            Controls.CheckBox {
                id: showRam
                text: i18n("Memory usage")
            }
            RowLayout {
                Controls.CheckBox {
                    id: showRamTemp
                    text: i18n("and temperature")
                    enabled: showRam.checked
                }
                Kirigami.ContextualHelpButton {
                    toolTipText: i18n("Only memory modules with a temperature sensor report one, which is common with DDR5 and rare before. Nothing is shown otherwise.")
                }
            }
        }

        // Without this, selecting values that the panel does not show looks pointless.
        Controls.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            visible: type.currentIndex === 1
            text: i18n("With the cat alone, the selected values appear in its tooltip, and the cat can follow them.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
            opacity: 0.75
        }

        Controls.ComboBox {
            id: catSource
            Kirigami.FormData.label: i18n("The cat follows:")
            model: [i18n("CPU usage"), i18n("GPU usage"), i18n("Memory usage"),
                    i18n("The highest of the selected values"),
                    i18n("The average of the selected values")]
            enabled: type.currentIndex !== 2
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Cat")
        }

        Controls.ComboBox {
            id: catPosition
            Kirigami.FormData.label: i18n("Position:")
            model: [i18n("Before the values"), i18n("After the values")]
            enabled: type.currentIndex === 0
        }

        HighUsageChoice {
            id: catHighUsage
            Kirigami.FormData.label: i18n("High usage:")
            dialogTitle: i18nc("@title:window", "Color of the cat at high usage")
            enabled: type.currentIndex !== 2
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Advanced")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Idle threshold:")
            enabled: type.currentIndex !== 2

            ValueSlider {
                id: idle
                from: 0
                to: 100
                stepSize: 1
                format: value => i18nc("a percentage", "%1%", Math.round(value))
            }
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("The cat sleeps while the usage it follows is under this value.")
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Frame rate:")
            enabled: type.currentIndex !== 2

            ValueSlider {
                id: frameRate
                from: 5
                to: 60
                stepSize: 5
                format: value => i18nc("frames per second", "%1 fps", Math.round(value))
            }
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("How many times per second the cat is drawn while it runs. A lower value is less smooth and lighter on the system.")
            }
        }

        Controls.SpinBox {
            id: updateRateLimit
            Kirigami.FormData.label: i18nd("KSysGuardSensorFaces", "Minimum Time Between Updates:")
            from: 0
            to: 60000
            stepSize: 500
            // Its text is a sentence, not a number: it is not meant to be typed in.
            editable: false
            textFromValue: value => {
                if (value <= 0) {
                    return i18nd("KSysGuardSensorFaces", "No Limit");
                }
                const seconds = value / 1000;
                return seconds === 1 ? i18nd("KSysGuardSensorFaces", "1 second")
                                     : i18nd("KSysGuardSensorFaces", "%1 seconds", seconds);
            }
        }
    }
}
