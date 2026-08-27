pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var bar: null
  property string moduleName: "jcsmrx.codex-limits"
  property var settings: ({})

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string usagePath: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state")
    + "/omarchy/agents/usage/codex.json"
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : 26
  readonly property color foreground: bar ? bar.foreground : "white"
  readonly property color urgent: bar ? bar.urgent : "#ff6b6b"
  readonly property int refreshIntervalSec: Math.max(60, Number(setting("refreshIntervalSec", 300)))
  readonly property int warningThreshold: Math.max(0, Math.min(50, Number(setting("warningThreshold", 20))))

  property var windows: []
  property double nowMs: Date.now()

  implicitWidth: vertical || windows.length === 0 ? 0 : meters.implicitWidth + 10
  implicitHeight: barSize
  visible: !vertical && windows.length > 0

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value))
  }

  function windowDurationMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0)
      return 7 * 24 * 60 * 60 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 60 * 60 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function shortLabel(label) {
    var duration = windowDurationMs(label)
    if (duration >= 7 * 24 * 60 * 60 * 1000) return "7d"
    if (duration >= 60 * 60 * 1000) return Math.round(duration / 3600000) + "h"
    if (duration > 0) return Math.round(duration / 60000) + "m"
    return "—"
  }

  function resetAtMs(entry) {
    return new Date(String(entry.resetsAt || "")).getTime()
  }

  function remainingPercent(entry) {
    var reset = resetAtMs(entry)
    if (isFinite(reset) && reset <= nowMs) return 100
    return Math.round(clamp(1 - Number(entry.percent || 0), 0, 1) * 100)
  }

  function resetProgress(entry) {
    var reset = resetAtMs(entry)
    var duration = windowDurationMs(entry.label)
    if (!isFinite(reset) || duration <= 0) return 0
    return clamp((reset - nowMs) / duration, 0, 1)
  }

  function durationText(milliseconds) {
    if (!(milliseconds > 0)) return "agora"
    var minutes = Math.max(1, Math.ceil(milliseconds / 60000))
    var days = Math.floor(minutes / 1440)
    var hours = Math.floor((minutes % 1440) / 60)
    var mins = minutes % 60
    if (days > 0) return days + "d " + hours + "h"
    if (hours > 0) return hours + "h " + mins + "m"
    return mins + "m"
  }

  function tooltipText() {
    var lines = []
    for (var i = 0; i < windows.length; i++) {
      var entry = windows[i]
      var name = shortLabel(entry.label) === "7d" ? "Semana" : "Sessão"
      lines.push(name + ": " + remainingPercent(entry) + "% restante · reset em "
        + durationText(resetAtMs(entry) - nowMs))
    }
    lines.push("Clique para atualizar")
    return lines.join("\n")
  }

  function parseUsage(content) {
    try {
      var record = JSON.parse(String(content || ""))
      var limits = record && Array.isArray(record.limits) ? record.limits : []
      var valid = []
      for (var i = 0; i < limits.length; i++) {
        var entry = limits[i] || {}
        if (isFinite(Number(entry.percent)) && String(entry.resetsAt || "") !== "")
          valid.push(entry)
      }
      // Preserve the last good snapshot through a transient collector failure.
      if (valid.length > 0) windows = valid.slice(0, 2)
    } catch (error) {
      console.warn(root.moduleName, "Ignoring invalid usage record", error)
    }
  }

  function refresh() {
    if (!updateProcess.running) updateProcess.running = true
  }

  FileView {
    path: root.usagePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseUsage(text())
  }

  Process {
    id: updateProcess
    command: [root.home + "/.local/bin/omarchy-agent-usage-update", "--limits-only", "codex"]

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn(root.moduleName, text.trim())
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 60000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.nowMs = Date.now()
      for (var i = 0; i < root.windows.length; i++) {
        if (root.resetAtMs(root.windows[i]) <= root.nowMs) {
          root.refresh()
          break
        }
      }
    }
  }

  IpcHandler {
    target: root.moduleName
    function refresh(): void { root.refresh() }
  }

  Row {
    id: meters
    anchors.centerIn: parent
    spacing: 7

    Repeater {
      model: root.windows

      Item {
        id: meter
        required property var modelData
        width: 43
        height: root.implicitHeight

        Column {
          anchors.centerIn: parent
          width: parent.width
          spacing: 1

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.shortLabel(meter.modelData.label) + " "
              + root.remainingPercent(meter.modelData) + "%"
            color: root.remainingPercent(meter.modelData) <= root.warningThreshold
              ? root.urgent : root.foreground
            opacity: root.remainingPercent(meter.modelData) <= root.warningThreshold ? 1 : 0.88
            font.family: root.bar ? root.bar.fontFamily : "monospace"
            font.pixelSize: 9
            renderType: Text.NativeRendering
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 37
            height: 2
            radius: 1
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

            Rectangle {
              width: parent.width * root.resetProgress(meter.modelData)
              height: parent.height
              radius: parent.radius
              color: root.remainingPercent(meter.modelData) <= root.warningThreshold
                ? root.urgent : root.foreground
              opacity: 0.78

              Behavior on width {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
              }
            }
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: root.refresh()
  }
}
