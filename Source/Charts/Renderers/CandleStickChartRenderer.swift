//
//  CandleStickChartRenderer.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

open class CandleStickChartRenderer: LineScatterCandleRadarRenderer
{
    @objc open weak var dataProvider: CandleChartDataProvider?
    
    @objc public init(dataProvider: CandleChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    open override func drawData(context: CGContext)
    {
        guard let dataProvider = dataProvider, let candleData = dataProvider.candleData else { return }

        // If we redraw the data, remove and repopulate accessible elements to update label values and frames
        accessibleChartElements.removeAll()

        // Make the chart header the first element in the accessible elements array
        if let chart = dataProvider as? CandleStickChartView {
            let element = createAccessibleHeader(usingChart: chart,
                                                 andData: candleData,
                                                 withDefaultDescription: "CandleStick Chart")
            accessibleChartElements.append(element)
        }

        for case let set as CandleChartDataSetProtocol in candleData where set.isVisible
        {
            drawDataSet(context: context, dataSet: set)
        }
    }
    
    private var _shadowPoints = [CGPoint](repeating: CGPoint(), count: 4)
    private var _rangePoints = [CGPoint](repeating: CGPoint(), count: 2)
    private var _openPoints = [CGPoint](repeating: CGPoint(), count: 2)
    private var _closePoints = [CGPoint](repeating: CGPoint(), count: 2)
    private var _bodyRect = CGRect()
    private var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
    
    @objc open func drawDataSet(context: CGContext, dataSet: CandleChartDataSetProtocol)
    {
        guard
            let dataProvider = dataProvider
            else { return }

        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        let barSpace = dataSet.barSpace
        let showCandleBar = dataSet.showCandleBar
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        context.saveGState()
        defer { context.restoreGState() }

        for j in _xBounds
        {
            // get the entry
            guard let e = dataSet.entryForIndex(j) as? CandleChartDataEntry else { continue }
            
            let xPos = e.x
            
            let open = e.open
            let close = e.close
            let high = e.high
            let low = e.low
            
            let doesContainMultipleDataSets = (dataProvider.candleData?.count ?? 1) > 1
            var accessibilityMovementDescription = "neutral"
            var accessibilityRect = CGRect(x: CGFloat(xPos) + 0.5 - barSpace,
                                           y: CGFloat(low * phaseY),
                                           width: (2 * barSpace) - 1.0,
                                           height: (CGFloat(abs(high - low) * phaseY)))
            trans.rectValueToPixel(&accessibilityRect)

            if showCandleBar
            {
                // calculate the shadow
                
                _shadowPoints[0].x = CGFloat(xPos)
                _shadowPoints[1].x = CGFloat(xPos)
                _shadowPoints[2].x = CGFloat(xPos)
                _shadowPoints[3].x = CGFloat(xPos)
                
                if open > close
                {
                    _shadowPoints[0].y = CGFloat(high * phaseY)
                    _shadowPoints[1].y = CGFloat(open * phaseY)
                    _shadowPoints[2].y = CGFloat(low * phaseY)
                    _shadowPoints[3].y = CGFloat(close * phaseY)
                }
                else if open < close
                {
                    _shadowPoints[0].y = CGFloat(high * phaseY)
                    _shadowPoints[1].y = CGFloat(close * phaseY)
                    _shadowPoints[2].y = CGFloat(low * phaseY)
                    _shadowPoints[3].y = CGFloat(open * phaseY)
                }
                else
                {
                    _shadowPoints[0].y = CGFloat(high * phaseY)
                    _shadowPoints[1].y = CGFloat(open * phaseY)
                    _shadowPoints[2].y = CGFloat(low * phaseY)
                    _shadowPoints[3].y = _shadowPoints[1].y
                }
                
                trans.pointValuesToPixel(&_shadowPoints)
                
                // draw the shadows
                
                var shadowColor: NSUIColor! = nil
                if dataSet.shadowColorSameAsCandle
                {
                    if open > close
                    {
                        shadowColor = dataSet.decreasingColor ?? dataSet.color(atIndex: j)
                    }
                    else if open < close
                    {
                        shadowColor = dataSet.increasingColor ?? dataSet.color(atIndex: j)
                    }
                    else
                    {
                        shadowColor = dataSet.neutralColor ?? dataSet.color(atIndex: j)
                    }
                }
                
                if shadowColor === nil
                {
                    shadowColor = dataSet.shadowColor ?? dataSet.color(atIndex: j)
                }

                // calculate the body
                
                _bodyRect.origin.x = CGFloat(xPos) - 0.5 + barSpace
                _bodyRect.origin.y = CGFloat(close * phaseY)
                _bodyRect.size.width = (CGFloat(xPos) + 0.5 - barSpace) - _bodyRect.origin.x
                _bodyRect.size.height = CGFloat(open * phaseY) - _bodyRect.origin.y
                
                trans.rectValueToPixel(&_bodyRect)
                
                // draw body differently for increasing and decreasing entry

                if open > close
                {
                    accessibilityMovementDescription = "decreasing"

                    let color = dataSet.decreasingColor ?? dataSet.color(atIndex: j)
                    
                    renderCandleStick(with: _bodyRect,
                                      color: color,
                                      filled: dataSet.isDecreasingFilled,
                                      shadowBetween: _shadowPoints,
                                      shadowColor: shadowColor,
                                      in: context,
                                      dataSet: dataSet)
                }
                else if open < close
                {
                    accessibilityMovementDescription = "increasing"

                    let color = dataSet.increasingColor ?? dataSet.color(atIndex: j)
                    
                    renderCandleStick(with: _bodyRect,
                                      color: color,
                                      filled: dataSet.isIncreasingFilled,
                                      shadowBetween: _shadowPoints,
                                      shadowColor: shadowColor,
                                      in: context,
                                      dataSet: dataSet)
                }
                else
                {
                    let color = dataSet.neutralColor ?? dataSet.color(atIndex: j)

                    renderCandleStick(with: _bodyRect,
                                      color: color,
                                      filled: false,
                                      shadowBetween: _shadowPoints,
                                      shadowColor: shadowColor,
                                      in: context,
                                      dataSet: dataSet)
                }
            }
            else
            {
                _rangePoints[0].x = CGFloat(xPos)
                _rangePoints[0].y = CGFloat(high * phaseY)
                _rangePoints[1].x = CGFloat(xPos)
                _rangePoints[1].y = CGFloat(low * phaseY)

                _openPoints[0].x = CGFloat(xPos) - 0.5 + barSpace
                _openPoints[0].y = CGFloat(open * phaseY)
                _openPoints[1].x = CGFloat(xPos)
                _openPoints[1].y = CGFloat(open * phaseY)

                _closePoints[0].x = CGFloat(xPos) + 0.5 - barSpace
                _closePoints[0].y = CGFloat(close * phaseY)
                _closePoints[1].x = CGFloat(xPos)
                _closePoints[1].y = CGFloat(close * phaseY)
                
                trans.pointValuesToPixel(&_rangePoints)
                trans.pointValuesToPixel(&_openPoints)
                trans.pointValuesToPixel(&_closePoints)
                
                // draw the ranges
                var barColor: NSUIColor! = nil

                if open > close
                {
                    accessibilityMovementDescription = "decreasing"
                    barColor = dataSet.decreasingColor ?? dataSet.color(atIndex: j)
                }
                else if open < close
                {
                    accessibilityMovementDescription = "increasing"
                    barColor = dataSet.increasingColor ?? dataSet.color(atIndex: j)
                }
                else
                {
                    barColor = dataSet.neutralColor ?? dataSet.color(atIndex: j)
                }

                renderBar(with: barColor, rangePoints: _rangePoints, openPoints: _openPoints, closedPoints: _closePoints, in: context, dataSet: dataSet)
            }

            let axElement = createAccessibleElement(withIndex: j,
                                                    container: dataProvider,
                                                    dataSet: dataSet)
            { (element) in
                element.accessibilityLabel = "\(doesContainMultipleDataSets ? "\(dataSet.label ?? "Dataset")" : "") " + "\(xPos) - \(accessibilityMovementDescription). low: \(low), high: \(high), opening: \(open), closing: \(close)"
                element.accessibilityFrame = accessibilityRect
            }

            accessibleChartElements.append(axElement)

        }

        // Post this notification to let VoiceOver account for the redrawn frames
        accessibilityPostLayoutChangedNotification()
    }
    
    open override func drawValues(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let candleData = dataProvider.candleData
            else { return }
        
        // if values are drawn
        if isDrawingValuesAllowed(dataProvider: dataProvider)
        {
            let phaseY = animator.phaseY
            
            var pt = CGPoint()
            
            for i in candleData.indices
            {
                guard let
                    dataSet = candleData[i] as? BarLineScatterCandleBubbleChartDataSetProtocol,
                    shouldDrawValues(forDataSet: dataSet)
                    else { continue }
                
                let valueFont = dataSet.valueFont
                
                let formatter = dataSet.valueFormatter
                
                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                let valueToPixelMatrix = trans.valueToPixelMatrix
                
                let iconsOffset = dataSet.iconsOffset
                
                let angleRadians = dataSet.valueLabelAngle.DEG2RAD
                
                _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
                
                let lineHeight = valueFont.lineHeight
                let yOffset: CGFloat = lineHeight + 5.0
                
                for j in _xBounds
                {
                    guard let e = dataSet.entryForIndex(j) as? CandleChartDataEntry else { break }
                    
                    pt.x = CGFloat(e.x)
                    pt.y = CGFloat(e.high * phaseY)
                    pt = pt.applying(valueToPixelMatrix)
                    
                    if (!viewPortHandler.isInBoundsRight(pt.x))
                    {
                        break
                    }
                    
                    if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y))
                    {
                        continue
                    }
                    
                    if dataSet.isDrawValuesEnabled
                    {
                        context.drawText(formatter.stringForValue(e.high,
                                                                  entry: e,
                                                                  dataSetIndex: i,
                                                                  viewPortHandler: viewPortHandler),
                                         at: CGPoint(x: pt.x,
                                                     y: pt.y - yOffset),
                                         align: .center,
                                         angleRadians: angleRadians,
                                         attributes: [.font: valueFont,
                                                      .foregroundColor: dataSet.valueTextColorAt(j)])
                    }
                    
                    if let icon = e.icon, dataSet.isDrawIconsEnabled
                    {
                        context.drawImage(icon,
                                          atCenter: CGPoint(x: pt.x + iconsOffset.x,
                                                          y: pt.y + iconsOffset.y),
                                          size: icon.size)
                    }
                }
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
    }
    
    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let dataProvider = dataProvider,
            let candleData = dataProvider.candleData
            else { return }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        for high in indices
        {
            guard
                let set = candleData[high.dataSetIndex] as? CandleChartDataSetProtocol,
                set.isHighlightEnabled
                else { continue }
            
            guard let e = set.entryForXValue(high.x, closestToY: high.y) as? CandleChartDataEntry else { continue }
            
            if !isInBoundsX(entry: e, dataSet: set)
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(forAxis: set.axisDependency)
            let lowValue = e.low * Double(animator.phaseY)
            let highValue = e.high * Double(animator.phaseY)
            let y = (lowValue + highValue) / 2.0
            
            let pt = trans.pixelForValues(x: e.x, y: y)
            
            high.setDraw(pt: pt)
            renderHighlight(high, at: pt, in: context, dataSet: set)
        }
    }

    private func createAccessibleElement(withIndex idx: Int,
                                         container: CandleChartDataProvider,
                                         dataSet: CandleChartDataSetProtocol,
                                         modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement {

        let element = NSUIAccessibilityElement(accessibilityContainer: container)

        // The modifier allows changing of traits and frame depending on highlight, rotation, etc
        modifier(element)

        return element
    }
    
    // MARK: - Rendering override points -
    
    /// Render a candle stick.
    ///
    /// - Parameters:
    ///   - rect: the rectangle of the body of the candlestick.
    ///   - color: the fill or stroke color of the body of the candlestick.
    ///   - shouldFill: whether the body should be filled or stroked.
    ///   - shadowPoints: the points that outline the shadow.
    ///   - shadowColor: the color of the shadow.
    ///   - context: the drawing context.
    ///   - dataSet: the dataset that is being rendered.
    @objc open func renderCandleStick(with rect: CGRect,
                                      color: NSUIColor,
                                      filled: Bool,
                                      shadowBetween shadowPoints: [CGPoint],
                                      shadowColor: NSUIColor,
                                      in context: CGContext,
                                      dataSet: CandleChartDataSetProtocol) {
        context.saveGState()
        
        // Render the shadow
        context.setStrokeColor(shadowColor.cgColor)
        context.setLineWidth(dataSet.shadowWidth)
        context.strokeLineSegments(between: shadowPoints)
        
        // Render the body
        if filled {
            context.setFillColor(color.cgColor)
            context.fill(rect)
        } else {
            context.setStrokeColor(color.cgColor)
            context.stroke(rect)
        }
        
        context.restoreGState()
    }

    /// Render a candle stick bar.
    ///
    /// - Parameters:
    ///   - color: the color of the bar.
    ///   - rangePoints: the points that represent range.
    ///   - openPoints: open points.
    ///   - closedPoints: closed points.
    ///   - context: the drawing context
    ///   - dataSet: the dataset that is being rendered.
    @objc open func renderBar(with color: NSUIColor,
                              rangePoints: [CGPoint],
                              openPoints: [CGPoint],
                              closedPoints: [CGPoint],
                              in context: CGContext,
                              dataSet: CandleChartDataSetProtocol) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.strokeLineSegments(between: rangePoints)
        context.strokeLineSegments(between: openPoints)
        context.strokeLineSegments(between: closedPoints)
        context.restoreGState()
    }
    
    /// Render highlight.
    ///
    /// - Parameters:
    ///   - highlight: the hightlight that is being rendered.
    ///   - point: where to render the highlight.
    ///   - context: the drawing context.
    ///   - dataSet: the dataset that is being rendered.
    @objc func renderHighlight(_ highlight: Highlight, at point: CGPoint, in context: CGContext, dataSet: CandleChartDataSetProtocol) {
        context.saveGState()
        context.setStrokeColor(dataSet.highlightColor.cgColor)
        context.setLineWidth(dataSet.highlightLineWidth)
        
        if let dashLengths = dataSet.highlightLineDashLengths {
            context.setLineDash(phase: dataSet.highlightLineDashPhase, lengths: dashLengths)
        }

        drawHighlightLines(context: context, point: point, set: dataSet)
        context.restoreGState()
    }
}
