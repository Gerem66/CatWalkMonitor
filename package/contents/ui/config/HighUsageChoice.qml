// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kquickcontrols as KQuickControls

/** Whether something changes color above a usage, which one, and to which color. */
RowLayout {
    property alias active: activeBox.checked
    /** In percent. */
    property alias threshold: thresholdField.value
    property alias color: button.color
    property alias dialogTitle: button.dialogTitle

    Controls.CheckBox {
        id: activeBox
        text: i18n("Change color above")
    }
    Controls.SpinBox {
        id: thresholdField
        from: 0
        to: 100
        editable: true
        // Take a typed number into account at once, not when the field is left.
        live: true
        enabled: activeBox.checked
    }
    Controls.Label {
        text: i18nc("@label unit after a number field", "%")
        enabled: activeBox.checked
    }
    KQuickControls.ColorButton {
        id: button
        showAlphaChannel: false
        enabled: activeBox.checked
    }
}
