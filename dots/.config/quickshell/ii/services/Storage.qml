pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Small normalized UDisks2 model for Settings.  UDisks2 owns topology and
 * mount state; stat(1) is used only for one-shot filesystem usage snapshots.
 */
Singleton {
    id: root

    readonly property string service: "org.freedesktop.UDisks2"
    readonly property string managerPath: "/org/freedesktop/UDisks2"
    readonly property string objectManager: "org.freedesktop.DBus.ObjectManager"
    readonly property string blockInterface: "org.freedesktop.UDisks2.Block"
    readonly property string filesystemInterface: "org.freedesktop.UDisks2.Filesystem"
    readonly property string driveInterface: "org.freedesktop.UDisks2.Drive"

    property bool ready: false
    property bool busy: false
    property string error: ""
    property list<var> drives: []
    property list<var> volumes: []
    property real overviewTotal: 0
    property real overviewUsed: 0
    property real overviewAvailable: 0
    readonly property real overviewPercent: overviewTotal > 0 ? overviewUsed / overviewTotal * 100 : 0

    signal operationFailed(string reason)

    function value(object, key, fallback) {
        const item = object?.[key];
        return item && Object.prototype.hasOwnProperty.call(item, "data") ? item.data : (item ?? fallback);
    }

    function bytes(value) {
        if (Array.isArray(value))
            return String.fromCharCode(...value.filter(byte => byte !== 0));
        return String(value ?? "");
    }

    function mountPoints(value) {
        return (value ?? []).map(point => bytes(point)).filter(point => point.length > 0);
    }

    function refresh() {
        snapshotProc.running = true;
    }

    function fail(reason) {
        root.error = reason || Translation.tr("Storage operation failed.");
        root.busy = false;
        root.operationFailed(root.error);
    }

    function humanSize(value) {
        const size = Number(value || 0);
        if (size < 1024) return `${size} B`;
        const units = ["KiB", "MiB", "GiB", "TiB"];
        let amount = size;
        let index = -1;
        while (amount >= 1024 && index < units.length - 1) {
            amount /= 1024;
            index++;
        }
        return `${amount >= 10 ? amount.toFixed(0) : amount.toFixed(1)} ${units[index]}`;
    }

    function driveForPath(path) {
        return root.drives.find(drive => drive.path === path);
    }

    function isTechnicalVolume(volume) {
        if (!volume) return true;
        const mount = volume.mountPoints[0] || "";
        return mount === "/boot/efi" || mount === "/boot" ||
            (volume.size > 0 && volume.size < 2 * 1024 * 1024 * 1024 && !mount);
    }

    function applySnapshot(parsed) {
        const rawObjects = parsed?.data ?? parsed;
        const objects = Array.isArray(rawObjects) && rawObjects.length === 1 ? rawObjects[0] : rawObjects;
        if (!objects || typeof objects !== "object") {
            fail(Translation.tr("Could not read storage devices."));
            return;
        }

        const drivesByPath = {};
        const blocks = [];
        for (const path of Object.keys(objects)) {
            const interfaces = objects[path] || {};
            const drive = interfaces[root.driveInterface];
            if (drive) {
                drivesByPath[path] = {
                    id: path,
                    path,
                    model: root.value(drive, "Model", ""),
                    vendor: root.value(drive, "Vendor", ""),
                    serial: root.value(drive, "Serial", ""),
                    size: Number(root.value(drive, "Size", 0)),
                    removable: Boolean(root.value(drive, "Removable", false) || root.value(drive, "MediaRemovable", false)),
                    ejectable: Boolean(root.value(drive, "Ejectable", false)),
                    canPowerOff: Boolean(root.value(drive, "CanPowerOff", false)),
                    volumes: []
                };
            }
            if (interfaces[root.blockInterface])
                blocks.push({ path, interfaces });
        }

        const nextVolumes = [];
        for (const block of blocks) {
            const data = block.interfaces[root.blockInterface];
            const filesystem = block.interfaces[root.filesystemInterface] || {};
            const blockDrivePath = root.value(data, "Drive", "/");
            const blockDrive = drivesByPath[blockDrivePath];
            if (blockDrive)
                blockDrive.size = Math.max(blockDrive.size, Number(root.value(data, "Size", 0)));
            const idUsage = root.value(data, "IdUsage", "");
            const idType = root.value(data, "IdType", "");
            if (idUsage !== "filesystem" || !idType || idType === "swap") continue;

            const device = root.bytes(root.value(data, "Device", []));
            const points = root.mountPoints(root.value(filesystem, "MountPoints", []));
            const drivePath = blockDrivePath;
            const drive = drivesByPath[drivePath];
            const volume = {
                id: block.path,
                path: block.path,
                device,
                label: root.value(data, "IdLabel", ""),
                uuid: root.value(data, "IdUUID", ""),
                filesystem: idType,
                size: Number(root.value(filesystem, "Size", root.value(data, "Size", 0))),
                mounted: points.length > 0,
                mountPoints: points,
                used: 0,
                available: 0,
                system: points.includes("/") || points.includes("/boot") || points.includes("/boot/efi"),
                technical: false,
                removable: Boolean(drive?.removable),
                ejectable: Boolean(drive?.ejectable),
                canPowerOff: Boolean(drive?.canPowerOff),
                drivePath,
                usagePath: points[0] || ""
            };
            volume.technical = root.isTechnicalVolume(volume);
            nextVolumes.push(volume);
            if (drive) drive.volumes.push(volume);
        }

        root.drives = Object.values(drivesByPath).filter(drive => drive.volumes.length > 0 || drive.removable);
        root.volumes = nextVolumes;
        root.ready = true;
        root.error = "";
        root.refreshUsage();
    }

    function refreshUsage() {
        const mounted = root.volumes.filter(volume => volume.mounted && volume.usagePath && !volume.technical);
        if (mounted.length === 0) {
            root.overviewTotal = 0;
            root.overviewUsed = 0;
            root.overviewAvailable = 0;
            return;
        }
        usageProc.command = ["stat", "-f", "-c", "%S:%b:%f:%a", ...mounted.map(volume => volume.usagePath)];
        usageProc.running = true;
    }

    function applyUsage(text) {
        const mounted = root.volumes.filter(volume => volume.mounted && volume.usagePath && !volume.technical);
        const lines = String(text || "").trim().split("\n").filter(line => line.length > 0);
        const seen = {};
        let total = 0;
        let used = 0;
        let available = 0;
        mounted.forEach((volume, index) => {
            const fields = (lines[index] || "").split(":").map(Number);
            const blockSize = fields[0] || 0;
            const blocks = fields[1] || 0;
            const free = fields[2] || 0;
            const availableBlocks = fields[3] || 0;
            volume.used = Math.max(0, (blocks - free) * blockSize);
            volume.available = Math.max(0, availableBlocks * blockSize);
            const identity = volume.uuid || volume.device;
            if (!seen[identity]) {
                seen[identity] = true;
                total += blocks * blockSize;
                used += volume.used;
                available += volume.available;
            }
        });
        root.overviewTotal = total;
        root.overviewUsed = used;
        root.overviewAvailable = available;
        root.volumes = [...root.volumes];
    }

    function runOperation(volume, method) {
        if (!volume || root.busy) return false;
        if ((method === "Unmount") && volume.system) {
            root.fail(Translation.tr("The running system volume cannot be unmounted."));
            return false;
        }
        root.busy = true;
        root.error = "";
        operationProc.command = ["busctl", "--system", "call", root.service, volume.path,
            root.filesystemInterface, method, "a{sv}", "0"];
        if (method === "Eject" || method === "PowerOff") {
            operationProc.command = ["busctl", "--system", "call", root.service,
                driveForPath(volume.drivePath)?.path || volume.drivePath,
                root.driveInterface, method, "a{sv}", "0"];
        }
        operationProc.running = true;
        return true;
    }

    function mount(volume) { return runOperation(volume, "Mount"); }
    function unmount(volume) { return runOperation(volume, "Unmount"); }
    function eject(volume) { return runOperation(volume, "Eject"); }
    function powerOff(volume) { return runOperation(volume, "PowerOff"); }

    Process {
        id: snapshotProc
        command: ["busctl", "--system", "--json=short", "call", root.service, root.managerPath,
            root.objectManager, "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.applySnapshot(JSON.parse(text)); }
                catch (exception) { root.fail(Translation.tr("Could not parse storage devices.")); }
            }
        }
        stderr: StdioCollector { onStreamFinished: {} }
        onExited: code => { if (code !== 0) root.fail(Translation.tr("Storage service is unavailable.")); }
    }

    Process {
        id: usageProc
        stdout: StdioCollector { onStreamFinished: root.applyUsage(text) }
        stderr: StdioCollector { onStreamFinished: {} }
        onExited: code => { if (code !== 0) root.fail(Translation.tr("Could not read filesystem usage.")); }
    }

    Process {
        id: operationProc
        stdout: StdioCollector { onStreamFinished: {} }
        stderr: StdioCollector { onStreamFinished: operationProc.errorOutput = text }
        property string errorOutput: ""
        onRunningChanged: if (running) errorOutput = ""
        onExited: code => {
            root.busy = false;
            if (code !== 0) {
                root.fail(operationProc.errorOutput.trim() || Translation.tr("Storage operation failed."));
                return;
            }
            root.refresh();
        }
    }

    // One persistent signal subscription, not a polling loop.
    Process {
        id: signalMonitor
        command: ["gdbus", "monitor", "--system", "--dest", root.service]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("InterfacesAdded") || line.includes("InterfacesRemoved") || line.includes("PropertiesChanged"))
                    root.refresh();
            }
        }
        stderr: SplitParser { onRead: line => {} }
        running: true
    }

    Component.onCompleted: root.refresh()
}
