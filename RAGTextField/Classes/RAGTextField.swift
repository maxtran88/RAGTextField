//
// Copyright (c) 2017 Reimar Twelker
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import UIKit

private enum Constants {
    
    /// The string used to measure the height of an arbitrary string.
    static let textSizeMeasurementString = "X"
    
    /// The duration of the placeholder animation if no duration is set by the
    /// user.
    static let defaultPlaceholderAnimationDuration = CFTimeInterval(0.2)
    
    /// The space between the left and right overlay views and the text.
    static let overlaySpaceToText: CGFloat = 7.0
}

open class RAGTextField: UITextField {
    
    /// Represents a horizontal position. Either left or right.
    private enum HorizontalPosition {
        case left, right
    }
    
    /// The font of the text field.
    ///
    /// If the hint font is `nil`, the given font is used for the hint.
    ///
    /// If the placeholder font is `nil`, the given font is used for the
    /// placeholder.
    open override var font: UIFont? {
        didSet {
            if hintFont == nil {
                hintLabel.font = font
            }
            
            if placeholderFont == nil {
                placeholderLabel.font = font
            }
            
            setNeedsUpdateConstraints()
        }
    }
    
    /// The text alignment of the text field.
    ///
    /// The given value is applied to the hint and the placeholder as well.
    open override var textAlignment: NSTextAlignment {
        didSet {
            hintLabel.textAlignment = textAlignment
            placeholderLabel.textAlignment = textAlignment
            
            needsUpdateOfPlaceholderTransformAfterLayout = true
            setNeedsLayout()
        }
    }
    
    /// The text value of the text field. Updates the position of the placeholder.
    open override var text: String? {
        didSet {
            updatePlaceholderTransform()
        }
    }
    
    // MARK: Hint
    
    private let hintLabel = UILabel()
    
    /// The text value of the hint.
    ///
    /// If `nil`, the hint label is removed from the layout.
    @IBInspectable open var hint: String? {
        set {
            if newValue == nil {
                hintLabel.text = ""
                hintLabel.isHidden = true
            } else {
                hintLabel.text = newValue
                hintLabel.isHidden = false
            }
            
            needsUpdateOfPlaceholderTransformAfterLayout = true
            invalidateIntrinsicContentSize()
        }
        get {
            return hintLabel.text
        }
    }
    
    /// The font used for the hint.
    ///
    /// If `nil`, the font of the text field is used instead.
    open var hintFont: UIFont? {
        set {
            hintLabel.font = newValue ?? font
        }
        get {
            return hintLabel.font
        }
    }
    
    /// The text color of the hint.
    ///
    /// If `nil`, the text color of the text field is used instead.
    @IBInspectable open var hintColor: UIColor? {
        set {
            hintLabel.textColor = newValue ?? textColor
        }
        get {
            return hintLabel.textColor
        }
    }
    
    /// The computed height of the hint in points.
    private var hintHeight: CGFloat {
        
        guard !hintLabel.isHidden else {
            return 0
        }
        
        return measureTextHeight(using: hintLabel.font)
    }
    
    // MARK: Placeholder
    
    private let placeholderLabel = UILabel()
    
    /// The text value of the placeholder.
    override open var placeholder: String? {
        set {
            placeholderLabel.text = newValue ?? ""
        }
        get {
            return placeholderLabel.text
        }
    }
    
    /// The font used for the placeholder.
    ///
    /// If `nil`, the font of the text field is used instead.
    open var placeholderFont: UIFont? {
        set {
            placeholderLabel.font = newValue ?? font
        }
        get {
            return placeholderLabel.font
        }
    }
    
    /// The text color of the placeholder.
    ///
    /// If `nil`, the text color of the text field is used instead.
    @IBInspectable open var placeholderColor: UIColor? {
        set {
            placeholderLabel.textColor = newValue ?? textColor
        }
        get {
            return placeholderLabel.textColor
        }
    }
    
    /// The scale applied to the placeholder when it is moved to the scaled
    /// position.
    ///
    /// Negative values are clamped to `0`. The default value is `1`.
    @IBInspectable open var placeholderScaleWhenEditing: CGFloat = 1.0 {
        didSet {
            if placeholderScaleWhenEditing < 0.0 {
                placeholderScaleWhenEditing = 0.0
            }
            
            needsUpdateOfPlaceholderTransformAfterLayout = true
            invalidateIntrinsicContentSize()
        }
    }
    
    /// The vertical offset of the scaled placeholder from the top of the text.
    ///
    /// Can be used to put a little distance between the placeholder and the text.
    @IBInspectable open var scaledPlaceholderOffset: CGFloat = 0.0 {
        didSet {
            needsUpdateOfPlaceholderTransformAfterLayout = true
            invalidateIntrinsicContentSize()
        }
    }
    
    /// Controls how the placeholder is being displayed, whether it is scaled
    /// and whether the scaled placeholder is taken into consideration when the
    /// view is layed out.
    ///
    /// The default value is `.scalesWhenNotEmpty`.
    open var placeholderMode: RAGTextFieldPlaceholderMode = .scalesWhenNotEmpty {
        didSet {
            needsUpdateOfPlaceholderTransformAfterLayout = true
            invalidateIntrinsicContentSize()
        }
    }
    
    /// The computed height of the untransformed placeholder in points.
    private var placeholderHeight: CGFloat {
        
        return measureTextHeight(using: placeholderLabel.font)
    }
    
    /// The duration of the animation transforming the placeholder to and from
    /// the scaled position. If `nil`, a default duration is used. Set to 0 to
    /// disable the animation.
    open var placeholderAnimationDuration: CFTimeInterval? = nil
    
    /// Whether the view is configured to animate the placeholder.
    ///
    /// The value is `false` only if the `placeholderAnimationDuration` is explicitly set to `0`.
    private var animatesPlaceholder: Bool {
        let duration = placeholderAnimationDuration ?? Constants.defaultPlaceholderAnimationDuration
        let result = duration > CFTimeInterval(0)
        
        return result
    }
    
    /// Whether the placeholder transform should be set after the next
    /// `layoutSubviews`.
    ///
    /// Does not trigger `layoutSubviews`.
    private var needsUpdateOfPlaceholderTransformAfterLayout = true
    
    /// Keeps track of whether the placeholder is currently in the scaled
    /// position.
    ///
    /// Used to prevent unnecessary animations or updates of the
    /// transform.
    private var isPlaceholderTransformedToScaledPosition = false
    
    // MARK: Text background view
    
    /// An optional view added to the text field. Its frame is set so that it is
    /// the size of the text and its horizontal and vertical padding.
    open weak var textBackgroundView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            guard let view = textBackgroundView else {
                return
            }
            
            view.isUserInteractionEnabled = false
            view.translatesAutoresizingMaskIntoConstraints = true
            
            addSubview(view)
            sendSubviewToBack(view)
            
            setNeedsLayout()
        }
    }
    
    /// Computes the frame of the text background view.
    ///
    /// - Returns: The frame
    private func computeTextBackgroundViewFrame() -> CGRect {
        
        let y = computeTopInsetToText() - verticalTextPadding
        let h = verticalTextPadding + measureTextHeight() + verticalTextPadding
        let frame = CGRect(x: 0, y: y, width: bounds.width, height: h)
        
        return frame
    }
    
    /// The padding applied to the left and right of the text rectangle. Can be
    /// used to reserve more space for the `textBackgroundView`.
    @IBInspectable open var horizontalTextPadding: CGFloat = 0.0 {
        didSet {
            setNeedsLayout()
        }
    }
    
    /// The padding applied to the top and bottom of the text rectangle. Can be
    /// used to reserve more space for the `textBackgroundView`.
    @IBInspectable open var verticalTextPadding: CGFloat = 0.0 {
        didSet {
            setNeedsLayout()
        }
    }
    
    // MARK: Overlay views
    
    /// Whether the left view is displayed to the left or to the right of the text.
    private var leftViewPosition: HorizontalPosition {
        
        if textAlignment == .natural && UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            return .right
        } else {
            return .left
        }
    }
    
    private var isLeftViewVisible: Bool {
        
        guard leftView != nil else { return false }
        return isOverlayVisible(with: leftViewMode)
    }
    
    /// Whether the left view is displayed to the left or to the right of the text.
    private var rightViewPosition: HorizontalPosition {
        
        if textAlignment == .natural && UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            return .left
        } else {
            return .right
        }
    }
    
    private var isRightViewVisible: Bool {
        
        guard rightView != nil else { return false }
        return isOverlayVisible(with: rightViewMode)
    }
    
    private func isOverlayVisible(with viewMode: UITextField.ViewMode) -> Bool {
        
        switch viewMode {
        case .always:
            return true
        case .whileEditing:
            return isEditing
        case .unlessEditing:
            return !isEditing
        case .never:
            return false
        }
    }
    
    // MARK: Clear button
    
    /// Whether the clear button is displayed to the left or to the right of the text.
    private var clearButtonPosition: HorizontalPosition {
        
        if textAlignment == .natural && UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            return .left
        } else {
            return .right
        }
    }
    
    private func isClearButtonVisible() -> Bool {
        
        return isOverlayVisible(with: clearButtonMode)
    }
    
    // MARK: - Init
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        addSubview(hintLabel)
        setupHintLabel()
        
        addSubview(placeholderLabel)
        setupPlaceholderLabel()
        
        // Listen for text changes on self
        let action = #selector(didChangeText)
        NotificationCenter.default.addObserver(self, selector: action, name: UITextField.textDidChangeNotification, object: self)
    }
    
    @objc private func didChangeText() {
        updatePlaceholderTransform(animated: true)
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        
        // Copy the placeholder from the super class and set it nil
        if super.placeholder != nil {
            placeholder = super.placeholder
            super.placeholder = nil
        }
    }
    
    /// Measures the height of the given text using the given font.
    ///
    /// - Parameters:
    ///   - font: The font to use
    ///   - text: The text whose height is measured
    /// - Returns: The height of the given string
    private func measureTextHeight(text: String = Constants.textSizeMeasurementString, using font: UIFont? = nil) -> CGFloat {
        
        let font = font ?? self.font!
        let boundingSize = text.size(using: font)
        let result = ceil(boundingSize.height)
        
        return result
    }
    
    // MARK: - Hint
    
    /// Sets initial properties and constraints of the hint label.
    private func setupHintLabel() {
        
        hint = nil
        hintLabel.font = font
        hintLabel.textAlignment = textAlignment
    }
    
    private func hintFrame(forBounds bounds: CGRect) -> CGRect {
        
        let w = bounds.width - 2 * horizontalTextPadding
        let h = measureTextHeight(using: hintLabel.font)
        let x = horizontalTextPadding
        let y = bounds.height - h
        let frame = CGRect(x: x, y: y, width: w, height: h)
        
        return frame
    }
    
    // MARK: - Placeholder
    
    /// Sets initial properties and constraints of the placeholder label.
    private func setupPlaceholderLabel() {
        
        placeholderLabel.text = ""
        placeholderLabel.font = font
        placeholderLabel.textAlignment = textAlignment
    }
    
    /// Returns whether the placeholder should be displayed in the scaled
    /// position or in the default position.
    ///
    /// - Returns: `true` if the placeholder should be displayed in the scaled position
    private func shouldDisplayScaledPlaceholder() -> Bool {
        let result: Bool
        
        switch placeholderMode {
        case .scalesWhenEditing:
            result = (text != nil) && !text!.isEmpty || isFirstResponder
        case .scalesWhenNotEmpty:
            result = (text != nil) && !text!.isEmpty
        default:
            result = false
        }
        
        return result
    }
    
    private func shouldDisplayPlaceholder() -> Bool {
        let result: Bool
        
        switch placeholderMode {
        case .scalesWhenEditing:
            result = true
        case .scalesWhenNotEmpty:
            result = true
        case .simple:
            result = (text == nil) || text!.isEmpty
        }
        
        return result
    }
    
    private func scaledPlaceholderHeight() -> CGFloat {
        guard placeholderMode.scalesPlaceholder else {
            return 0
        }
        
        return ceil(placeholderScaleWhenEditing * placeholderHeight)
    }
    
    // MARK: - Overlay views
    
    open override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        
        let superValue = super.leftViewRect(forBounds: bounds)
        let size = superValue.size
        let x = horizontalTextPadding
        let y = computeTopInsetToText() + 0.5 * (measureTextHeight() - size.height)
        let rect = CGRect(origin: CGPoint(x: x, y: y), size: size)
        
        return rect
    }
    
    open override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        
        let superValue = super.leftViewRect(forBounds: bounds)
        let size = superValue.size
        let x = bounds.width - horizontalTextPadding - size.width
        let y = computeTopInsetToText() + 0.5 * (measureTextHeight() - size.height)
        let rect = CGRect(origin: CGPoint(x: x, y: y), size: size)
        
        return rect
    }
    
    // MARK: - UITextField
    
    open override func textRect(forBounds bounds: CGRect) -> CGRect {
        
        return textAndEditingRect(forBounds: bounds)
    }
    
    open override func editingRect(forBounds bounds: CGRect) -> CGRect {
        
        return textAndEditingRect(forBounds: bounds)
    }
    
    private func textAndEditingRect(forBounds bounds: CGRect) -> CGRect {
        
        let topInset = computeTopInsetToText()
        let leftInset = computeLeftInsetToText()
        let bottomInset = computeBottomInsetToText()
        let rightInset = computeRightInsetToText()
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        let rect = bounds.inset(by: insets)
        
        return rect
    }
    
    private func computeTopInsetToText() -> CGFloat {
        
        let placeholderOffset = placeholderMode.scalesPlaceholder ? scaledPlaceholderOffset : 0.0
        let inset = ceil(scaledPlaceholderHeight() + placeholderOffset + verticalTextPadding)
        
        return inset
    }
    
    private func computeLeftInsetToText() -> CGFloat {
        
        let inset: CGFloat
        if isLeftViewVisible && leftViewPosition == .left {
            inset = leftViewRect(forBounds: bounds).maxX + Constants.overlaySpaceToText
        } else if isRightViewVisible && rightViewPosition == .left {
            inset = leftViewRect(forBounds: bounds).maxX + Constants.overlaySpaceToText
        } else if isClearButtonVisible() && clearButtonPosition == .left {
            inset = clearButtonRect(forBounds: bounds).maxX + Constants.overlaySpaceToText
        } else {
            inset = horizontalTextPadding
        }
        
        return inset
    }
    
    private func computeBottomInsetToText() -> CGFloat {
        
        let inset = ceil(hintHeight + verticalTextPadding)
        
        return inset
    }
    
    private func computeRightInsetToText() -> CGFloat {
        
        let inset: CGFloat
        if isRightViewVisible && rightViewPosition == .right {
            inset = bounds.width - rightViewRect(forBounds: bounds).minX + Constants.overlaySpaceToText
        } else if isLeftViewVisible && leftViewPosition == .right {
            inset = bounds.width - rightViewRect(forBounds: bounds).minX + Constants.overlaySpaceToText
        } else if isClearButtonVisible() && clearButtonPosition == .right {
            inset = bounds.width - clearButtonRect(forBounds: bounds).minX + Constants.overlaySpaceToText
        } else {
            inset = horizontalTextPadding
        }
        
        return inset
    }
    
    private func computeLeadingInsetToText() -> CGFloat {
        
        if textAlignment == .natural && UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            return computeRightInsetToText()
        } else {
            return computeLeftInsetToText()
        }
    }
    
    private func computeTrailingInsetToText() -> CGFloat {
        
        if textAlignment == .natural && UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            return computeLeftInsetToText()
        } else {
            return computeRightInsetToText()
        }
    }
    
    open override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        
        let superValue = super.clearButtonRect(forBounds: bounds)
        let size = superValue.size
        let y = computeTopInsetToText() + 0.5 * (measureTextHeight() - size.height)
        
        let x: CGFloat
        if clearButtonPosition == .left {
            x = horizontalTextPadding
        } else {
            x = bounds.width - size.width - horizontalTextPadding
        }
        
        let clearButtonRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        
        return clearButtonRect
    }
    
    // MARK: - UIResponder
    
    open override func becomeFirstResponder() -> Bool {
        defer {
            updatePlaceholderTransform(animated: true)
        }
        
        return super.becomeFirstResponder()
    }
    
    open override func resignFirstResponder() -> Bool {
        defer {
            updatePlaceholderTransform(animated: true)
        }
        
        return super.resignFirstResponder()
    }
    
    // MARK: - Animations
    
    private func basePlaceholderFrame() -> CGRect {
        
        let x = computeLeftInsetToText()
        let placeholderHeight = measureTextHeight(using: placeholderLabel.font)
        let y = computeTopInsetToText() + 0.5 * (measureTextHeight() - placeholderHeight)
        let w = bounds.width - computeRightInsetToText() - x
        let h = placeholderHeight
        let frame = CGRect(x: x, y: y, width: w, height: h)
        
        return frame
    }
    
    private func scaledPlaceholderFrame() -> CGRect {
        
        let placeholderHeight = scaledPlaceholderHeight()
        let y = computeTopInsetToText() - verticalTextPadding - scaledPlaceholderOffset - placeholderHeight
        let w = placeholderScaleWhenEditing * (bounds.width - computeRightInsetToText() - computeLeftInsetToText())
        let h = placeholderHeight
        let x: CGFloat
        
        switch placeholderLabel.textAlignment {
        case .left:
            x = horizontalTextPadding
        case .right:
            x = bounds.width - horizontalTextPadding - w
        case .center:
            x = 0.5 * (bounds.width - w)
        case .justified, .natural:
            if UIApplication.shared.userInterfaceLayoutDirection == .leftToRight {
                x = horizontalTextPadding
            } else {
                x = bounds.width - horizontalTextPadding - w
            }
        }
        
        let frame = CGRect(x: x, y: y, width: w, height: h)

        return frame
    }
    
    private func expectedPlaceholderFrame() -> CGRect {
        
        if shouldDisplayScaledPlaceholder() {
            return scaledPlaceholderFrame()
        } else {
            return basePlaceholderFrame()
        }
    }
    
    private func animatePlaceholderToScaledPosition() {
        
        placeholderLabel.layer.removeAllAnimations()
        
        let scale = placeholderScaleWhenEditing
        let transform = CATransform3DMakeScale(scale, scale, 1.0)
        let transformAnimation = makeTransformAnimation(transform: transform)
        placeholderLabel.layer.add(transformAnimation, forKey: "transform")
        placeholderLabel.layer.transform = transform
        
        let position = scaledPlaceholderFrame().center
        let positionAnimation = makePositionAnimation(position: position)
        placeholderLabel.layer.add(positionAnimation, forKey: "position")
        placeholderLabel.layer.position = position
    }
    
    private func animatePlaceholderToBasePosition() {
        
        placeholderLabel.layer.removeAllAnimations()
        
        let transform = CATransform3DIdentity
        let transformAnimation = makeTransformAnimation(transform: transform)
        placeholderLabel.layer.add(transformAnimation, forKey: "transform")
        placeholderLabel.layer.transform = transform

        let position = basePlaceholderFrame().center
        let positionAnimation = makePositionAnimation(position: position)
        placeholderLabel.layer.add(positionAnimation, forKey: "position")
        placeholderLabel.layer.position = position
    }
    
    private func makeTransformAnimation(transform: CATransform3D) -> CAAnimation {
        
        let animation = CABasicAnimation(keyPath: "transform")
        animation.duration = placeholderAnimationDuration ?? Constants.defaultPlaceholderAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        let fromValue = placeholderLabel.layer.presentation()?.transform ?? placeholderLabel.layer.transform
        animation.fromValue = fromValue
        animation.toValue = transform
        
        return animation
    }
    
    private func makePositionAnimation(position: CGPoint) -> CAAnimation {
        
        let animation = CABasicAnimation(keyPath: "position")
        animation.duration = placeholderAnimationDuration ?? Constants.defaultPlaceholderAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        let fromValue = placeholderLabel.layer.presentation()?.position ?? placeholderLabel.layer.position
        animation.fromValue = fromValue
        animation.toValue = position
        
        return animation
    }
    
    private func updatePlaceholderTransform(animated: Bool = false) {
        
        // Make sure the layout is up to date
        layoutIfNeeded()
        
        guard animatesPlaceholder else {
            placeholderLabel.layer.transform = expectedPlaceholderTransform()
            placeholderLabel.frame = expectedPlaceholderFrame()
            
            return
        }
        
        switch (animated, shouldDisplayScaledPlaceholder(), isPlaceholderTransformedToScaledPosition) {
        case (true, true, false):
            animatePlaceholderToScaledPosition()
            isPlaceholderTransformedToScaledPosition = true
        case (true, false, true):
            animatePlaceholderToBasePosition()
            isPlaceholderTransformedToScaledPosition = false
        default:
            placeholderLabel.layer.transform = expectedPlaceholderTransform()
            placeholderLabel.frame = expectedPlaceholderFrame()
        }

        // Update the general visibility of the placeholder
        placeholderLabel.isHidden = !shouldDisplayPlaceholder()
    }
    
    /// Returns the transform that should be applied to the placeholder.
    ///
    /// - Returns: the transform
    private func expectedPlaceholderTransform() -> CATransform3D {
        
        if shouldDisplayScaledPlaceholder() {
            let scale = placeholderScaleWhenEditing
            return CATransform3DMakeScale(scale, scale, 1.0)
        }
        
        return CATransform3DIdentity
    }
    
    // MARK: - UIView
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        if needsUpdateOfPlaceholderTransformAfterLayout {
            updatePlaceholderTransform()
            needsUpdateOfPlaceholderTransformAfterLayout = false
        }
        
        // Update the frame of the optional text background view
        textBackgroundView?.frame = computeTextBackgroundViewFrame()
        
        // Update the frame of the hint
        if !hintLabel.isHidden {
            hintLabel.frame = hintFrame(forBounds: bounds)
        }
    }
    
    open override var intrinsicContentSize: CGSize {
        
        let intrinsicHeight = computeTopInsetToText() + measureTextHeight() + computeBottomInsetToText()
        let size = CGSize(width: UIView.noIntrinsicMetric, height: ceil(intrinsicHeight))
        
        return size
    }
}
