import QtQuick

QtObject {
    required property var lastIpcObject
    readonly property string ssid: lastIpcObject.ssid
    readonly property string bssid: lastIpcObject.bssid
    readonly property int strength: lastIpcObject.strength
    readonly property int frequency: lastIpcObject.frequency
    readonly property bool active: lastIpcObject.active
    readonly property string security: lastIpcObject.security
    readonly property bool isSecure: security.length > 0
    readonly property bool hidden: lastIpcObject.hidden ?? false
    readonly property string band: lastIpcObject.band ?? ""
    readonly property bool connected: lastIpcObject.connected ?? lastIpcObject.active ?? false
    readonly property string bestAccessPoint: lastIpcObject.bestAccessPoint ?? bssid
    readonly property list<var> accessPoints: lastIpcObject.accessPoints ?? []
    readonly property list<var> savedProfiles: lastIpcObject.savedProfiles ?? []

    property bool askingPassword: false
}
