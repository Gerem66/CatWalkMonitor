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
    property alias cfg_showIcons: showIcons.checked
    property alias cfg_cpuColorCustom: cpuColor.custom
    property alias cfg_cpuColor: cpuColor.color
    property alias cfg_gpuColorCustom: gpuColor.custom
    property alias cfg_gpuColor: gpuColor.color
    property alias cfg_ramColorCustom: ramColor.custom
    property alias cfg_ramColor: ramColor.color
    property alias cfg_type: type.currentIndex
    property alias cfg_valuesOrientation: valuesOrientation.currentIndex
    property alias cfg_catSource: catSource.currentIndex
    property alias cfg_catPosition: catPosition.currentIndex
    property alias cfg_catSize: catSize.value
    property alias cfg_catColorCustom: catColor.custom
    property alias cfg_catColor: catColor.color
    property alias cfg_highUsageColorEnabled: catHighUsage.active
    property alias cfg_highUsageThreshold: catHighUsage.threshold
    property alias cfg_highUsageColor: catHighUsage.color
    property alias cfg_textSize: textSize.value
    property alias cfg_textColorCustom: textColor.custom
    property alias cfg_textColor: textColor.color
    property alias cfg_idle: idle.value
    property alias cfg_walkThreshold: walkThreshold.value
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

        Controls.ComboBox {
            id: valuesOrientation
            Kirigami.FormData.label: i18n("Arrange the values:")
            model: [i18n("Along the panel"), i18n("In a row"), i18n("In a column")]
            enabled: type.currentIndex !== 1
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Cat")
        }

        Controls.ComboBox {
            id: catPosition
            Kirigami.FormData.label: i18n("Position:")
            model: [i18n("Before the values"), i18n("After the values"),
                    i18n("Above the values"), i18n("Below the values")]
            enabled: type.currentIndex === 0
        }

        SizeChoice {
            id: catSize
            Kirigami.FormData.label: i18n("Size:")
            from: 1
            to: 256
            suggested: 32
            enabled: type.currentIndex !== 2
        }

        ColorChoice {
            id: catColor
            Kirigami.FormData.label: i18n("Color:")
            dialogTitle: i18nc("@title:window", "Color of the cat")
            enabled: type.currentIndex !== 2
        }

        HighUsageChoice {
            id: catHighUsage
            Kirigami.FormData.label: i18n("High usage:")
            dialogTitle: i18nc("@title:window", "Color of the cat at high usage")
            enabled: type.currentIndex !== 2
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Values")
        }

        SizeChoice {
            id: textSize
            Kirigami.FormData.label: i18n("Size:")
            from: 1
            to: 128
            suggested: 14
            enabled: type.currentIndex !== 1
        }

        ColorChoice {
            id: textColor
            Kirigami.FormData.label: i18n("Color:")
            dialogTitle: i18nc("@title:window", "Color of the values")
            enabled: type.currentIndex !== 1
        }

        Controls.CheckBox {
            id: showIcons
            Kirigami.FormData.label: i18n("Icons:")
            text: i18n("Show an icon before each value")
            enabled: type.currentIndex !== 1
        }

        // What is particular to a value overrides what they share.
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "CPU")
        }

        ColorChoice {
            id: cpuColor
            Kirigami.FormData.label: i18n("Color:")
            dialogTitle: i18nc("@title:window", "Color of the CPU value")
            enabled: type.currentIndex !== 1 && showCpu.checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "GPU")
        }

        ColorChoice {
            id: gpuColor
            Kirigami.FormData.label: i18n("Color:")
            dialogTitle: i18nc("@title:window", "Color of the GPU value")
            enabled: type.currentIndex !== 1 && showGpu.checked
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nc("@title:group", "Memory")
        }

        ColorChoice {
            id: ramColor
            Kirigami.FormData.label: i18n("Color:")
            dialogTitle: i18nc("@title:window", "Color of the memory value")
            enabled: type.currentIndex !== 1 && showRam.checked
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
            Kirigami.FormData.label: i18n("Walk below:")
            enabled: type.currentIndex !== 2

            ValueSlider {
                id: walkThreshold
                from: 0
                to: 100
                stepSize: 5
                format: value => i18nc("a percentage", "%1%", Math.round(value))
            }
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("The cat walks while the usage it follows is under this value, and runs from there on. At 0 it always runs.")
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
