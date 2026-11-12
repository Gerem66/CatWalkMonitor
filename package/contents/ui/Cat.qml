// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

/**
 * The cat. It runs faster as `usage` grows and sleeps below `idleThreshold`.
 *
 * Every pose of the run is precomputed in one sprite sheet (see
 * tools/generate_sprites.py), rasterized once at the size on screen. Showing
 * a frame is then only a matter of moving that texture: nothing is decoded
 * or drawn again while the cat moves, however slow or fast it goes. The
 * sheet is white and takes its color from Tinted.
 */
Item {
    id: cat

    /** Load driving the animation, in percent. */
    property real usage: 0
    /** The cat sleeps while the load is under this value. */
    property real idleThreshold: 5
    /** Frames rendered per second while the cat moves. */
    property int frameRate: 30
    property color color: "white"
    property bool animated: true

    // `>=` is false for NaN, so an unknown load puts the cat to sleep.
    readonly property bool idle: !(usage >= idleThreshold)

    // Layout of the sprite sheet; keep in sync with tools/generate_sprites.py.
    readonly property int columns: 10
    readonly property int rows: 7
    readonly property int posesPerKeyframe: 12
    readonly property int runPoses: 60
    readonly property int idlePose: 60

    /** Place in the run cycle, in poses. */
    property real position: 0
    readonly property int runPose: Math.floor(position) % runPoses

    // Poses per second. The pace is the one of the original widget, which
    // showed a new keyframe every 5000 / sqrt(usage + 35) - 400 ms.
    readonly property real targetSpeed: {
        const load = Math.max(0, Math.min(100, usage || 0));
        return posesPerKeyframe * 1000 / (5000 / Math.sqrt(load + 35) - 400);
    }
    property real speed: targetSpeed
    property double lastTick: 0

    // A cell of the sheet must cover a whole number of device pixels,
    // otherwise neighboring poses bleed into each other.
    readonly property real cellPixels: Math.max(1, Math.round(Math.min(width, height) * Screen.devicePixelRatio))
    readonly property real cell: cellPixels / Screen.devicePixelRatio

    implicitWidth: 22
    implicitHeight: 22

    // One pose of the sheet.
    component Pose: Image {
        required property int index

        x: -(index % cat.columns) * cat.cell
        y: -Math.floor(index / cat.columns) * cat.cell
        width: cat.columns * cat.cell
        height: cat.rows * cat.cell
        sourceSize: Qt.size(width, height)
        source: Qt.resolvedUrl("../images/cat.svg")
    }

    Tinted {
        anchors.centerIn: parent
        width: cat.cell
        height: cat.cell
        color: cat.color

        Pose {
            index: cat.idlePose
            visible: cat.idle
        }
        Pose {
            index: cat.runPose
            visible: !cat.idle
        }
    }

    Timer {
        interval: 1000 / Math.max(1, cat.frameRate)
        repeat: true
        running: cat.animated && cat.visible && !cat.idle
        onRunningChanged: {
            cat.lastTick = Date.now();
            cat.speed = cat.targetSpeed;
        }
        onTriggered: {
            // Advance by the time that really passed, so the pace does not
            // depend on the frame rate nor on a late timer.
            const now = Date.now();
            const elapsed = Math.min(now - cat.lastTick, 250) / 1000;
            cat.lastTick = now;
            // Ease into the new speed instead of jumping at each reading.
            cat.speed += (cat.targetSpeed - cat.speed) * Math.min(1, elapsed * 3);
            cat.position = (cat.position + cat.speed * elapsed) % cat.runPoses;
        }
    }
}
