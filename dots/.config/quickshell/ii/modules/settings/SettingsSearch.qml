pragma Singleton

import Quickshell
import QtQuick

/**
 * Central search index for the settings app.
 *
 * Rows built with SettingsRow (and its subclasses) register themselves here on
 * creation, so the index is derived from what actually exists in the UI rather
 * than a hand-maintained parallel list that would drift out of date. This means
 * a setting becomes searchable the moment it's authored - nothing else to update.
 *
 * Because registration happens at row-creation time, every settings page must be
 * instantiated for the index to be complete (see the page host in settings.qml,
 * which keeps all pages alive and only toggles visibility).
 */
Singleton {
    id: root

    property var entries: []
    property string query: ""

    readonly property string normalizedQuery: root.query.trim().toLowerCase()
    readonly property bool searching: root.normalizedQuery.length > 0

    readonly property var results: {
        if (!root.searching)
            return [];
        const q = root.normalizedQuery;
        const scored = [];
        for (const entry of root.entries) {
            const score = root.scoreEntry(entry, q);
            if (score > 0)
                scored.push({ entry, score });
        }
        // Highest score first; stable-ish tiebreak by page then title so results
        // don't visibly reshuffle between keystrokes that score the same.
        scored.sort((a, b) => {
            if (b.score !== a.score) return b.score - a.score;
            if (a.entry.pageIndex !== b.entry.pageIndex) return a.entry.pageIndex - b.entry.pageIndex;
            return a.entry.title.localeCompare(b.entry.title);
        });
        return scored.map(s => s.entry);
    }

    // Title matches rank above keyword/description matches so typing an exact
    // setting name surfaces that setting rather than everything mentioning it.
    function scoreEntry(entry, q) {
        const title = (entry.title ?? "").toLowerCase();
        const description = (entry.description ?? "").toLowerCase();
        const keywords = (entry.keywords ?? "").toLowerCase();
        const section = (root.resolveContext(entry.target).section ?? "").toLowerCase();

        if (title === q) return 100;
        if (title.startsWith(q)) return 80;
        if (title.includes(q)) return 60;
        if (section.includes(q)) return 40;
        if (keywords.includes(q)) return 30;
        if (description.includes(q)) return 20;
        return 0;
    }

    // Walks up from a registered row to whatever page/group/detail page it
    // sits in. Done lazily because a top-level page only learns its own index
    // after its Loader has finished loading it.
    // Done lazily rather than at registration time because a page only learns
    // its own index after its Loader has finished loading it.
    function resolveContext(target) {
        const context = {
            "pageIndex": -1,
            "pageName": "",
            "section": "",
            "subPageKey": "",
            "subPageTitle": ""
        };
        let node = target;
        while (node) {
            if (context.section.length === 0 && node.settingsSectionTitle)
                context.section = node.settingsSectionTitle;
            if (context.subPageKey.length === 0 && node.settingsSubPageKey !== undefined) {
                context.subPageKey = node.settingsSubPageKey;
                context.subPageTitle = node.settingsSubPageTitle ?? "";
            }
            if (node.settingsPageIndex !== undefined && node.settingsPageIndex >= 0) {
                context.pageIndex = node.settingsPageIndex;
                context.pageName = node.settingsPageName ?? "";
                break;
            }
            node = node.parent;
        }
        return context;
    }

    function register(entry) {
        if (!entry || !entry.title || entry.title.length === 0)
            return;
        root.entries = [...root.entries, entry];
    }

    function unregister(target) {
        if (!target)
            return;
        const remaining = root.entries.filter(entry => entry.target !== target);
        // Only reassign when something actually went away. Handing back a new
        // array unconditionally would re-evaluate `results`, which recreates the
        // result delegates, which unregister on destruction - a binding loop.
        if (remaining.length === root.entries.length)
            return;
        root.entries = remaining;
    }

    function clearQuery() {
        root.query = "";
    }
}
