import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings

/**
 * Replaces the page body while a search is active. Each hit says which page it
 * lives on, and selecting one navigates there and pulses the setting.
 */
StyledFlickable {
    id: root

    property real sidePadding: 24

    signal resultActivated(var entry)

    clip: true
    contentHeight: contentColumn.implicitHeight + 60

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
        spacing: 18

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            text: {
                const q = SettingsSearch.query.trim();
                const count = SettingsSearch.results.length;
                if (count === 0)
                    return Translation.tr("No results for \"%1\"").arg(q);
                if (count === 1)
                    return Translation.tr("1 result for \"%1\"").arg(q);
                return Translation.tr("%1 results for \"%2\"").arg(count).arg(q);
            }
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.huge
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.colors.colOnSurface
            wrapMode: Text.WordWrap
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            visible: SettingsSearch.results.length === 0
            text: Translation.tr("Try a different word, or browse the pages on the left.")
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        SettingsCard {
            id: resultsCard
            Layout.fillWidth: true
            visible: SettingsSearch.results.length > 0

            Repeater {
                model: SettingsSearch.results

                SettingsRow {
                    required property var modelData
                    required property int index

                    icon: modelData.icon
                    title: modelData.title
                    description: modelData.description
                    clickable: true
                    // These are views onto settings that are already indexed;
                    // registering them again would duplicate every hit.
                    registerInSearch: false
                    onClicked: root.resultActivated(modelData)

                    RowLayout {
                        spacing: 6

                        StyledText {
                            readonly property var context: SettingsSearch.resolveContext(modelData.target)
                            text: {
                                const location = context.subPageTitle.length > 0
                                    ? `${context.pageName} · ${context.subPageTitle}`
                                    : context.pageName;
                                return context.section.length > 0
                                    ? `${location} · ${context.section}` : location;
                            }
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }
            }
        }
    }
}
