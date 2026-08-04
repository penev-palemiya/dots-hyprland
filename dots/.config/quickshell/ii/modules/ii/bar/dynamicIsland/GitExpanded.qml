import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Expanded panel for the git activity: the project, its branch, and what's
 * uncommitted or unpushed.
 *
 * There is no "behind" count here on purpose. Knowing how many commits you're
 * behind requires a `git fetch`, and a status panel that silently hits the
 * network every time you glance at it is exactly the kind of background work
 * this shell has been getting rid of. What's shown is what can be known from
 * local refs alone, which is also what's actually true without asking a
 * server.
 */
ColumnLayout {
    id: root

    anchors.fill: parent
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: Translation.tr("Project")
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
                text: DevStatus.projectName
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            MaterialSymbol {
                fill: 0
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
                text: DevStatus.detachedHead ? "commit" : "account_tree"
            }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
                text: DevStatus.branch
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8
        columnSpacing: 8
        uniformCellWidths: true

        DevStatRow {
            symbol: "difference"
            title: Translation.tr("Uncommitted")
            value: DevStatus.changedFiles > 0 ? Translation.tr("%1 files").arg(DevStatus.changedFiles) : Translation.tr("Clean")
            warning: false
        }

        DevStatRow {
            symbol: "arrow_upward"
            title: Translation.tr("To push")
            // "no upstream" is a genuinely different answer from "nothing to
            // push", so it gets its own label rather than a misleading 0.
            value: !DevStatus.hasUpstream ? Translation.tr("No upstream") : DevStatus.ahead > 0 ? Translation.tr("%1 commits").arg(DevStatus.ahead) : Translation.tr("Up to date")
            warning: false
        }
    }

    component DevStatRow: Rectangle {
        id: statRow

        property string symbol: ""
        property string title: ""
        property string value: ""
        property bool warning: false

        Layout.fillWidth: true
        implicitHeight: statContent.implicitHeight + 16
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        RowLayout {
            id: statContent

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 8

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                fill: 0
                iconSize: Appearance.font.pixelSize.normal
                color: statRow.warning ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                text: statRow.symbol
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    text: statRow.title
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: statRow.warning ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                    text: statRow.value
                }
            }
        }
    }
}
