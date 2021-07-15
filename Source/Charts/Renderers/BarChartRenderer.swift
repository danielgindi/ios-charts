//
//  BarChartRenderer.swift
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

#if !os(OSX)
    import UIKit
#endif

open class BarChartRenderer: BarLineScatterCandleBubbleRenderer
{
    /// A nested array of elements ordered logically (i.e not in visual/drawing order) for use with VoiceOver
    ///
    /// Its use is apparent when there are multiple data sets, since we want to read bars in left to right order,
    /// irrespective of dataset. However, drawing is done per dataset, so using this array and then flattening it prevents us from needing to
    /// re-render for the sake of accessibility.
    ///
    /// In practise, its structure is:
    ///
    /// ````
    ///     [
    ///      [dataset1 element1, dataset2 element1],
    ///      [dataset1 element2, dataset2 element2],
    ///      [dataset1 element3, dataset2 element3]
    ///     ...
    ///     ]
    /// ````
    /// This is done to provide numerical inference across datasets to a screenreader user, in the same way that a sighted individual
    /// uses a multi-dataset bar chart.
    ///
    /// The ````internal```` specifier is to allow subclasses (HorizontalBar) to populate the same array
    internal lazy var accessibilityOrderedElements: [[NSUIAccessibilityElement]] = accessibilityCreateEmptyOrderedElements()

    private typealias Buffer = [CGRect]
    
    @objc open weak var dataProvider: BarChartDataProvider?
    
    @objc public init(dataProvider: BarChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    // [CGRect] per dataset
    private var _buffers = [Buffer]()
    
    open override func initBuffers()
    {
        guard let barData = dataProvider?.barData else { return _buffers.removeAll() }

        // Match buffers count to dataset count
        if _buffers.count != barData.count
        {
            while _buffers.count < barData.count
            {
                _buffers.append(Buffer())
            }
            while _buffers.count > barData.count
            {
                _buffers.removeLast()
            }
        }

        _buffers = zip(_buffers, barData).map { buffer, set -> Buffer in
            let set = set as! BarChartDataSetProtocol
            let size = set.entryCount * (set.isStacked ? set.stackSize : 1)
            return buffer.count == size
                ? buffer
                : Buffer(repeating: .zero, count: size)
        }
    }
    
    private func prepareBuffer(dataSet: BarChartDataSetProtocol, index: Int)
    {
        guard
            let dataProvider = dataProvider,
            let barData = dataProvider.barData
            else { return }
        
        let barWidthHalf = CGFloat(barData.barWidth / 2.0)
    
        var bufferIndex = 0
        let containsStacks = dataSet.isStacked
        
        let isInverted = dataProvider.isInverted(axis: dataSet.axisDependency)
        let phaseY = CGFloat(animator.phaseY)

        for i in (0..<dataSet.entryCount).clamped(to: 0..<Int(ceil(Double(dataSet.entryCount) * animator.phaseX)))
        {
            guard let e = dataSet.entryForIndex(i) as? BarChartDataEntry else { continue }

            let x = CGFloat(e.x)
            let left = x - barWidthHalf
            let right = x + barWidthHalf

            var y = e.y

            if containsStacks, let vals = e.yValues
            {
                var posY = 0.0
                var negY = -e.negativeSum
                var yStart = 0.0
                
                // fill the stack
                for value in vals
                {
                    if value == 0.0 && (posY == 0.0 || negY == 0.0)
                    {
                        // Take care of the situation of a 0.0 value, which overlaps a non-zero bar
                        y = value
                        yStart = y
                    }
                    else if value >= 0.0
                    {
                        y = posY
                        yStart = posY + value
                        posY = yStart
                    }
                    else
                    {
                        y = negY
                        yStart = negY + abs(value)
                        negY += abs(value)
                    }
                    
                    var top = isInverted
                        ? (y <= yStart ? CGFloat(y) : CGFloat(yStart))
                        : (y >= yStart ? CGFloat(y) : CGFloat(yStart))
                    var bottom = isInverted
                        ? (y >= yStart ? CGFloat(y) : CGFloat(yStart))
                        : (y <= yStart ? CGFloat(y) : CGFloat(yStart))
                    
                    // multiply the height of the rect with the phase
                    top *= phaseY
                    bottom *= phaseY

                    let barRect = CGRect(x: left, y: top,
                                         width: right - left,
                                         height: bottom - top)
                    _buffers[index][bufferIndex] = barRect
                    bufferIndex += 1
                }
            }
            else
            {
                var top = isInverted
                    ? (y <= 0.0 ? CGFloat(y) : 0)
                    : (y >= 0.0 ? CGFloat(y) : 0)
                var bottom = isInverted
                    ? (y >= 0.0 ? CGFloat(y) : 0)
                    : (y <= 0.0 ? CGFloat(y) : 0)
                
                /* When drawing each bar, the renderer actually draws each bar from 0 to the required value.
                 * This drawn bar is then clipped to the visible chart rect in BarLineChartViewBase's draw(rect:) using clipDataToContent.
                 * While this works fine when calculating the bar rects for drawing, it causes the accessibilityFrames to be oversized in some cases.
                 * This offset attempts to undo that unnecessary drawing when calculating barRects
                 *
                 * +---------------------------------------------------------------+---------------------------------------------------------------+
                 * |      Situation 1:  (!inverted && y >= 0)                      |      Situation 3:  (inverted && y >= 0)                       |
                 * |                                                               |                                                               |
                 * |        y ->           +--+       <- top                       |        0 -> ---+--+---+--+------   <- top                     |
                 * |                       |//|        } topOffset = y - max       |                |  |   |//|          } topOffset = min         |
                 * |      max -> +---------+--+----+  <- top - topOffset           |      min -> +--+--+---+--+----+    <- top + topOffset         |
                 * |             |  +--+   |//|    |                               |             |  |  |   |//|    |                               |
                 * |             |  |  |   |//|    |                               |             |  +--+   |//|    |                               |
                 * |             |  |  |   |//|    |                               |             |         |//|    |                               |
                 * |      min -> +--+--+---+--+----+  <- bottom + bottomOffset     |      max -> +---------+--+----+    <- bottom - bottomOffset   |
                 * |                |  |   |//|        } bottomOffset = min        |                       |//|          } bottomOffset = y - max  |
                 * |        0 -> ---+--+---+--+-----  <- bottom                    |        y ->           +--+         <- bottom                  |
                 * |                                                               |                                                               |
                 * +---------------------------------------------------------------+---------------------------------------------------------------+
                 * |      Situation 2:  (!inverted && y < 0)                       |      Situation 4:  (inverted && y < 0)                        |
                 * |                                                               |                                                               |
                 * |        0 -> ---+--+---+--+-----   <- top                      |        y ->           +--+         <- top                     |
                 * |                |  |   |//|         } topOffset = -max         |                       |//|          } topOffset = min - y     |
                 * |      max -> +--+--+---+--+----+   <- top - topOffset          |      min -> +---------+--+----+    <- top + topOffset         |
                 * |             |  |  |   |//|    |                               |             |  +--+   |//|    |                               |
                 * |             |  +--+   |//|    |                               |             |  |  |   |//|    |                               |
                 * |             |         |//|    |                               |             |  |  |   |//|    |                               |
                 * |      min -> +---------+--+----+   <- bottom + bottomOffset    |      max -> +--+--+---+--+----+    <- bottom - bottomOffset   |
                 * |                       |//|         } bottomOffset = min - y   |                |  |   |//|          } bottomOffset = -max     |
                 * |        y ->           +--+        <- bottom                   |        0 -> ---+--+---+--+-------  <- bottom                  |
                 * |                                                               |                                                               |
                 * +---------------------------------------------------------------+---------------------------------------------------------------+
                 */
                var topOffset: CGFloat = 0.0
                var bottomOffset: CGFloat = 0.0
                if let offsetView = dataProvider as? BarChartView
                {
                    let offsetAxis = offsetView.getAxis(dataSet.axisDependency)
                    if y >= 0
                    {
                        // situation 1
                        if offsetAxis.axisMaximum < y
                        {
                            topOffset = CGFloat(y - offsetAxis.axisMaximum)
                        }
                        if offsetAxis.axisMinimum > 0
                        {
                            bottomOffset = CGFloat(offsetAxis.axisMinimum)
                        }
                    }
                    else // y < 0
                    {
                        //situation 2
                        if offsetAxis.axisMaximum < 0
                        {
                            topOffset = CGFloat(offsetAxis.axisMaximum * -1)
                        }
                        if offsetAxis.axisMinimum > y
                        {
                            bottomOffset = CGFloat(offsetAxis.axisMinimum - y)
                        }
                    }
                    if isInverted
                    {
                        // situation 3 and 4
                        // exchange topOffset/bottomOffset based on 1 and 2
                        // see diagram above
                        (topOffset, bottomOffset) = (bottomOffset, topOffset)
                    }
                }
                //apply offset
                top = isInverted ? top + topOffset : top - topOffset
                bottom = isInverted ? bottom - bottomOffset : bottom + bottomOffset

                // multiply the height of the rect with the phase
                // explicitly add 0 + topOffset to indicate this is changed after adding accessibility support (#3650, #3520)
                if top > 0 + topOffset
                {
                    top *= phaseY
                }
                else
                {
                    bottom *= phaseY
                }

                let barRect = CGRect(x: left, y: top,
                                     width: right - left,
                                     height: bottom - top)
                _buffers[index][bufferIndex] = barRect
                bufferIndex += 1
            }
        }
    }

    open override func drawData(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let barData = dataProvider.barData
            else { return }
        
        // If we redraw the data, remove and repopulate accessible elements to update label values and frames
        accessibleChartElements.removeAll()
        accessibilityOrderedElements = accessibilityCreateEmptyOrderedElements()

        // Make the chart header the first element in the accessible elements array
        if let chart = dataProvider as? BarChartView {
            let element = createAccessibleHeader(usingChart: chart,
                                                 andData: barData,
                                                 withDefaultDescription: "Bar Chart")
            accessibleChartElements.append(element)
        }

        // Populate logically ordered nested elements into accessibilityOrderedElements in drawDataSet()
        for i in barData.indices
        {
            guard let set = barData[i] as? BarChartDataSetProtocol else {
                fatalError("Datasets for BarChartRenderer must conform to IBarChartDataset")
            }

            guard set.isVisible else { continue }

            drawDataSet(context: context, dataSet: set, index: i)
        }

        // Merge nested ordered arrays into the single accessibleChartElements.
        accessibleChartElements.append(contentsOf: accessibilityOrderedElements.flatMap { $0 } )
        accessibilityPostLayoutChangedNotification()
    }

    private var _barShadowRectBuffer: CGRect = CGRect()
    
    @objc open func drawDataSet(context: CGContext, dataSet: BarChartDataSetProtocol, index: Int)
    {
        guard let dataProvider = dataProvider else { return }

        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)

        prepareBuffer(dataSet: dataSet, index: index)
        trans.rectValuesToPixel(&_buffers[index])
        
        let borderWidth = dataSet.barBorderWidth
        let borderColor = dataSet.barBorderColor
        let drawBorder = borderWidth > 0.0
        
        context.saveGState()
        defer { context.restoreGState() }
        
        // draw the bar shadow before the values
        if dataProvider.isDrawBarShadowEnabled
        {
            guard let barData = dataProvider.barData else { return }
            
            let barWidth = barData.barWidth
            let barWidthHalf = barWidth / 2.0
            var x: Double = 0.0

            let range = (0..<dataSet.entryCount).clamped(to: 0..<Int(ceil(Double(dataSet.entryCount) * animator.phaseX)))
            for i in range
            {
                guard let e = dataSet.entryForIndex(i) as? BarChartDataEntry else { continue }
                
                x = e.x
                
                _barShadowRectBuffer.origin.x = CGFloat(x - barWidthHalf)
                _barShadowRectBuffer.size.width = CGFloat(barWidth)
                
                trans.rectValueToPixel(&_barShadowRectBuffer)
                
                guard viewPortHandler.isInBoundsLeft(_barShadowRectBuffer.origin.x + _barShadowRectBuffer.size.width) else { continue }
                
                guard viewPortHandler.isInBoundsRight(_barShadowRectBuffer.origin.x) else { break }
                
                _barShadowRectBuffer.origin.y = viewPortHandler.contentTop
                _barShadowRectBuffer.size.height = viewPortHandler.contentHeight
                
                context.setFillColor(dataSet.barShadowColor.cgColor)
                context.fill(_barShadowRectBuffer)
            }
        }

        let buffer = _buffers[index]
        
        // draw the bar shadow before the values
        if dataProvider.isDrawBarShadowEnabled
        {
            for barRect in buffer where viewPortHandler.isInBoundsLeft(barRect.origin.x + barRect.size.width)
            {
                guard viewPortHandler.isInBoundsRight(barRect.origin.x) else { break }

                context.setFillColor(dataSet.barShadowColor.cgColor)
                context.fill(barRect)
            }
        }
        
        let isSingleColor = dataSet.colors.count == 1
        
        if isSingleColor
        {
            context.setFillColor(dataSet.color(atIndex: 0).cgColor)
        }
        
        // In case the chart is stacked, we need to accomodate individual bars within accessibilityOrdereredElements
        let isStacked = dataSet.isStacked
        let stackSize = isStacked ? dataSet.stackSize : 1

        for j in buffer.indices
        {
            let barRect = buffer[j]
            
            guard viewPortHandler.isInBoundsLeft(barRect.origin.x + barRect.size.width) else { continue }
            guard viewPortHandler.isInBoundsRight(barRect.origin.x) else { break }

            if !isSingleColor
            {
                // Set the color for the currently drawn value. If the index is out of bounds, reuse colors.
                context.setFillColor(dataSet.color(atIndex: j).cgColor)
            }
            
            context.fill(barRect)
            
            if drawBorder
            {
                context.setStrokeColor(borderColor.cgColor)
                context.setLineWidth(borderWidth)
                context.stroke(barRect)
            }

            // Create and append the corresponding accessibility element to accessibilityOrderedElements
            if let chart = dataProvider as? BarChartView
            {
                let element = createAccessibleElement(
                    withIndex: j,
                    container: chart,
                    dataSet: dataSet,
                    dataSetIndex: index,
                    stackSize: stackSize
                ) { (element) in
                    element.accessibilityFrame = barRect
                }

                accessibilityOrderedElements[j/stackSize].append(element)
            }
        }
    }
    
    open func prepareBarHighlight(
        x: Double,
          y1: Double,
          y2: Double,
          barWidthHalf: Double,
          trans: Transformer,
          rect: inout CGRect)
    {
        let left = x - barWidthHalf
        let right = x + barWidthHalf
        let top = y1
        let bottom = y2
        
        rect.origin.x = CGFloat(left)
        rect.origin.y = CGFloat(top)
        rect.size.width = CGFloat(right - left)
        rect.size.height = CGFloat(bottom - top)
        
        trans.rectValueToPixel(&rect, phaseY: animator.phaseY )
    }

    open override func drawValues(context: CGContext)
    {
        // if values are drawn
        if isDrawingValuesAllowed(dataProvider: dataProvider)
        {
            guard
                let dataProvider = dataProvider,
                let barData = dataProvider.barData
                else { return }

            let valueOffsetPlus: CGFloat = 4.5
            var posOffset: CGFloat
            var negOffset: CGFloat
            let drawValueAboveBar = dataProvider.isDrawValueAboveBarEnabled
            
            for dataSetIndex in barData.indices
            {
                guard
                    let dataSet = barData[dataSetIndex] as? BarChartDataSetProtocol,
                    shouldDrawValues(forDataSet: dataSet)
                    else { continue }
                
                let angleRadians = dataSet.valueLabelAngle.DEG2RAD
                
                let isInverted = dataProvider.isInverted(axis: dataSet.axisDependency)
                
                // calculate the correct offset depending on the draw position of the value
                let valueFont = dataSet.valueFont
                let valueTextHeight = valueFont.lineHeight
                posOffset = (drawValueAboveBar ? -(valueTextHeight + valueOffsetPlus) : valueOffsetPlus)
                negOffset = (drawValueAboveBar ? valueOffsetPlus : -(valueTextHeight + valueOffsetPlus))
                
                if isInverted
                {
                    posOffset = -posOffset - valueTextHeight
                    negOffset = -negOffset - valueTextHeight
                }
                
                let buffer = _buffers[dataSetIndex]
                
                let formatter = dataSet.valueFormatter
                
                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                
                let phaseY = animator.phaseY
                
                let iconsOffset = dataSet.iconsOffset
        
                // if only single values are drawn (sum)
                if !dataSet.isStacked
                {
                    let range = 0 ..< Int(ceil(Double(dataSet.entryCount) * animator.phaseX))
                    for j in range
                    {
                        guard let e = dataSet.entryForIndex(j) as? BarChartDataEntry else { continue }
                        
                        let rect = buffer[j]
                        
                        let x = rect.origin.x + rect.size.width / 2.0
                        
                        guard viewPortHandler.isInBoundsRight(x) else { break }
                        
                        guard viewPortHandler.isInBoundsY(rect.origin.y),
                            viewPortHandler.isInBoundsLeft(x)
                            else { continue }
                        
                        let val = e.y
                        
                        if dataSet.isDrawValuesEnabled
                        {
                            drawValue(
                                context: context,
                                value: formatter.stringForValue(
                                    val,
                                    entry: e,
                                    dataSetIndex: dataSetIndex,
                                    viewPortHandler: viewPortHandler),
                                xPos: x,
                                yPos: val >= 0.0
                                    ? (rect.origin.y + posOffset)
                                    : (rect.origin.y + rect.size.height + negOffset),
                                font: valueFont,
                                align: .center,
                                color: dataSet.valueTextColorAt(j),
                                anchor: CGPoint(x: 0.5, y: 0.5),
                                angleRadians: angleRadians)
                        }
                        
                        if let icon = e.icon, dataSet.isDrawIconsEnabled
                        {
                            var px = x
                            var py = val >= 0.0
                                ? (rect.origin.y + posOffset)
                                : (rect.origin.y + rect.size.height + negOffset)
                            
                            px += iconsOffset.x
                            py += iconsOffset.y
                            
                            context.drawImage(icon,
                                              atCenter: CGPoint(x: px, y: py),
                                              size: icon.size)
                        }
                        
                    }
                }
                else
                {
                    // if we have stacks
                    
                    var bufferIndex = 0
                    let lastIndex = ceil(Double(dataSet.entryCount) * animator.phaseX)

                    for index in 0 ..< Int(lastIndex)
                    {
                        guard let e = dataSet.entryForIndex(index) as? BarChartDataEntry else { continue }
                        
                        let vals = e.yValues
                        
                        let rect = buffer[bufferIndex]
                        
                        let x = rect.origin.x + rect.size.width / 2.0
                        
                        // we still draw stacked bars, but there is one non-stacked in between
                        if let values = vals
                        {
                            // draw stack values
                            var transformed = [CGPoint]()

                            var posY = 0.0
                            var negY = -e.negativeSum

                            for value in values
                            {
                                let y: Double
                                
                                if value == 0.0 && (posY == 0.0 || negY == 0.0)
                                {
                                    // Take care of the situation of a 0.0 value, which overlaps a non-zero bar
                                    y = value
                                }
                                else if value >= 0.0
                                {
                                    posY += value
                                    y = posY
                                }
                                else
                                {
                                    y = negY
                                    negY -= value
                                }

                                transformed.append(CGPoint(x: 0.0, y: CGFloat(y * phaseY)))
                            }

                            trans.pointValuesToPixel(&transformed)
                            
                            for k in 0 ..< transformed.count
                            {
                                let drawBelow = (values[k] == 0.0 && negY == 0.0 && posY > 0.0) || values[k] < 0.0
                                let y = transformed[k].y + (drawBelow ? negOffset : posOffset)

                                guard viewPortHandler.isInBoundsRight(x) else { break }
                                guard viewPortHandler.isInBoundsY(y),
                                    viewPortHandler.isInBoundsLeft(x)
                                    else { continue }

                                if dataSet.isDrawValuesEnabled
                                {
                                    // Check that value won't write on top of another value above the bar
                                    if drawValueAboveBar && k > 0 && values[k - 1] != 0 &&
                                        ((transformed[k - 1].y - transformed[k].y + posOffset) < 0)
                                    {
                                        continue
                                    }
                                    
                                    // Ensure that the value is contained within the bar
                                    if !drawValueAboveBar {
                                        if k > 0 {
                                            if ((transformed[k - 1].y - transformed[k].y) + negOffset) < 0 {
                                                continue
                                            }
                                        } else {
                                            if (transformed[k].y + negOffset) < 0 {
                                                continue
                                            }
                                        }
                                    }
                                    
                                    if values[k] != 0 {
                                        drawValue(
                                            context: context,
                                            value: formatter.stringForValue(
                                                values[k],
                                                entry: e,
                                                dataSetIndex: dataSetIndex,
                                                viewPortHandler: viewPortHandler),
                                            xPos: x,
                                            yPos: y,
                                            font: valueFont,
                                            align: .center,
                                            color: dataSet.valueTextColorAt(index),
                                            anchor: CGPoint(x: 0.5, y: 0.5),
                                            angleRadians: angleRadians)
                                                                        
                                    }
                                }

                                if let icon = e.icon, dataSet.isDrawIconsEnabled
                                {
                                    context.drawImage(icon,
                                                      atCenter: CGPoint(x: x + iconsOffset.x,
                                                                      y: y + iconsOffset.y),
                                                      size: icon.size)
                                }
                            }
                        }
                        else
                        {
                            guard viewPortHandler.isInBoundsRight(x) else { break }
                            guard viewPortHandler.isInBoundsY(rect.origin.y),
                                viewPortHandler.isInBoundsLeft(x) else { continue }

                            if dataSet.isDrawValuesEnabled
                            {
                                drawValue(
                                    context: context,
                                    value: formatter.stringForValue(
                                        e.y,
                                        entry: e,
                                        dataSetIndex: dataSetIndex,
                                        viewPortHandler: viewPortHandler),
                                    xPos: x,
                                    yPos: rect.origin.y +
                                        (e.y >= 0 ? posOffset : negOffset),
                                    font: valueFont,
                                    align: .center,
                                    color: dataSet.valueTextColorAt(index),
                                    anchor: CGPoint(x: 0.5, y: 0.5),
                                    angleRadians: angleRadians)
                            }
                            
                            if let icon = e.icon, dataSet.isDrawIconsEnabled
                            {
                                var px = x
                                var py = rect.origin.y +
                                    (e.y >= 0 ? posOffset : negOffset)
                                
                                px += iconsOffset.x
                                py += iconsOffset.y
                                
                                context.drawImage(icon,
                                                  atCenter: CGPoint(x: px, y: py),
                                                  size: icon.size)
                            }
                        }

                        bufferIndex += vals?.count ?? 1
                    }
                }
            }
        }
    }
    
    /// Draws a value at the specified x and y position.
    @objc open func drawValue(context: CGContext, value: String, xPos: CGFloat, yPos: CGFloat, font: NSUIFont, align: TextAlignment, color: NSUIColor, anchor: CGPoint, angleRadians: CGFloat)
    {
        if (angleRadians == 0.0)
        {
            context.drawText(value, at: CGPoint(x: xPos, y: yPos), align: align, attributes: [.font: font, .foregroundColor: color])
        }
        else
        {
            // align left to center text with rotation
            context.drawText(value, at: CGPoint(x: xPos, y: yPos), align: align, anchor: anchor, angleRadians: angleRadians, attributes: [.font: font, .foregroundColor: color])
        }
    }

    
    open override func drawExtras(context: CGContext)
    {
        
    }
    
    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let dataProvider = dataProvider,
            let barData = dataProvider.barData
            else { return }
        
        context.saveGState()
        defer { context.restoreGState() }
        var barRect = CGRect()
        
        for high in indices
        {
            guard
                let set = barData[high.dataSetIndex] as? BarChartDataSetProtocol,
                set.isHighlightEnabled
                else { continue }
            
            if let e = set.entryForXValue(high.x, closestToY: high.y) as? BarChartDataEntry
            {
                guard isInBoundsX(entry: e, dataSet: set) else { continue }
                
                let trans = dataProvider.getTransformer(forAxis: set.axisDependency)
                
                context.setFillColor(set.highlightColor.cgColor)
                context.setAlpha(set.highlightAlpha)
                
                let isStack = high.stackIndex >= 0 && e.isStacked
                
                let y1: Double
                let y2: Double
                
                if isStack
                {
                    if dataProvider.isHighlightFullBarEnabled
                    {
                        y1 = e.positiveSum
                        y2 = -e.negativeSum
                    }
                    else
                    {
                        let range = e.ranges?[high.stackIndex]
                        
                        y1 = range?.from ?? 0.0
                        y2 = range?.to ?? 0.0
                    }
                }
                else
                {
                    y1 = e.y
                    y2 = 0.0
                }
                
                prepareBarHighlight(x: e.x, y1: y1, y2: y2, barWidthHalf: barData.barWidth / 2.0, trans: trans, rect: &barRect)
                
                setHighlightDrawPos(highlight: high, barRect: barRect)
                
                context.fill(barRect)
            }
        }
    }

    /// Sets the drawing position of the highlight object based on the given bar-rect.
    internal func setHighlightDrawPos(highlight high: Highlight, barRect: CGRect)
    {
        high.setDraw(x: barRect.midX, y: barRect.origin.y)
    }

    /// Creates a nested array of empty subarrays each of which will be populated with NSUIAccessibilityElements.
    /// This is marked internal to support HorizontalBarChartRenderer as well.
    internal func accessibilityCreateEmptyOrderedElements() -> [[NSUIAccessibilityElement]]
    {
        guard let chart = dataProvider as? BarChartView else { return [] }

        // Unlike Bubble & Line charts, here we use the maximum entry count to account for stacked bars
        let maxEntryCount = chart.data?.maxEntryCountSet?.entryCount ?? 0

        return Array(repeating: [NSUIAccessibilityElement](),
                     count: maxEntryCount)
    }

    /// Creates an NSUIAccessibleElement representing the smallest meaningful bar of the chart
    /// i.e. in case of a stacked chart, this returns each stack, not the combined bar.
    /// Note that it is marked internal to support subclass modification in the HorizontalBarChart.
    internal func createAccessibleElement(withIndex idx: Int,
                                          container: BarChartView,
                                          dataSet: BarChartDataSetProtocol,
                                          dataSetIndex: Int,
                                          stackSize: Int,
                                          modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement
    {
        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        let xAxis = container.xAxis

        guard let e = dataSet.entryForIndex(idx/stackSize) as? BarChartDataEntry else { return element }
        guard let dataProvider = dataProvider else { return element }

        // NOTE: The formatter can cause issues when the x-axis labels are consecutive ints.
        // i.e. due to the Double conversion, if there are more than one data set that are grouped,
        // there is the possibility of some labels being rounded up. A floor() might fix this, but seems to be a brute force solution.
        let label = xAxis.valueFormatter?.stringForValue(e.x, axis: xAxis) ?? "\(e.x)"

        var elementValueText = dataSet.valueFormatter.stringForValue(
            e.y,
            entry: e,
            dataSetIndex: dataSetIndex,
            viewPortHandler: viewPortHandler)

        if dataSet.isStacked, let vals = e.yValues
        {
            let labelCount = min(dataSet.colors.count, stackSize)

            let stackLabel: String?
            if (!dataSet.stackLabels.isEmpty && labelCount > 0) {
                let labelIndex = idx % labelCount
                stackLabel = dataSet.stackLabels.indices.contains(labelIndex) ? dataSet.stackLabels[labelIndex] : nil
            } else {
                stackLabel = nil
            }
            
            //Handles empty array of yValues
            let yValue = vals.isEmpty ? 0.0 : vals[idx % vals.count]

            elementValueText = dataSet.valueFormatter.stringForValue(
                yValue,
                entry: e,
                dataSetIndex: dataSetIndex,
                viewPortHandler: viewPortHandler)

            if let stackLabel = stackLabel {
                elementValueText = stackLabel + " \(elementValueText)"
            } else {
                elementValueText = "\(elementValueText)"
            }
        }

        let dataSetCount = dataProvider.barData?.dataSetCount ?? -1
        let doesContainMultipleDataSets = dataSetCount > 1

        element.accessibilityLabel = "\(doesContainMultipleDataSets ? (dataSet.label ?? "")  + ", " : "") \(label): \(elementValueText)"

        modifier(element)

        return element
    }
}

