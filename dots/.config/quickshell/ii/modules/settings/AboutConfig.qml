import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property string currentSourceUrl: "https://github.com/penev-palemiya/dots-hyprland"
    readonly property string upstreamUrl: "https://github.com/end-4/dots-hyprland"
    readonly property string upstreamDocsUrl: "https://ii.clsty.link"
    readonly property string upstreamCommunityUrl: "https://discord.gg/GtdRBXgMwq"

    function open(url) {
        if (url.length > 0)
            Qt.openUrlExternally(url);
    }

    SettingsGroup {
        title: Translation.tr("Identity")

        SettingsRow {
            icon: "info"
            title: Translation.tr("Product name")
            description: Translation.tr("No current fork product name is defined.")
            registerInSearch: false
        }

        SettingsRow {
            icon: "code"
            title: Translation.tr("Build")
            description: Translation.tr("Development build")
            registerInSearch: false
        }
    }

    SettingsGroup {
        title: Translation.tr("Project")

        SettingsRow {
            icon: "code"
            title: Translation.tr("Source code")
            description: root.currentSourceUrl
            clickable: true
            onClicked: root.open(root.currentSourceUrl)
        }

        SettingsRow {
            icon: "account_tree"
            title: Translation.tr("Based on")
            description: Translation.tr("illogical-impulse / end-4 dots-hyprland")
            clickable: true
            onClicked: root.open(root.upstreamUrl)
            registerInSearch: false
        }
    }

    SettingsGroup {
        title: Translation.tr("Support")

        SettingsRow {
            icon: "auto_stories"
            title: Translation.tr("Upstream documentation")
            description: root.upstreamDocsUrl
            clickable: true
            onClicked: root.open(root.upstreamDocsUrl)
            registerInSearch: false
        }

        SettingsRow {
            icon: "forum"
            title: Translation.tr("Upstream community")
            description: Translation.tr("Discord community for the upstream project")
            clickable: true
            onClicked: root.open(root.upstreamCommunityUrl)
            registerInSearch: false
        }
    }

    SettingsGroup {
        title: Translation.tr("Credits / Legal")

        SettingsRow {
            icon: "policy"
            title: Translation.tr("License")
            description: Translation.tr("GNU GPL v3")
            registerInSearch: false
        }

        SettingsRow {
            icon: "groups"
            title: Translation.tr("Upstream attribution")
            description: Translation.tr("Based on the illogical-impulse project and its contributors.")
            registerInSearch: false
        }
    }
}
