//
//  HoverButton.swift
//  Polaris
//
//  A reusable square button with transparent background, hover effect, and SF Symbol icon.
//

import AppKit

final class HoverButton: NSButton {

    // MARK: - Size Variants

    enum Size {
        case small   // 24x24
        case regular // 28x28
        case large   // 32x32

        var dimension: CGFloat {
            switch self {
            case .small: return 24
            case .regular: return 28
            case .large: return 32
            }
        }

        var symbolConfiguration: NSImage.SymbolConfiguration {
            switch self {
            case .small:
                return NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            case .regular:
                return NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            case .large:
                return NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 5
            case .regular: return 6
            case .large: return 7
            }
        }
    }

    // MARK: - Properties

    private let buttonSize: Size
    private var backgroundLayer: CALayer?
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false

    // MARK: - Initialization

    init(symbolName: String,
         tooltip: String,
         size: Size = .regular,
         target: AnyObject? = nil,
         action: Selector? = nil) {
        self.buttonSize = size
        super.init(frame: NSRect(x: 0, y: 0, width: size.dimension, height: size.dimension))
        configure(symbolName: symbolName, tooltip: tooltip, target: target, action: action)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    private func configure(symbolName: String, tooltip: String, target: AnyObject?, action: Selector?) {
        self.target = target
        self.action = action
        self.toolTip = tooltip
        self.isBordered = false
        self.bezelStyle = .smallSquare
        self.imagePosition = .imageOnly
        self.imageScaling = .scaleNone
        self.translatesAutoresizingMaskIntoConstraints = false

        widthAnchor.constraint(equalToConstant: buttonSize.dimension).isActive = true
        heightAnchor.constraint(equalToConstant: buttonSize.dimension).isActive = true

        setSymbol(symbolName, accessibilityDescription: tooltip)
        setupBackgroundLayer()
    }

    private func setupBackgroundLayer() {
        wantsLayer = true
        layer?.masksToBounds = false

        let bgLayer = CALayer()
        bgLayer.cornerRadius = buttonSize.cornerRadius
        bgLayer.masksToBounds = true
        bgLayer.opacity = 0

        layer?.insertSublayer(bgLayer, at: 0)
        backgroundLayer = bgLayer

        updateHoverBackground()
    }

    // MARK: - Public Methods

    func setSymbol(_ symbolName: String, accessibilityDescription: String? = nil) {
        var img = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription ?? toolTip)
        img = img?.withSymbolConfiguration(buttonSize.symbolConfiguration)
        self.image = img
        self.needsDisplay = true
    }

    // MARK: - Intrinsic Size

    override var intrinsicContentSize: NSSize {
        NSSize(width: buttonSize.dimension, height: buttonSize.dimension)
    }

    override var alignmentRectInsets: NSEdgeInsets {
        .init(top: 0, left: 0, bottom: 0, right: 0)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let squareSize = NSSize(width: buttonSize.dimension, height: buttonSize.dimension)
        super.setFrameSize(squareSize)
    }

    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backgroundLayer?.frame = bounds
        CATransaction.commit()
    }

    // MARK: - Tracking Area

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard isEnabled else { return }
        isHovered = true
        animateHover(show: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        animateHover(show: false)
    }

    // MARK: - Hover Animation

    private func animateHover(show: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        backgroundLayer?.opacity = show ? 1.0 : 0.0
        CATransaction.commit()
    }

    private func updateHoverBackground() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            backgroundLayer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
        }
    }

    // MARK: - Appearance Changes

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHoverBackground()
    }

    override var isEnabled: Bool {
        didSet {
            if !isEnabled && isHovered {
                animateHover(show: false)
            }
        }
    }
}
