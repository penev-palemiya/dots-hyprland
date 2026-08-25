import QtQuick
import qs.services
import qs.modules.common

SearchablePicker {
    id: root

    property var entities: []
    property string currentId: ""
    property string placeholder: Translation.tr("Select device")
    property string searchPlaceholder: Translation.tr("Search devices")
    signal selected(var entity)
    signal canceled()

    sourceItems: root.entities
    currentValue: root.currentId
    currentText: {
        const entity = root.entities.find(item => root.idOf(item) === root.currentId);
        return entity ? root.nameOf(entity) : "";
    }
    emptyText: Translation.tr("No devices available.")
    noResultsText: Translation.tr("No matching devices.")
    itemValue: root.idOf
    primaryText: root.nameOf
    secondaryText: root.secondaryOf
    iconText: entity => String(entity && (entity.icon || ""))
    sortItems: values => values.sort((a, b) => {
        const ac = root.idOf(a) === root.currentId;
        const bc = root.idOf(b) === root.currentId;
        if (ac !== bc)
            return ac ? -1 : 1;
        return root.nameOf(a).localeCompare(root.nameOf(b));
    })
    onPicked: item => root.selected(item)

    function idOf(entity) { return String(entity && entity.id !== undefined ? entity.id : ""); }
    function nameOf(entity) { return String(entity && (entity.name || entity.label || entity.id || "")); }
    function secondaryOf(entity) { return String(entity && (entity.secondary || entity.status || "")); }
}
