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
    property bool cpuTemperatureEnabled: false
    property bool gpuTemperatureEnabled: false
    property bool ramTemperatureEnabled: false

    /** Usages, in percent. */
    readonly property real cpuUsage: reading(cpu)
    readonly property real gpuUsage: reading(gpu)
    readonly property real ramUsage: reading(ram)

    /** Temperatures, in degrees Celsius: the average over the cores, the cards, the modules. */
    readonly property real cpuTemperature: reading(cpuTemperatureSensor)
    readonly property real gpuTemperature: average(gpuTemperatureSensors)
    readonly property real ramTemperature: average(ramTemperatureSensors)

    // The system computes the average temperature of the CPU itself. Graphics
    // cards and memory modules have one sensor each, whose names depend on
    // the machine: those have to be looked for.
    readonly property var gpuTemperaturePattern: /^gpu\/gpu\d+\/temperature$/
    // Memory modules report their temperature through a JC42 chip (DDR3 and
    // DDR4) or an SPD5118 one (DDR5), when they have a sensor at all.
    readonly property var ramTemperaturePattern: /^lmsensors\/(jc42|spd5118)-[^\/]+\/temp1$/
    property var gpuTemperatureIds: []
    property var ramTemperatureIds: []

    function reading(sensor) {
        const value = sensor.value;
        return sensor.enabled && typeof value === "number" && isFinite(value) ? value : NaN;
    }

    /** Average of the sensors made by an Instantiator. */
    function average(sensors) {
        let sum = 0;
        let count = 0;
        for (let i = 0; i < sensors.count; ++i) {
            const value = sensors.objectAt(i)?.value;
            // A sensor that exists but measures nothing reports 0.
            if (typeof value === "number" && value > 0) {
                sum += value;
                ++count;
            }
        }
        return count > 0 ? sum / count : NaN;
    }

    function findTemperatureSensors() {
        const tree = finder.item;
        if (!tree) {
            return;
        }
        const gpus = [];
        const modules = [];
        const visit = parent => {
            for (let row = 0; row < tree.rowCount(parent); ++row) {
                const index = tree.index(row, 0, parent);
                const id = tree.data(index, Sensors.SensorTreeModel.SensorId);
                if (gpuTemperaturePattern.test(id)) {
                    gpus.push(id);
                } else if (ramTemperaturePattern.test(id)) {
                    modules.push(id);
                }
                visit(index);
            }
        };
        visit(tree.index(-1, -1));
        // Assigning an identical list would create the sensors again for nothing.
        if (gpus.join() !== gpuTemperatureIds.join()) {
            gpuTemperatureIds = gpus;
        }
        if (modules.join() !== ramTemperatureIds.join()) {
            ramTemperatureIds = modules;
        }
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
    Sensors.Sensor {
        id: cpuTemperatureSensor
        sensorId: "cpu/all/averageTemperature"
        enabled: metrics.cpuTemperatureEnabled
        updateRateLimit: metrics.updateRateLimit
    }
    Instantiator {
        id: gpuTemperatureSensors
        model: metrics.gpuTemperatureEnabled ? metrics.gpuTemperatureIds : []
        delegate: Sensors.Sensor {
            required property string modelData
            sensorId: modelData
            updateRateLimit: metrics.updateRateLimit
        }
    }
    Instantiator {
        id: ramTemperatureSensors
        model: metrics.ramTemperatureEnabled ? metrics.ramTemperatureIds : []
        delegate: Sensors.Sensor {
            required property string modelData
            sensorId: modelData
            updateRateLimit: metrics.updateRateLimit
        }
    }

    // The list of all the sensors of the machine is only loaded while there
    // is something to look for in it.
    Loader {
        id: finder
        active: metrics.gpuTemperatureEnabled || metrics.ramTemperatureEnabled
        sourceComponent: Sensors.SensorTreeModel {
            // The list fills in as the system answers.
            onRowsInserted: search.restart()
            onModelReset: search.restart()
        }
        onLoaded: search.restart()
    }
    Timer {
        id: search
        interval: 250
        onTriggered: metrics.findTemperatureSensors()
    }
}
