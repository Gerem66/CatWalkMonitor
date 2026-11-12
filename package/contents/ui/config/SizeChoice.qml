// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

/**
 * A size in pixels that is left to the widget unless the user sets one.
 *
 * `value` is the size, or `automaticValue` while the widget chooses it.
 */
RowLayout {
    id: choice

    property int value: automaticValue
    /** What `value` is while the size is automatic; it must be under `from`. */
    property int automaticValue: 0
    property alias from: field.from
    property alias to: field.to
    /** The size proposed when the user takes over. */
    property int suggested: from

    readonly property bool automatic: value === automaticValue

    // Follow a value that comes from outside, such as the saved one. Not
    // tested with `automatic`: that binding may not be up to date yet here.
    onValueChanged: {
        if (value !== automaticValue) {
            field.value = value;
        }
    }

    Controls.CheckBox {
        text: i18nc("@option:check the widget chooses the size", "Automatic")
        checked: choice.automatic
        onToggled: choice.value = checked ? choice.automaticValue : field.value
    }
    Controls.SpinBox {
        id: field
        value: choice.suggested
        editable: true
        // Take a typed number into account at once, not when the field is left.
        live: true
        enabled: !choice.automatic
        onValueModified: choice.value = value
    }
    Controls.Label {
        text: i18nc("@label unit after a number field", "px")
        enabled: !choice.automatic
    }
}
