import Cocoa

enum DragGesturePhase: Equatable {
    case idle
    case pending
    case active
    case ignored
}

struct DragGestureClassifier {
    private(set) var phase: DragGesturePhase = .idle
    private var startCursorPosition: CGPoint?
    private var startWindowPosition: CGPoint?

    mutating func begin(cursor: CGPoint, windowFrame: CGRect, titleBarHeight: CGFloat) {
        guard phase == .idle else { return }

        let titleBarFrame = CGRect(
            x: windowFrame.minX,
            y: windowFrame.minY,
            width: windowFrame.width,
            height: min(titleBarHeight, windowFrame.height)
        )
        guard titleBarFrame.contains(cursor) else {
            phase = .ignored
            return
        }

        startCursorPosition = cursor
        startWindowPosition = windowFrame.origin
        phase = .pending
    }

    mutating func update(cursor: CGPoint, windowPosition: CGPoint) -> Bool {
        if phase == .active { return true }
        guard phase == .pending,
              let startCursorPosition,
              let startWindowPosition else { return false }

        let cursorDelta = hypot(
            cursor.x - startCursorPosition.x,
            cursor.y - startCursorPosition.y
        )
        let windowDelta = hypot(
            windowPosition.x - startWindowPosition.x,
            windowPosition.y - startWindowPosition.y
        )
        if cursorDelta >= 5 && windowDelta >= 5 {
            phase = .active
            return true
        }
        return false
    }

    func cursorDistance(to cursor: CGPoint) -> CGFloat {
        guard let startCursorPosition else { return 0 }
        return hypot(cursor.x - startCursorPosition.x, cursor.y - startCursorPosition.y)
    }

    mutating func ignore() {
        phase = .ignored
    }

    mutating func reset() {
        phase = .idle
        startCursorPosition = nil
        startWindowPosition = nil
    }
}

final class DragSnapManager {
    static let shared = DragSnapManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var dragGesture = DragGestureClassifier()
    private var currentSnapAction: SnapAction?
    private var draggedWindow: AXUIElement?
    private var didRestoreFromSnap = false
    private let stateLock = NSLock()

    private let edgeThreshold: CGFloat = 100
    private let cornerRadius: CGFloat = 200
    /// Heuristic title bar height for drag gesture detection.
    /// Most macOS apps use ~28pt; 40 provides a tolerant upper bound.
    private let titleBarHeight: CGFloat = 40

    func start() {
        guard UserPreferences.shared.dragSnapEnabled else { return }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDragged.rawValue) |
                                 (1 << CGEventType.leftMouseUp.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, _ -> Unmanaged<CGEvent>? in
                DragSnapManager.shared.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            }, userInfo: nil
        )
        guard let eventTap = eventTap else {
            FileLog.write("DragSnapManager.start: CGEvent.tapCreate failed — check Input Monitoring permission")
            return
        }
        runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let eventTap = eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    func reload() { stop(); start() }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let cursorPosition = event.location
        stateLock.lock()
        defer { stateLock.unlock() }
        switch type {
        case .leftMouseDragged:
            handleDrag(cursorPosition: cursorPosition)
        case .leftMouseUp:
            handleMouseUp(cursorPosition: cursorPosition)
        default: break
        }
    }

    private func handleDrag(cursorPosition: CGPoint) {
        switch dragGesture.phase {
        case .idle:
            guard let window = WindowManager.shared.getFocusedWindow(),
                  let windowFrame = WindowManager.shared.getFrame(of: window) else { return }
            draggedWindow = window
            didRestoreFromSnap = false
            dragGesture.begin(
                cursor: cursorPosition,
                windowFrame: windowFrame,
                titleBarHeight: titleBarHeight
            )
            return
        case .pending:
            guard let window = draggedWindow,
                  let currentWindowPosition = WindowManager.shared.getPosition(of: window) else {
                dragGesture.ignore()
                return
            }
            guard dragGesture.update(
                cursor: cursorPosition,
                windowPosition: currentWindowPosition
            ) else { return }
        case .active:
            break
        case .ignored:
            return
        }

        let cursorDelta = dragGesture.cursorDistance(to: cursorPosition)

        // Restore from snap after an active title-bar drag moves 50px+
        if !didRestoreFromSnap && cursorDelta > 50 {
            didRestoreFromSnap = true
            guard let window = draggedWindow else { return }
            let cursor = cursorPosition
            if WindowManager.shared.hasPreviousFrame(for: window) {
                DispatchQueue.main.async {
                    WindowManager.shared.restoreWindowAtCursor(window, cursorCG: cursor)
                }
                return
            } else if WindowManager.shared.isWindowMaximized(window) {
                DispatchQueue.main.async {
                    WindowManager.shared.restoreFromMaximized(window, cursorCG: cursor)
                }
                return
            }
        }

        let detectedAction = detectSnapZone(cursor: cursorPosition)

        if detectedAction != currentSnapAction {
            currentSnapAction = detectedAction
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let action = detectedAction, let screen = self.screenForCursor(cursorPosition) {
                    if let frame = SnapZone.frame(for: action, on: screen) {
                        SnapOverlayWindow.shared.show(at: frame)
                    }
                } else {
                    SnapOverlayWindow.shared.hideOverlay()
                }
            }
        }
    }

    private func handleMouseUp(cursorPosition: CGPoint) {
        let action = currentSnapAction
        let window = draggedWindow
        let wasDragging = dragGesture.phase == .active

        resetDragState()

        guard wasDragging, let action = action, let window = window else {
            DispatchQueue.main.async { SnapOverlayWindow.shared.hideOverlay() }
            return
        }
        guard let screen = screenForCursor(cursorPosition) else {
            DispatchQueue.main.async { SnapOverlayWindow.shared.hideOverlay() }
            return
        }

        if let targetFrame = SnapZone.frame(for: action, on: screen) {
            let cgFrame = WindowManager.shared.convertToCG(nsFrame: targetFrame, screen: screen)
            DispatchQueue.main.async {
                WindowManager.shared.move(window: window, to: cgFrame)
                SnapOverlayWindow.shared.hideOverlay()
            }
        } else {
            DispatchQueue.main.async { SnapOverlayWindow.shared.hideOverlay() }
        }
    }

    // MARK: - Zone Detection

    func detectSnapZone(cursor: CGPoint) -> SnapAction? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let mainHeight = mainScreen.frame.height
        // CG cursor (origin top-left) → NS point (origin bottom-left) for screen hit-testing
        let nsCursor = CGPoint(x: cursor.x, y: mainHeight - cursor.y)

        guard let screen = screenForNSPoint(nsCursor) else { return nil }
        let frame = screen.frame

        let distLeft = nsCursor.x - frame.minX
        let distRight = frame.maxX - nsCursor.x
        let distTop = frame.maxY - nsCursor.y
        let distBottom = nsCursor.y - frame.minY

        let nearLeft = distLeft < edgeThreshold
        let nearRight = distRight < edgeThreshold
        let nearTop = distTop < edgeThreshold
        let nearBottom = distBottom < edgeThreshold

        let inCornerLeft = distLeft < cornerRadius
        let inCornerRight = distRight < cornerRadius
        let inCornerTop = distTop < cornerRadius
        let inCornerBottom = distBottom < cornerRadius

        // Corners first
        if nearTop && inCornerLeft { return .topLeft }
        if nearTop && inCornerRight { return .topRight }
        if nearBottom && inCornerLeft { return .bottomLeft }
        if nearBottom && inCornerRight { return .bottomRight }
        if nearLeft && inCornerTop { return .topLeft }
        if nearRight && inCornerTop { return .topRight }
        if nearLeft && inCornerBottom { return .bottomLeft }
        if nearRight && inCornerBottom { return .bottomRight }

        // Edges
        if nearLeft { return .leftHalf }
        if nearRight { return .rightHalf }
        if nearTop { return .maximize }
        if nearBottom { return .bottomHalf }

        return nil
    }

    private func screenForCursor(_ cgPoint: CGPoint) -> NSScreen? {
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let nsPoint = CGPoint(x: cgPoint.x, y: mainScreen.frame.height - cgPoint.y)
        return screenForNSPoint(nsPoint)
    }

    private func screenForNSPoint(_ nsPoint: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(nsPoint) {
                return screen
            }
        }
        return NSScreen.main
    }

    private func resetDragState() {
        dragGesture.reset()
        currentSnapAction = nil
        draggedWindow = nil
        didRestoreFromSnap = false
    }
}
