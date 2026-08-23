import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Scrollable body of one sidebar page. Detail pages stay instantiated but are
 * toggled visible, rather than using StackView: search must index rows in every
 * detail page before the user has visited them.
 */
StyledFlickable {
    id: root

    property string pageTitle: ""
    property int settingsPageIndex: -1
    property string settingsPageName: root.pageTitle
    property real sidePadding: 24
    property real bottomPadding: 60
    // [{ key: "sound", title: "Sound", content: soundPageComponent }]
    property var subPages: []
    property string currentSubPageKey: ""

    default property alias pageContent: primaryContent.data

    readonly property var activeSubPage: {
        for (const subPage of root.subPages) {
            if (subPage.key === root.currentSubPageKey)
                return subPage;
        }
        return null;
    }
    readonly property bool showingSubPage: root.activeSubPage !== null
    readonly property string displayedTitle: root.showingSubPage
        ? root.activeSubPage.title : root.pageTitle

    clip: true
    contentHeight: contentColumn.implicitHeight + root.bottomPadding

    function openSubPage(key) {
        for (const subPage of root.subPages) {
            if (subPage.key === key) {
                root.currentSubPageKey = key;
                root.contentY = 0;
                return;
            }
        }
    }

    function popSubPage() {
        root.currentSubPageKey = "";
        root.contentY = 0;
    }

    function subPageKeyFor(row) {
        let node = row;
        while (node && node !== root) {
            if (node.settingsSubPageKey !== undefined)
                return node.settingsSubPageKey;
            node = node.parent;
        }
        return "";
    }

    // Brings a row registered in search into view. If it is in a detail page,
    // reveal that page first, then wait for its layout before calculating y.
    function revealRow(row) {
        if (!row)
            return;
        const subPageKey = root.subPageKeyFor(row);
        if (subPageKey.length > 0 && root.currentSubPageKey !== subPageKey) {
            root.openSubPage(subPageKey);
            Qt.callLater(() => root.revealRow(row));
            return;
        }
        const rowY = row.mapToItem(contentColumn, 0, 0).y;
        const target = Math.max(0, Math.min(rowY - height / 3, Math.max(0, contentHeight - height)));
        root.contentY = target;
        row.flashHighlight();
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 28
            leftMargin: root.sidePadding
            rightMargin: root.sidePadding
        }
        spacing: 28

        Item {
            id: titleHeader
            Layout.fillWidth: true
            Layout.bottomMargin: 4
            Layout.leftMargin: 4
            implicitHeight: titleRow.implicitHeight

            RowLayout {
                id: titleRow
                anchors.fill: parent
                spacing: 8

                MaterialSymbol {
                    visible: root.showingSubPage
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.displayedTitle
                    font {
                        family: Appearance.font.family.title
                        pixelSize: Appearance.font.pixelSize.huge
                        variableAxes: Appearance.font.variableAxes.title
                    }
                    color: Appearance.colors.colOnSurface
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.showingSubPage
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.popSubPage()
            }
        }

        ColumnLayout {
            id: primaryContent
            Layout.fillWidth: true
            visible: !root.showingSubPage
            spacing: 28
        }

        Repeater {
            model: root.subPages

            Loader {
                required property var modelData

                Layout.fillWidth: true
                visible: root.currentSubPageKey === modelData.key
                // Detail pages are intentionally lazy: expensive services
                // belong to the destination the user opened, not Settings
                // startup. Leaving the page destroys its page-local model.
                active: root.currentSubPageKey === modelData.key
                sourceComponent: modelData.content

                onLoaded: {
                    if (item) {
                        if (item.settingsSubPageKey !== undefined)
                            item.settingsSubPageKey = modelData.key;
                        if (item.settingsSubPageTitle !== undefined)
                            item.settingsSubPageTitle = modelData.title;
                        item.width = width;
                    }
                }
                onWidthChanged: {
                    if (item)
                        item.width = width;
                }
            }
        }
    }
}
