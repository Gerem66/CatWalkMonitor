// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

/**
 * The cat. It sleeps below `idleThreshold`, walks up to `walkThreshold` and
 * runs from there on, the faster the higher `usage` is.
 *
 * Every pose of both gaits is precomputed in one sprite sheet (see
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
    /** The cat walks while the load is under this value; 0 makes it always run. */
    property real walkThreshold: 30
    /** Frames rendered per second while the cat moves. */
    property int frameRate: 30
    property color color: "white"
    property bool animated: true

    // `>=` is false for NaN, so an unknown load puts the cat to sleep.
    readonly property bool idle: !(usage >= idleThreshold)
    /** Whether the cat runs rather than walks; see chooseGait(). */
    property bool running: false
    // 0 while walking, 1 while running, in between during a change of gait.
    property real gait: running ? 1 : 0

    // Layout of the sprite sheet; keep in sync with tools/generate_sprites.py.
    readonly property int columns: 10
    readonly property int rows: 9
    readonly property int posesPerKeyframe: 12
    readonly property int runPoses: 60
    readonly property int walkPoses: 25
    readonly property int firstWalkPose: 60
    readonly property int idlePose: 85
    // Both cycles are back at their start together every so many poses.
    readonly property int period: 300

    /** Place in the cycles, in poses. Both gaits are read from it. */
    property real position: 0
    readonly property int runPose: Math.floor(position) % runPoses
    readonly property int walkPose: firstWalkPose + Math.floor(position) % walkPoses

    // Poses per second. The pace is the one of the original widget, which
    // showed a new keyframe every 5000 / sqrt(usage + 35) - 400 ms. The
    // poses of the walk are two footfalls, which take about as long as two
    // keyframes of the run.
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

    /**
     * Start running at the threshold, but only go back to walking once the
     * load is clearly under it. A load wavering around the threshold would
     * otherwise change the gait at each reading.
     */
    function chooseGait() {
        if (usage >= walkThreshold) {
            running = true;
        } else if (usage < walkThreshold * 0.8) {
            running = false;
        }
    }

    onUsageChanged: chooseGait()
    onWalkThresholdChanged: chooseGait()
    Component.onCompleted: chooseGait()

    Behavior on gait {
        NumberAnimation { duration: 250 }
    }

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
        // On a change of gait the new one first fades in over the old one,
        // then the old one fades out: the cat stays opaque all along.
        Pose {
            index: cat.walkPose
            visible: !cat.idle && cat.gait < 1
            opacity: Math.min(1, 2 - 2 * cat.gait)
        }
        Pose {
            index: cat.runPose
            visible: !cat.idle && cat.gait > 0
            opacity: Math.min(1, 2 * cat.gait)
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
            cat.position = (cat.position + cat.speed * elapsed) % cat.period;
        }
    }
}
