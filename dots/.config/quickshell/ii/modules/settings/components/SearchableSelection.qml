import QtQuick
import qs.services
import qs.modules.common

SearchablePicker {
    id: root

    property var options: []
    property var items: []
    signal selected(string value)

    sourceItems: root.items && root.items.length > 0
        ? root.items
        : root.options.map(value => ({ value: value, primaryText: value }))
    currentText: root.currentValue
    onPicked: item => root.selected(root.itemValue(item))
}
