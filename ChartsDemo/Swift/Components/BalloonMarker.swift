//
//  BalloonMarker.swift
//  ChartsDemo-Swift
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import Charts

open class BalloonMarker: MarkerImage {
    @objc open var color: UIColor?
    @objc open var arrowSize = CGSize(width: 15, height: 20)
    @objc open var font: UIFont?
    @objc open var textColor: UIColor?
    @objc open var insets = UIEdgeInsets()
    @objc open var minimumSize = CGSize()
    @objc open var borderRadius = CGFloat()
    
    fileprivate var label: String?
    fileprivate var _labelSize: CGSize = CGSize()
    fileprivate var _paragraphStyle: NSMutableParagraphStyle?
    fileprivate var _drawAttributes = [NSAttributedStringKey : Any]()
    
    @objc public init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets, borderRadius: CGFloat) {
        super.init()
        
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        self.borderRadius = borderRadius
        
        _paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
        _paragraphStyle?.alignment = .center
    }
    
    open override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {

        var offset = self.offset
        var size = self.size
        let radiusWidth = self.borderRadius
        
        if size.width == 0.0 && image != nil {
            size.width = image!.size.width
        }
        if size.height == 0.0 && image != nil {
            size.height = image!.size.height
        }
        
        let width = size.width
        let height = size.height
        let padding: CGFloat = 8.0
        
        var origin = point
        origin.x -= width / 2
        origin.y -= height
        
        if origin.x + offset.x < radiusWidth {
            offset.x = -origin.x + padding
        }
        else if let chart = chartView,
            origin.x + width + offset.x + radiusWidth > chart.bounds.size.width {
            offset.x = chart.bounds.size.width - origin.x - width - padding
        }
        
        if origin.y + offset.y < 0 {
            offset.y = height + padding;
        }
        else if let chart = chartView,
            origin.y + height + offset.y > chart.bounds.size.height {
            offset.y = chart.bounds.size.height - origin.y - height - padding
        }
        
        return offset
    }
    
    open override func draw(context: CGContext, point: CGPoint)
    {
        guard let label = label else { return }
        
        let offset = self.offsetForDrawing(atPoint: point)
        let size = self.size
        let radius = self.borderRadius
        
        var rect = CGRect(
            origin: CGPoint(
                x: point.x + offset.x,
                y: point.y + offset.y),
            size: size)
        rect.origin.x -= size.width / 2.0
        rect.origin.y -= size.height
        
        context.saveGState()
        
        let borderWidth = CGFloat(1.0)
        let radius2 = radius - borderWidth / 2
        
        if let color = color {
            if offset.y > 0 {
                context.beginPath()
                context.move(to: CGPoint(
                    x: rect.origin.x,
                    y: rect.origin.y + arrowSize.height - radius2))
                context.addLine(to: CGPoint(
                    x: rect.origin.x + (rect.size.width - arrowSize.width) / 2.0,
                    y: rect.origin.y + arrowSize.height - radius2))
                
                
                //arrow vertex
                context.addLine(to: CGPoint(
                    x: point.x,
                    y: point.y))
                context.addLine(to: CGPoint(
                    x: rect.origin.x + (rect.size.width + arrowSize.width) / 2.0,
                    y: rect.origin.y + arrowSize.height - radius2))
                context.addArc(center: CGPoint(x: rect.origin.x + rect.size.width,
                                               y: rect.origin.y + arrowSize.height),
                               radius: radius2,
                               startAngle: CGFloat(-(Double.pi/2)), endAngle: 0, clockwise: false)
                context.addArc(center: CGPoint(x: rect.origin.x + rect.size.width,
                                               y: rect.origin.y + rect.size.height - radius2),
                               radius: radius2,
                               startAngle: 0, endAngle: CGFloat(Double.pi/2), clockwise: false)
                context.addArc(center: CGPoint(x: rect.origin.x,
                                               y: rect.origin.y + rect.size.height - radius2),
                               radius: radius2,
                               startAngle: CGFloat(Double.pi/2),endAngle: CGFloat(Double.pi), clockwise: false)
                context.addArc(center: CGPoint(x: rect.origin.x,
                                               y: rect.origin.y + arrowSize.height),
                               radius: radius2,
                               startAngle: CGFloat(Double.pi), endAngle: CGFloat(-(Double.pi/2)), clockwise: false)
                
                color.setFill()
                context.fillPath()
            }
            else {
                context.beginPath()
                context.move(to: CGPoint(
                    x: rect.origin.x,
                    y: rect.origin.y))
                context.addArc(center: CGPoint(x: rect.origin.x + rect.size.width,
                                               y: rect.origin.y + radius2),
                               radius: radius2,
                               startAngle: CGFloat(-(Double.pi/2)), endAngle: 0, clockwise: false)
                context.addArc(center: CGPoint(x: rect.origin.x + rect.size.width,
                                               y: rect.origin.y + rect.size.height - arrowSize.height - radius2),
                               radius: radius2,
                               startAngle: 0, endAngle: CGFloat(Double.pi/2), clockwise: false)
                context.addLine(to: CGPoint(
                    x: rect.origin.x + (rect.size.width + arrowSize.width) / 2.0,
                    y: rect.origin.y + rect.size.height - arrowSize.height))
                
                //arrow vertex
                context.addLine(to: CGPoint(
                    x: point.x,
                    y: point.y))
                context.addLine(to: CGPoint(
                    x: rect.origin.x + (rect.size.width - arrowSize.width) / 2.0,
                    y: rect.origin.y + rect.size.height - arrowSize.height))
                context.addArc(center: CGPoint(x: rect.origin.x,
                                               y: rect.origin.y + rect.size.height - arrowSize.height - radius2),
                               radius: radius2,
                               startAngle: CGFloat(Double.pi/2),endAngle: CGFloat(Double.pi), clockwise: false)
                context.addArc(center: CGPoint(x: rect.origin.x,
                                               y: rect.origin.y + radius2),
                               radius: radius2,
                               startAngle: CGFloat(Double.pi), endAngle: CGFloat(-(Double.pi/2)), clockwise: false)
                
                color.setFill()
                context.fillPath()
            }
        }
        
        if offset.y > 0 {
            rect.origin.y += self.insets.top + arrowSize.height
        } else {
            rect.origin.y += self.insets.top
        }
        
        rect.size.height -= self.insets.top + self.insets.bottom
        UIGraphicsPushContext(context)
        
        label.draw(in: rect, withAttributes: _drawAttributes)
        UIGraphicsPopContext()
        context.restoreGState()
    }
    
    open override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        setLabel(String(entry.y))
    }
    
    @objc open func setLabel(_ newLabel: String) {
        label = newLabel
        
        _drawAttributes.removeAll()
        _drawAttributes[NSAttributedStringKey.font] = self.font
        _drawAttributes[NSAttributedStringKey.paragraphStyle] = _paragraphStyle
        _drawAttributes[NSAttributedStringKey.foregroundColor] = self.textColor
        
        _labelSize = label?.size(withAttributes: _drawAttributes) ?? CGSize.zero
        
        var size = CGSize()
        size.width = _labelSize.width + self.insets.left + self.insets.right
        size.height = _labelSize.height + self.insets.top + self.insets.bottom
        size.width = max(minimumSize.width, size.width)
        size.height = max(minimumSize.height, size.height)
        self.size = size
    }
}
