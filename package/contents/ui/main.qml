// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    function describe(usage) {
        return isFinite(usage)
            ? i18nc("a percentage", "%1%", usage.toLocaleString(Qt.locale(), "f", 1))
            : i18nc("there is no reading for this value", "unavailable");
    }

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.ShadowBackground

    // The readings carry no label in the panel: the tooltip names them.
    toolTipSubText: {
        const lines = [];
        if (cfg.showCpu) {
            lines.push(i18n("CPU: %1", describe(sensors.cpuUsage)));
        }
        if (cfg.showGpu) {
            lines.push(i18n("GPU: %1", describe(sensors.gpuUsage)));
        }
        if (cfg.showRam) {
            lines.push(i18n("Memory: %1", describe(sensors.ramUsage)));
        }
        return lines.join("\n");
    }

    compactRepresentation: CompactRepresentation {
        cfg: root.cfg
        metrics: sensors
        formFactor: Plasmoid.formFactor
    }
    fullRepresentation: Item {}

    Metrics {
        id: sensors
        updateRateLimit: root.cfg.updateRateLimit
        // A sensor is watched when its reading is shown or moves the cat.
        cpuEnabled: root.cfg.showCpu || root.cfg.catSource === 0
        gpuEnabled: root.cfg.showGpu || root.cfg.catSource === 1
        ramEnabled: root.cfg.showRam || root.cfg.catSource === 2
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18ndc("plasma_applet_org.kde.plasma.systemmonitor",
                         "@action", "Open System Monitor…")
            icon.name: "utilities-system-monitor"
            priority: Plasmoid.LowPriorityAction
            onTriggered: executable.exec("plasma-systemmonitor")
        }
    ]

    P5Support.DataSource {
        id: executable

        function exec(cmd) {
            connectSource(cmd);
        }

        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
    }
}
