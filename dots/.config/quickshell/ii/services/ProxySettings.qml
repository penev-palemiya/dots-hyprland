pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import qs.modules.common.functions

/** Canonical desktop/session proxy policy backed by GSettings/libproxy. */
Singleton {
    id: root

    readonly property string rootSchema: "org.gnome.system.proxy"
    readonly property string httpSchema: "org.gnome.system.proxy.http"
    readonly property string httpsSchema: "org.gnome.system.proxy.https"
    readonly property string socksSchema: "org.gnome.system.proxy.socks"
    readonly property string environmentPath: `${FileUtils.trimFileProtocol(Directories.home)}/.config/environment.d/90-ii-proxy.conf`

    property string mode: "none"
    property string pacUrl: ""
    property var ignoreHosts: []
    property string httpHost: ""
    property int httpPort: 8080
    property string httpsHost: ""
    property int httpsPort: 0
    property string socksHost: ""
    property int socksPort: 0
    property bool ready: false
    property bool applying: false
    property string error: ""
    property string externalChange: ""

    readonly property bool manual: root.mode === "manual"
    readonly property bool automatic: root.mode === "auto"
    readonly property var policy: ({
        mode: root.mode,
        pacUrl: root.pacUrl,
        ignoreHosts: [...root.ignoreHosts],
        httpHost: root.httpHost,
        httpPort: root.httpPort,
        httpsHost: root.httpsHost,
        httpsPort: root.httpsPort,
        socksHost: root.socksHost,
        socksPort: root.socksPort
    })

    readonly property var schemas: [root.rootSchema, root.httpSchema, root.httpsSchema, root.socksSchema]
    property int readIndex: 0
    property var readValues: ({})
    property var pendingPolicy: null
    property int applyIndex: 0
    property string previousPolicyJson: ""
    property bool restoring: false

    signal policyChangedExternally()

    function parseValue(value) {
        const text = String(value ?? "").trim();
        if (text === "true" || text === "false") return text === "true";
        if (/^\d+$/.test(text)) return Number(text);
        if (text.startsWith("'") && text.endsWith("'")) return text.slice(1, -1).replace(/''/g, "'");
        if (text.startsWith("[") && text.endsWith("]")) {
            const values = [];
            const expression = /'((?:[^']|'')*)'/g;
            let match;
            while ((match = expression.exec(text)) !== null)
                values.push(match[1].replace(/''/g, "'"));
            return values;
        }
        return text;
    }

    function parseSchema(text) {
        const values = {};
        for (const line of String(text || "").split("\n")) {
            const match = line.match(/^\S+\s+\S+\s+(\S+)\s+(.*)$/);
            if (match) values[match[1]] = root.parseValue(match[2]);
        }
        return values;
    }

    function read() {
        if (readProc.running) return;
        root.readIndex = 0;
        root.readValues = {};
        readProc.command = ["gsettings", "list-recursively", root.schemas[root.readIndex]];
        readProc.running = true;
    }

    function applyReadValues() {
        const values = root.readValues;
        root.mode = values.mode || "none";
        root.pacUrl = values["autoconfig-url"] || "";
        root.ignoreHosts = Array.isArray(values["ignore-hosts"]) ? values["ignore-hosts"] : [];
        root.httpHost = values.httpHost ?? "";
        root.httpPort = Number(values.httpPort || 0);
        root.httpsHost = values.httpsHost ?? "";
        root.httpsPort = Number(values.httpsPort || 0);
        root.socksHost = values.socksHost ?? "";
        root.socksPort = Number(values.socksPort || 0);
        root.ready = true;
        root.policyChangedExternally();
    }

    function validHost(host) {
        const value = String(host || "").trim();
        return value.length > 0 && /^[A-Za-z0-9_.:\[\]-]+$/.test(value) && !value.includes(":::");
    }

    function validPort(port) { return Number.isInteger(Number(port)) && Number(port) >= 1 && Number(port) <= 65535; }

    function normalizeBypass(value) {
        return String(value || "").split(",").map(item => item.trim()).filter(item => item.length > 0 && !/[\n'="\r]/.test(item));
    }

    function validate(candidate) {
        if (!["none", "auto", "manual"].includes(candidate.mode)) return "Choose a valid proxy mode.";
        if (candidate.mode === "auto") {
            if (!/^https?:\/\/[^\s:@]+(?:\/[^\s]*)?$/i.test(candidate.pacUrl || ""))
                return "Enter an HTTP or HTTPS PAC URL without credentials.";
        }
        if (candidate.mode !== "manual") return "";
        for (const pair of [[candidate.httpHost, candidate.httpPort], [candidate.httpsHost, candidate.httpsPort], [candidate.socksHost, candidate.socksPort]]) {
            if (!pair[0] && Number(pair[1]) > 0) return "A proxy host is required when a port is set.";
            if (pair[0] && (!root.validHost(pair[0]) || !root.validPort(pair[1]))) return "Enter a valid proxy host and port.";
        }
        if (candidate.httpHost && candidate.httpsHost && candidate.httpHost === candidate.httpsHost && Number(candidate.httpPort) === Number(candidate.httpsPort)) {
            // This is common and valid; keep both explicit fields.
        }
        return "";
    }

    function gsettingsString(value) {
        return `'${String(value || "").replace(/'/g, "''")}'`;
    }

    function gsettingsArray(values) {
        return `[${values.map(value => gsettingsString(value)).join(", ")}]`;
    }

    function projection(policy) {
        if (policy.mode !== "manual") return "";
        const lines = [];
        const add = (key, value) => { if (value) lines.push(`${key}=${value}`); };
        const endpointHost = host => host.includes(":") && !host.startsWith("[") ? `[${host}]` : host;
        if (policy.httpHost) {
            const endpoint = `http://${endpointHost(policy.httpHost)}:${Number(policy.httpPort)}`;
            add("http_proxy", endpoint); add("HTTP_PROXY", endpoint);
        }
        if (policy.httpsHost) {
            const endpoint = `http://${endpointHost(policy.httpsHost)}:${Number(policy.httpsPort)}`;
            add("https_proxy", endpoint); add("HTTPS_PROXY", endpoint);
        }
        if (policy.socksHost) {
            const endpoint = `socks5://${endpointHost(policy.socksHost)}:${Number(policy.socksPort)}`;
            add("all_proxy", endpoint); add("ALL_PROXY", endpoint);
        }
        if (policy.ignoreHosts.length > 0) {
            const bypass = policy.ignoreHosts.join(",");
            add("no_proxy", bypass); add("NO_PROXY", bypass);
        }
        return lines.join("\n");
    }

    function apply(candidate) {
        const normalized = Object.assign({}, candidate, { ignoreHosts: root.normalizeBypass(candidate.ignoreHosts) });
        const validation = root.validate(normalized);
        if (validation) { root.error = validation; return false; }
        root.error = "";
        root.previousPolicyJson = JSON.stringify(root.policy);
        root.restoring = false;
        root.pendingPolicy = normalized;
        root.applyIndex = 0;
        root.applying = true;
        applyProc.command = root.applyCommands()[0];
        applyProc.running = true;
        return true;
    }

    function applyCommands() {
        const p = root.pendingPolicy;
        const manual = p.mode === "manual";
        return [
            ["gsettings", "set", root.rootSchema, "mode", root.gsettingsString(p.mode)],
            ["gsettings", "set", root.rootSchema, "autoconfig-url", root.gsettingsString(p.mode === "auto" ? p.pacUrl : "")],
            ["gsettings", "set", root.rootSchema, "ignore-hosts", root.gsettingsArray(p.ignoreHosts)],
            ["gsettings", "set", root.httpSchema, "enabled", manual && Boolean(p.httpHost) ? "true" : "false"],
            ["gsettings", "set", root.httpSchema, "host", root.gsettingsString(manual ? p.httpHost : "")],
            ["gsettings", "set", root.httpSchema, "port", String(manual && p.httpHost ? p.httpPort : 8080)],
            ["gsettings", "set", root.httpsSchema, "host", root.gsettingsString(manual ? p.httpsHost : "")],
            ["gsettings", "set", root.httpsSchema, "port", String(manual && p.httpsHost ? p.httpsPort : 0)],
            ["gsettings", "set", root.socksSchema, "host", root.gsettingsString(manual ? p.socksHost : "")],
            ["gsettings", "set", root.socksSchema, "port", String(manual && p.socksHost ? p.socksPort : 0)]
        ];
    }

    function finishApply() {
        root.applying = false;
        root.pendingPolicy = null;
        root.restoring = false;
        root.read();
    }

    function restorePrevious(reason) {
        let previous;
        try { previous = JSON.parse(root.previousPolicyJson); } catch (exception) { root.error = reason; root.finishApply(); return; }
        root.error = reason;
        root.pendingPolicy = previous;
        root.restoring = true;
        root.applyIndex = 0;
        applyProc.command = root.applyCommands()[0];
        applyProc.running = true;
    }

    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: root.readValues = Object.assign(root.readValues, root.parseSchema(text))
        }
        onExited: code => {
            if (code !== 0) { root.error = "Could not read desktop proxy settings."; root.ready = true; return; }
            root.readIndex++;
            if (root.readIndex < root.schemas.length) {
                readProc.command = ["gsettings", "list-recursively", root.schemas[root.readIndex]];
                readProc.running = true;
            } else root.applyReadValues();
        }
    }

    Process {
        id: applyProc
        onExited: code => {
            if (code !== 0) {
                if (!root.restoring)
                    root.restorePrevious("Proxy settings could not be applied; previous settings restored.");
                else
                    root.finishApply();
                return;
            }
            root.applyIndex++;
            const commands = root.applyCommands();
            if (root.applyIndex < commands.length) {
                applyProc.command = commands[root.applyIndex];
                applyProc.running = true;
            } else {
                const content = root.projection(root.pendingPolicy);
                projectionProc.environment = ({ PROXY_CONTENT: content, PROXY_PATH: root.environmentPath });
                projectionProc.running = true;
            }
        }
    }

    Process {
        id: projectionProc
        command: ["bash", "-c", "set -eu; path=\"$PROXY_PATH\"; mkdir -p \"$(dirname \"$path\")\"; if [ -n \"$PROXY_CONTENT\" ]; then tmp=$(mktemp \"$path.tmp.XXXXXX\"); printf '%s\\n' \"$PROXY_CONTENT\" > \"$tmp\"; chmod 600 \"$tmp\"; mv -f \"$tmp\" \"$path\"; else rm -f \"$path\"; fi; for key in http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY; do systemctl --user unset-environment \"$key\" || true; done; if [ -n \"$PROXY_CONTENT\" ]; then while IFS='=' read -r key value; do [ -n \"$key\" ] && systemctl --user set-environment \"$key=$value\" || true; done <<EOF\n$PROXY_CONTENT\nEOF\nfi; dbus-update-activation-environment --systemd >/dev/null 2>&1 || true" ]
        onExited: code => {
            if (code !== 0 && !root.restoring) {
                root.restorePrevious("Proxy environment projection failed; previous settings restored.");
                return;
            }
            if (code !== 0) root.error = "Proxy settings could not be restored completely.";
            root.finishApply();
        }
    }

    Timer { id: readDebounce; interval: 250; repeat: false; onTriggered: root.read() }
    function scheduleRead() { if (!root.applying) readDebounce.restart(); }

    Process {
        command: ["gsettings", "monitor", root.rootSchema]
        running: true
        stdout: SplitParser { onRead: root.scheduleRead() }
    }
    Process {
        command: ["gsettings", "monitor", root.httpSchema]
        running: true
        stdout: SplitParser { onRead: root.scheduleRead() }
    }
    Process {
        command: ["gsettings", "monitor", root.httpsSchema]
        running: true
        stdout: SplitParser { onRead: root.scheduleRead() }
    }
    Process {
        command: ["gsettings", "monitor", root.socksSchema]
        running: true
        stdout: SplitParser { onRead: root.scheduleRead() }
    }

    Component.onCompleted: root.read()
}
