// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kquickcontrols as KQuickControls

/** A color that is either left to the theme or picked by the user. */
RowLayout {
    property alias custom: customBox.checked
    property alias color: button.color
    property alias dialogTitle: button.dialogTitle

    Controls.CheckBox {
        id: customBox
        text: i18nc("@option:check use a color of one's own instead of the theme's", "Custom")
    }
    KQuickControls.ColorButton {
        id: button
        showAlphaChannel: false
        enabled: customBox.checked
    }
}
