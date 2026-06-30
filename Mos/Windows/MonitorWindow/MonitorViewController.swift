//
//  MonitorViewController.swift
//  Mos
//  滚动监控界面
//  Created by Caldis on 2017/1/10.
//  Copyright © 2017年 Caldis. All rights reserved.
//

import Cocoa

let scrollEventName = NSNotification.Name(rawValue: "ScrollEvent")
let buttonEventName = NSNotification.Name(rawValue: "ButtonEvent")

final class MonitorLineChartView: NSView {
    private struct Series {
        let title: String
        let color: NSColor
        var values: [Double] = []
    }

    private let maxSamples = 100
    private var series: [Series] = [
        Series(title: "Vertical", color: NSColor(calibratedRed: 96.0/255.0, green: 198.0/255.0, blue: 85.0/255.0, alpha: 1.0)),
        Series(title: "Horizontal", color: NSColor(calibratedRed: 246.0/255.0, green: 191.0/255.0, blue: 79.0/255.0, alpha: 1.0)),
        Series(title: "IsContinuous", color: NSColor(calibratedRed: 52.0/255.0, green: 152.0/255.0, blue: 219.0/255.0, alpha: 1.0)),
        Series(title: "ScrollCount", color: NSColor(calibratedRed: 155.0/255.0, green: 89.0/255.0, blue: 182.0/255.0, alpha: 1.0)),
        Series(title: "ScrollPhase", color: NSColor(calibratedRed: 230.0/255.0, green: 126.0/255.0, blue: 34.0/255.0, alpha: 1.0)),
        Series(title: "MomentumPhase", color: NSColor(calibratedRed: 231.0/255.0, green: 76.0/255.0, blue: 60.0/255.0, alpha: 1.0)),
    ]

    override var isFlipped: Bool { true }

    func reset() {
        for index in series.indices {
            series[index].values.removeAll()
        }
        needsDisplay = true
    }

    func append(_ values: [Double]) {
        for (index, value) in values.enumerated() where index < series.count {
            series[index].values.append(value)
            if series[index].values.count > maxSamples {
                series[index].values.removeFirst(series[index].values.count - maxSamples)
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let plotRect = bounds.insetBy(dx: 8, dy: 22)
        NSColor.secondaryLabelColor.setStroke()
        NSBezierPath(rect: plotRect).stroke()

        let visibleValues = series.flatMap { $0.values }
        guard !visibleValues.isEmpty else {
            drawLegend()
            return
        }

        let minValue = min(visibleValues.min() ?? 0, 0)
        let maxValue = max(visibleValues.max() ?? 0, 0)
        let span = max(maxValue - minValue, 1)
        let maxCount = max(series.map { $0.values.count }.max() ?? 1, 1)

        drawZeroLine(in: plotRect, minValue: minValue, span: span)
        for item in series {
            draw(values: item.values, color: item.color, in: plotRect, minValue: minValue, span: span, maxCount: maxCount)
        }
        drawLegend()
    }

    private func draw(values: [Double], color: NSColor, in rect: NSRect, minValue: Double, span: Double, maxCount: Int) {
        guard values.count > 1 else { return }
        let path = NSBezierPath()
        for (index, value) in values.enumerated() {
            let xRatio = CGFloat(index) / CGFloat(max(maxCount - 1, 1))
            let yRatio = CGFloat((value - minValue) / span)
            let point = NSPoint(x: rect.minX + xRatio * rect.width, y: rect.maxY - yRatio * rect.height)
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        color.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawZeroLine(in rect: NSRect, minValue: Double, span: Double) {
        let yRatio = CGFloat((0 - minValue) / span)
        let y = rect.maxY - yRatio * rect.height
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: y))
        path.line(to: NSPoint(x: rect.maxX, y: y))
        NSColor.tertiaryLabelColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawLegend() {
        var x: CGFloat = 8
        let y: CGFloat = 4
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.labelColor,
        ]

        for item in series {
            item.color.setFill()
            NSBezierPath(rect: NSRect(x: x, y: y + 4, width: 10, height: 2)).fill()
            x += 14
            let size = (item.title as NSString).size(withAttributes: attrs)
            (item.title as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            x += size.width + 10
        }
    }
}

class MonitorViewController: NSViewController {

    private enum PreviewRefresh {
        static let buttonLogInterval: TimeInterval = 0.1
    }
    
    // MARK: - UI: 图表
    @IBOutlet weak var lineChart: MonitorLineChartView!
    
    // MARK: - UI: Log 文本
    @IBOutlet var parsedLogTextField: NSTextView!
    @IBOutlet var scrollLogTextField: NSTextView!
    @IBOutlet var scrollDetailLogTextField: NSTextView!
    @IBOutlet var buttonEventLogTextField: NSTextView!
    @IBOutlet var processLogTextField: NSTextView!
    @IBOutlet var mouseLogTextField: NSTextView!

    // MARK: - UI: 事件触发器
    @IBOutlet weak var shortcutMenu: NSMenu!
    @IBOutlet weak var shortcutPopUpButton: NSPopUpButton!

    // MARK: - 生命周期
    override func viewWillAppear() {
        initCharts()
        initScrollObserver()
        initButtonObserver()
        setupShortcutMenu()
    }
    override func viewWillDisappear() {
        uninitScrollObserver()
        uninitButtonObserver()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 监听: 滚动
    var scrollEventInterceptor: Interceptor?
    let scrollEventMask = ScrollCore.shared.scrollEventMask
    let scrollEventCallBack: CGEventTapCallBack = { (proxy, type, event, refcon) in
        // 发送 ScrollWheelEventUpdate 通知
        NotificationCenter.default.post(name: scrollEventName, object: event)
        // 返回事件对象
        return Unmanaged.passUnretained(event)
    }
    // 更新面板
    var prevScrollWheelEventScrollPhase = 0.0
    var prevScrollWheelEventMomentumPhase = 0.0
    @objc private func updateScrollEventData(notification: NSNotification) {
        let event = notification.object as! CGEvent
        // 更新图表
        let isContinuous = Double(event.getIntegerValueField(.scrollWheelEventIsContinuous))
        let scrollPhase = Double(event.getIntegerValueField(.scrollWheelEventScrollPhase))
        let momentumPhase = Double(event.getIntegerValueField(.scrollWheelEventMomentumPhase))
        lineChart.append([
            event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1),
            event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2),
            isContinuous,
            Double(event.getIntegerValueField(.scrollWheelEventScrollCount)),
            scrollPhase,
            momentumPhase,
        ])

        // Logs
        if prevScrollWheelEventScrollPhase != scrollPhase || prevScrollWheelEventMomentumPhase != momentumPhase {
            if prevScrollWheelEventScrollPhase != scrollPhase {
                prevScrollWheelEventScrollPhase = scrollPhase
            }
            if prevScrollWheelEventMomentumPhase != momentumPhase {
                prevScrollWheelEventMomentumPhase = momentumPhase
            }
            NSLog("Phase updated -> prevScrollWheelEventScrollPhase: \(scrollPhase), prevScrollWheelEventMomentumPhase: \(momentumPhase)")
        }
        // 更新 Log
        parsedLogTextField.string = Logger.getParsedLog(form: event)
        scrollLogTextField.string = Logger.getScrollLog(form: event)
        scrollDetailLogTextField.string = Logger.getScrollDetailLog(form: event)
        processLogTextField.string = Logger.getProcessLog(form: event)
        mouseLogTextField.string = Logger.getMouseLog(form: event)
    }
    // 初始化监听
    func initScrollObserver() {
        // 监听内部事件
        NotificationCenter.default.addObserver(self, selector: #selector(updateScrollEventData), name: scrollEventName, object: nil)
        // 启动事件拦截
        do {
            scrollEventInterceptor = try Interceptor(
                event: scrollEventMask,
                handleBy: scrollEventCallBack,
                listenOn: .cgAnnotatedSessionEventTap,
                placeAt: .tailAppendEventTap,
                for: .listenOnly
            )
        } catch {
            NSLog("[MonitorView] Create scroll interceptor failure: \(error)")
        }
    }
    // 停止
    func uninitScrollObserver() {
        scrollEventInterceptor?.stop()
    }
    
    // MARK: - 监听: 按键
    var buttonEventInterceptor: Interceptor?
    var buttonEventMask: CGEventMask {
        let buttonDownEvents =
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
        let buttonUpEvents =
            CGEventMask(1 << CGEventType.leftMouseUp.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseUp.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
        let dragEvents =
            CGEventMask(1 << CGEventType.leftMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.rightMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
        let keyboardEvents =
            CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let moveEvents = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
        return buttonDownEvents | buttonUpEvents | dragEvents | keyboardEvents | moveEvents
    }
    let buttonEventCallBack: CGEventTapCallBack = { (proxy, type, event, refcon) in
        // 发送按钮事件通知
        NotificationCenter.default.post(name: buttonEventName, object: event)
        // 返回事件对象
        return Unmanaged.passUnretained(event)
    }
    // 按钮日志
    private let buttonEventLogStore = MonitorLogStore(previewLineLimit: 200)
    private var isButtonPreviewRefreshScheduled = false
    // 更新面板
    @objc private func updateButtonEventData(notification: NSNotification) {
        let event = notification.object as! CGEvent
        buttonEventLogStore.append(buttonEventLogLine(for: event), to: .buttonEvent)
        scheduleButtonPreviewRefresh()
    }

    func buttonEventLogLine(for event: CGEvent) -> String {
        let modifiers = event.modifierString.isEmpty ? "none" : event.modifierString
        let flagsHex = String(event.flags.rawValue, radix: 16)

        if event.isMouseInteractionEvent {
            let userData = event.getIntegerValueField(.eventSourceUserData)
            let deltaX = Int(event.getDoubleValueField(.mouseEventDeltaX))
            let deltaY = Int(event.getDoubleValueField(.mouseEventDeltaY))
            return "[\(event.timestampFormatted)] \(event.eventTypeName) button: \(event.mouseCode) delta:(\(deltaX),\(deltaY)) mods:[\(modifiers)] flags:0x\(flagsHex) userData: \(userData)"
        }

        if event.type == .flagsChanged {
            let phase = event.isKeyDown ? "down" : "up"
            return "[\(event.timestampFormatted)] \(event.eventTypeName) key: \(event.keyCodeName) phase: \(phase) mods:[\(modifiers)] flags:0x\(flagsHex)"
        }

        if event.isKeyboardEvent {
            return "[\(event.timestampFormatted)] \(event.eventTypeName) key: \(event.keyCodeName) keyCode: \(event.keyCode) mods:[\(modifiers)] flags:0x\(flagsHex)"
        }

        return "[\(event.timestampFormatted)] \(event.eventTypeName) \(event.displayName) flags:0x\(flagsHex)"
    }
    // 初始化
    func initButtonObserver() {
        // 监听内部事件
        NotificationCenter.default.addObserver(self, selector: #selector(updateButtonEventData), name: buttonEventName, object: nil)
        // 启动事件拦截
        do {
            buttonEventInterceptor = try Interceptor(
                event: buttonEventMask,
                handleBy: buttonEventCallBack,
                listenOn: .cgAnnotatedSessionEventTap,
                placeAt: .tailAppendEventTap,
                for: .listenOnly
            )
        } catch {
            NSLog("[MonitorView] Create button interceptor failure: \(error)")
        }
    }
    // 停止
    func uninitButtonObserver() {
        buttonEventInterceptor?.stop()
    }

    private func scheduleButtonPreviewRefresh() {
        guard !isButtonPreviewRefreshScheduled else { return }
        isButtonPreviewRefreshScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + PreviewRefresh.buttonLogInterval) { [weak self] in
            guard let self else { return }
            self.isButtonPreviewRefreshScheduled = false
            self.refreshButtonLogPreview()
        }
    }

    private func refreshButtonLogPreview() {
        guard let textView = buttonEventLogTextField else { return }
        textView.string = buttonEventLogStore.previewText(for: .buttonEvent)
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }

    @IBAction private func exportButtonEventLog(_ sender: Any) {
        guard let window = view.window else { return }

        let savePanel = NSSavePanel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        savePanel.nameFieldStringValue = "monitor-button-events-\(formatter.string(from: Date())).log"
        savePanel.allowedFileTypes = ["log", "txt"]

        savePanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = savePanel.url, let self else { return }
            let output = self.buttonEventLogStore.exportText(for: .buttonEvent)
            do {
                try output.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSLog("[MonitorView] Export button event log failure: \(error)")
            }
        }
    }

    // MARK: - 按键事件处理
    func setupShortcutMenu() {
        guard shortcutMenu != nil else {
            NSLog("[MonitorView] shortcutMenu 未连接，无法构建菜单")
            return
        }

        // 使用 ShortcutManager 构建分级菜单
        ShortcutManager.buildShortcutMenu(
            into: shortcutMenu,
            target: self,
            action: #selector(onShortcutMenuItemSelected(_:))
        )

        // 设置默认选择 placeholder
        shortcutPopUpButton?.selectItem(at: 0)
    }
    @objc func onShortcutMenuItemSelected(_ sender: NSMenuItem) {
        guard let shortcut = sender.representedObject as? SystemShortcut.Shortcut else {
            NSLog("[MonitorView] 无法获取快捷键信息")
            return
        }
        // 使用 ShortcutExecutor 触发快捷键
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ShortcutExecutor.shared.execute(shortcut)
        }
    }
    

    // MARK: - 图表管理
    // 初始化
    func initCharts() {
        lineChart.reset()
    }
    // 刷新内容
    @IBAction func refreshChart(_ sender: Any) {
        initCharts()
        // 清空按钮事件日志
        buttonEventLogStore.clear(.buttonEvent)
        isButtonPreviewRefreshScheduled = false
        buttonEventLogTextField?.string = ""
    }
}
