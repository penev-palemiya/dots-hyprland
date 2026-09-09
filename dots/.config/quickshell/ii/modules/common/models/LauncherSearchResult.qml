import QtQuick
import Quickshell

QtObject {
    enum IconType { Material, Text, System, None }
    enum FontType { Normal, Monospace }

    // General stuff
    property string type: ""
    property var fontType: LauncherSearchResult.FontType.Normal
    property string name: ""
    property string rawValue: ""
    property string iconName: ""
    property var iconType: LauncherSearchResult.IconType.None
    property string verb: ""
    property bool blurImage: false
    property var execute: () => {
        print("Not implemented");
    }
    property var actions: []
    
    // Stuff needed for DesktopEntry 
    property string id: ""
    property bool shown: true
    property string comment: ""
    property bool runInTerminal: false
    property string genericName: ""
    property list<string> keywords: []

    // Extra stuff to allow for more flexibility
    property string category: type

    // Stable identity for ScriptModel's diffing (`objectProp: "key"`).
    // Without a real property here that reconciliation silently degrades into
    // "every entry is new", tearing down and rebuilding every delegate on each
    // keystroke instead of reusing the rows that didn't change. `id` alone is
    // not enough: only app results carry one, so everything else would collide
    // on the empty string. Type + name is unique within a single result list.
    readonly property string key: `${type}\u0000${id !== "" ? id : name}`
}
