// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.ksysguard.sensors as Sensors

/**
 * The readings of the widget.
 *
 * A reading is NaN as long as its sensor is disabled, has not reported
 * anything yet, or does not exist on this machine. Only the sensors that
 * are enabled are watched.
 */
Item {
    id: metrics

    /** Minimum time between two readings, in milliseconds. */
    property int updateRateLimit: 1000
    property bool cpuEnabled: true
    property bool gpuEnabled: false
    property bool ramEnabled: false

    /** Usages, in percent. */
    readonly property real cpuUsage: reading(cpu)
    readonly property real gpuUsage: reading(gpu)
    readonly property real ramUsage: reading(ram)

    function reading(sensor) {
        const value = sensor.value;
        return sensor.enabled && typeof value === "number" && isFinite(value) ? value : NaN;
    }

    visible: false

    Sensors.Sensor {
        id: cpu
        sensorId: "cpu/all/usage"
        enabled: metrics.cpuEnabled
        updateRateLimit: metrics.updateRateLimit
    }
    Sensors.Sensor {
        id: gpu
        sensorId: "gpu/all/usage"
        enabled: metrics.gpuEnabled
        updateRateLimit: metrics.updateRateLimit
    }
    Sensors.Sensor {
        id: ram
        sensorId: "memory/physical/usedPercent"
        enabled: metrics.ramEnabled
        updateRateLimit: metrics.updateRateLimit
    }
}
