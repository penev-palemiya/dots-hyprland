import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root

    property real value: 0
    property real minimum: 0
    property real maximum: 999999
    property real step: 1
    property bool integer: true
    property bool allowEmpty: false
    property string unit: ""
    property string editingText: root.formatValue(root.value)
    property bool inputValid: root.validate(root.editingText)
    signal committed(real value)
    signal textCommitted(string text)

    // SettingsRow places trailing controls in a plain Item rather than a
    // Layout, so Layout.preferredWidth alone would leave this editor at its
    // default zero width. Keep both hints for use in either context.
    implicitWidth: 150
    Layout.preferredWidth: 150
    spacing: 4

    function formatValue(value) { return root.integer ? Math.round(value).toString() : Number(value).toString(); }
    function validate(text) {
        const trimmed = String(text).trim();
        if (trimmed === "") return root.allowEmpty;
        if (trimmed === "-" || trimmed === "." || trimmed === "-.") return false;
        if (!/^[-+]?\d+(\.\d+)?$/.test(trimmed)) return false;
        const number = Number(trimmed);
        return Number.isFinite(number) && number >= root.minimum && number <= root.maximum;
    }
    function commit() {
        if (!root.validate(root.editingText)) { root.invalidFlash.restart(); return false; }
        if (String(root.editingText).trim() === "") { root.textCommitted(""); return true; }
        const next = root.integer ? Math.round(Number(root.editingText)) : Number(root.editingText);
        root.editingText = root.formatValue(next);
        root.committed(next);
        root.textCommitted(root.editingText);
        return true;
    }
    function stepBy(delta) {
        const next = Math.max(root.minimum, Math.min(root.maximum, Number(root.value) + delta * root.step));
        root.editingText = root.formatValue(next);
        root.commit();
    }

    onValueChanged: if (!field.activeFocus) root.editingText = root.formatValue(root.value)

    MaterialTextField {
        id: field
        Layout.fillWidth: true
        text: root.editingText
        inputMethodHints: root.integer ? Qt.ImhDigitsOnly : Qt.ImhFormattedNumbersOnly
        Accessible.name: root.unit ? Translation.tr("Value") + " (" + root.unit + ")" : Translation.tr("Value")
        onTextChanged: if (text !== root.editingText) root.editingText = text
        onAccepted: root.commit()
        onEditingFinished: root.commit()
        color: root.inputValid ? Appearance.m3colors.m3onSurface : Appearance.colors.colError
        onActiveFocusChanged: if (!activeFocus) root.commit()
    }
    StyledText { visible: root.unit.length > 0; text: root.unit; color: Appearance.colors.colOnSurfaceVariant }
    ToolButton { display: AbstractButton.IconOnly; Accessible.name: Translation.tr("Decrease"); onClicked: root.stepBy(-1); contentItem: MaterialSymbol { text: "remove"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface } }
    ToolButton { display: AbstractButton.IconOnly; Accessible.name: Translation.tr("Increase"); onClicked: root.stepBy(1); contentItem: MaterialSymbol { text: "add"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface } }

    SequentialAnimation {
        id: invalidFlash
        NumberAnimation {
            target: field
            property: "opacity"
            to: 0.55
            duration: 80
        }
        NumberAnimation {
            target: field
            property: "opacity"
            to: 1
            duration: 180
        }
    }
}
