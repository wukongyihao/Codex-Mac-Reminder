import AppKit
import CodexBreathingLightCore
import Foundation
import QuartzCore

@MainActor
final class EdgeGlowView: NSView {
    private let options: AlertOptions

    init(frame: NSRect, options: AlertOptions) {
        self.options = options
        super.init(frame: frame)
        wantsLayer = true
        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setupLayers() {
        guard let rootLayer = layer else {
            return
        }

        rootLayer.backgroundColor = NSColor.clear.cgColor
        rootLayer.masksToBounds = false

        let color = NSColor(boopaHex: options.colorHex)
        let depth = min(
            CGFloat(options.thickness + options.blur),
            min(bounds.width, bounds.height) / 2
        )

        addBand(
            to: rootLayer,
            frame: CGRect(x: 0, y: bounds.height - depth, width: bounds.width, height: depth),
            color: color,
            startPoint: CGPoint(x: 0.5, y: 1),
            endPoint: CGPoint(x: 0.5, y: 0)
        )
        addBand(
            to: rootLayer,
            frame: CGRect(x: 0, y: 0, width: bounds.width, height: depth),
            color: color,
            startPoint: CGPoint(x: 0.5, y: 0),
            endPoint: CGPoint(x: 0.5, y: 1)
        )
        addBand(
            to: rootLayer,
            frame: CGRect(x: 0, y: 0, width: depth, height: bounds.height),
            color: color,
            startPoint: CGPoint(x: 0, y: 0.5),
            endPoint: CGPoint(x: 1, y: 0.5)
        )
        addBand(
            to: rootLayer,
            frame: CGRect(x: bounds.width - depth, y: 0, width: depth, height: bounds.height),
            color: color,
            startPoint: CGPoint(x: 1, y: 0.5),
            endPoint: CGPoint(x: 0, y: 0.5)
        )

        animate(rootLayer)
    }

    private func addBand(
        to rootLayer: CALayer,
        frame: CGRect,
        color: NSColor,
        startPoint: CGPoint,
        endPoint: CGPoint
    ) {
        let glowLayer = CAGradientLayer()
        glowLayer.frame = frame
        glowLayer.startPoint = startPoint
        glowLayer.endPoint = endPoint
        glowLayer.colors = [
            color.withAlphaComponent(0.92).cgColor,
            color.withAlphaComponent(0.36).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        glowLayer.locations = [0.0, 0.38, 1.0]
        rootLayer.addSublayer(glowLayer)
    }

    private func animate(_ layer: CALayer) {
        switch options.animation {
        case .solid:
            layer.opacity = 1
        case .breathe, .pulse:
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = options.animation == .breathe ? 0.35 : 0.12
            animation.toValue = 1.0
            animation.duration = options.animation == .breathe ? 1.0 : 0.45
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(animation, forKey: "boopaOpacity")
        }
    }
}

@MainActor
final class EdgeGlowAppDelegate: NSObject, NSApplicationDelegate {
    private let options: AlertOptions
    private var glowWindows: [NSWindow] = []
    private var closeButtonWindows: [NSWindow] = []

    init(options: AlertOptions) {
        self.options = options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createWindows()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(options.effectiveDurationSeconds)) {
            NSApp.terminate(nil)
        }
    }

    private func createWindows() {
        for screen in NSScreen.screens {
            createGlowWindow(on: screen)
            createCloseButtonWindow(on: screen)
        }
    }

    private func createGlowWindow(on screen: NSScreen) {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.alphaValue = 0
        panel.contentView = EdgeGlowView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            options: options
        )
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
        glowWindows.append(panel)
    }

    private func createCloseButtonWindow(on screen: NSScreen) {
        let buttonSize = NSSize(width: 180, height: 48)
        let margin: CGFloat = 24
        let frame = NSRect(
            x: screen.frame.maxX - buttonSize.width - margin,
            y: screen.frame.maxY - buttonSize.height - margin,
            width: buttonSize.width,
            height: buttonSize.height
        )
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.level = .screenSaver
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        let button = NSButton(
            title: "关闭本次提醒",
            target: self,
            action: #selector(closeCurrentReminder)
        )
        button.frame = NSRect(origin: .zero, size: buttonSize)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 16, weight: .semibold)
        button.keyEquivalent = "\u{1b}"
        button.setButtonType(.momentaryPushIn)

        panel.contentView = button
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0.92
        }
        closeButtonWindows.append(panel)
    }

    @objc private func closeCurrentReminder() {
        NSApp.terminate(nil)
    }
}

@MainActor
func runUI(options: AlertOptions) {
    let app = NSApplication.shared
    let delegate = EdgeGlowAppDelegate(options: options)
    app.delegate = delegate
    withExtendedLifetime(delegate) {
        app.run()
    }
}

do {
    var options = try AlertOptions.parse(Array(CommandLine.arguments.dropFirst()))
    let reminderState = ReminderStateStore().read()
    if options.eventKind == .attention, !options.colorWasProvided {
        options.colorHex = reminderState.effectiveAttentionColorHex
    }
    guard ReminderGate.shouldShowAlert(isEnabled: reminderState.isEnabled, force: options.force) else {
        exit(0)
    }

    runUI(options: options)
} catch {
    fputs("codex-breathing-light-ui: \(error)\n", stderr)
    exit(2)
}

private extension NSColor {
    convenience init(boopaHex: String) {
        let namedColors: [String: NSColor] = [
            "red": .systemRed,
            "green": .systemGreen,
            "blue": .systemBlue,
            "orange": .systemOrange,
            "yellow": .systemYellow,
            "cyan": .systemCyan,
            "purple": .systemPurple,
            "pink": .systemPink
        ]

        let trimmed = boopaHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if let named = namedColors[trimmed.lowercased()] {
            self.init(cgColor: named.cgColor)!
            return
        }

        let hex = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value), hex.count == 6 else {
            self.init(cgColor: NSColor.systemRed.cgColor)!
            return
        }

        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
