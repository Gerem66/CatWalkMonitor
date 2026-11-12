import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    property alias cfg_idle: idleSlider.value
    property alias cfg_type: typeBox.currentIndex
    property alias cfg_iconPosition: iconPositionBox.currentIndex
    property alias cfg_highCpuColorEnabled: highCpuColorCheckBox.checked
    property alias cfg_highCpuThreshold: highCpuThresholdSpinBox.value
    property alias cfg_highCpuColor: highCpuColorButton.color
    property alias cfg_updateRateLimit: updateRateLimitSpinBox.value
    Kirigami.FormLayout {
        id: root

        RowLayout {
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Idle threshold")
            Controls.Slider {
                Layout.fillWidth: true
                id: idleSlider
                from: 0
                to: 100
                stepSize: 1
            }
            Controls.Label {
                id: label
                text: idleSlider.value + "%"
                Layout.minimumWidth: textMetrics.width
                Layout.minimumHeight: textMetrics.height
                horizontalAlignment: Text.AlignRight
            }
            TextMetrics {
                id: textMetrics
                text: "199%"
            }
        }
        Controls.ComboBox {
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Displaying items")
            id: typeBox
            model: [i18n("Character and percentage"), i18n(
                    "Character only"), i18n("Percentage only")]
        }
        Controls.ComboBox {
            id: iconPositionBox
            Layout.fillWidth: true
            Kirigami.FormData.label: i18n("Icon position")
            model: [i18n("Left"), i18n("Right")]
            enabled: typeBox.currentIndex === 0
        }
        Controls.CheckBox {
            id: highCpuColorCheckBox
            text: i18n("Change cat colour at high CPU usage")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("CPU usage threshold")
            enabled: highCpuColorCheckBox.checked
            Controls.SpinBox {
                id: highCpuThresholdSpinBox
                from: 0
                to: 100
                editable: true
            }
            Controls.Label {
                text: "%"
            }
        }
        KQuickControls.ColorButton {
            id: highCpuColorButton
            Kirigami.FormData.label: i18n("High CPU colour")
            dialogTitle: i18n("Choose high CPU colour")
            showAlphaChannel: false
            enabled: highCpuColorCheckBox.checked
        }
        Controls.SpinBox {
            id: updateRateLimitSpinBox
            Layout.fillWidth: true
            Kirigami.FormData.label: i18nd("KSysGuardSensorFaces",
                                           "Minimum Time Between Updates:")
            from: 0
            to: 60000
            stepSize: 500
            editable: true
            textFromValue: function (value, locale) {
                if (value <= 0) {
                    return i18nd("KSysGuardSensorFaces", "No Limit")
                } else {
                    var seconds = value / 1000
                    if (seconds == 1) {
                        return i18nd("KSysGuardSensorFaces", "1 second")
                    } else {
                        return i18nd("KSysGuardSensorFaces",
                                     "%1 seconds", seconds)
                    }
                }
            }
            valueFromText: function (value, locale) {
                var v = parseInt(value)
                if (isNaN(v)) {
                    return 0
                } else {
                    return v * 1000
                }
            }
        }
    }
}
