//
//  LineChartRenderer.swift
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

open class LineChartRenderer: LineRadarRenderer
{
    // TODO: Currently, this nesting isn't necessary for LineCharts. However, it will make it much easier to add a custom rotor
    // that navigates between datasets.
    // NOTE: Unlike the other renderers, LineChartRenderer populates accessibleChartElements in drawCircles due to the nature of its drawing options.
    /// A nested array of elements ordered logically (i.e not in visual/drawing order) for use with VoiceOver.
    private lazy var accessibilityOrderedElements: [[NSUIAccessibilityElement]] = accessibilityCreateEmptyOrderedElements()

    @objc open weak var dataProvider: LineChartDataProvider?
    
    @objc public init(dataProvider: LineChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    open override func drawData(context: CGContext)
    {
        guard let lineData = dataProvider?.lineData else { return }

        let sets = lineData.dataSets as? [LineChartDataSet]
        assert(sets != nil, "Datasets for LineChartRenderer must conform to ILineChartDataSet")

        let drawDataSet = { self.drawDataSet(context: context, dataSet: $0) }
        sets!.lazy
            .filter(\.isVisible)
            .forEach(drawDataSet)
    }
    
    @objc open func drawDataSet(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        if dataSet.entryCount < 1
        {
            return
        }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        context.setLineWidth(dataSet.lineWidth)
        if dataSet.lineDashLengths != nil
        {
            context.setLineDash(phase: dataSet.lineDashPhase, lengths: dataSet.lineDashLengths!)
        }
        else
        {
            context.setLineDash(phase: 0.0, lengths: [])
        }
        
        context.setLineCap(dataSet.lineCapType)
        
        // if drawing cubic lines is enabled
        switch dataSet.mode
        {
        case .linear: fallthrough
        case .stepped:
            drawLinear(context: context, dataSet: dataSet)
            
        case .cubicBezier:
            drawCubicBezier(context: context, dataSet: dataSet)
            
        case .horizontalBezier:
            drawHorizontalBezier(context: context, dataSet: dataSet)
        }
    }
    
    @objc open func drawCubicBezier(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if _xBounds.range >= 1
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            
            // Take an extra point from the left, and an extra from the right.
            // That's because we need 4 points for a cubic bezier (cubic=4), otherwise we get lines moving and doing weird stuff on the edges of the chart.
            // So in the starting `prev` and `cur`, go -2, -1
            
            let firstIndex = _xBounds.min + 1
            
            var prevPrev: ChartDataEntry! = nil
            var prev: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 2, 0))
            var cur: ChartDataEntry! = dataSet.entryForIndex(max(firstIndex - 1, 0))
            var next: ChartDataEntry! = cur
            var nextIndex: Int = -1
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            
            for j in _xBounds.dropFirst()  // same as firstIndex
            {
                prevPrev = prev
                prev = cur
                cur = nextIndex == j ? next : dataSet.entryForIndex(j)
                
                nextIndex = j + 1 < dataSet.entryCount ? j + 1 : j
                next = dataSet.entryForIndex(nextIndex)
                
                if next == nil { break }
                
                prevDx = CGFloat(cur.x - prevPrev.x) * intensity
                prevDy = CGFloat(cur.y - prevPrev.y) * intensity
                curDx = CGFloat(next.x - prev.x) * intensity
                curDy = CGFloat(next.y - prev.y) * intensity
                
                cubicPath.addCurve(
                    to: CGPoint(
                        x: CGFloat(cur.x),
                        y: CGFloat(cur.y) * CGFloat(phaseY)),
                    control1: CGPoint(
                        x: CGFloat(prev.x) + prevDx,
                        y: (CGFloat(prev.y) + prevDy) * CGFloat(phaseY)),
                    control2: CGPoint(
                        x: CGFloat(cur.x) - curDx,
                        y: (CGFloat(cur.y) - curDy) * CGFloat(phaseY)),
                    transform: valueToPixelMatrix)
            }
        }
        
        context.saveGState()
        defer { context.restoreGState() }

        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = cubicPath.mutableCopy()
            
            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: _xBounds)
        }

        if dataSet.isDrawLineWithGradientEnabled
        {
            drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
        }
        else
        {
            renderLine(with: cubicPath, color: drawingColor, in: context, dataSet: dataSet)
        }
    }
    
    @objc open func drawHorizontalBezier(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        // the path for the cubic-spline
        let cubicPath = CGMutablePath()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        if _xBounds.range >= 1
        {
            var prev: ChartDataEntry! = dataSet.entryForIndex(_xBounds.min)
            var cur: ChartDataEntry! = prev
            
            if cur == nil { return }
            
            // let the spline start
            cubicPath.move(to: CGPoint(x: CGFloat(cur.x), y: CGFloat(cur.y * phaseY)), transform: valueToPixelMatrix)
            
            for j in _xBounds.dropFirst()
            {
                prev = cur
                cur = dataSet.entryForIndex(j)
                
                let cpx = CGFloat(prev.x + (cur.x - prev.x) / 2.0)
                
                cubicPath.addCurve(
                    to: CGPoint(
                        x: CGFloat(cur.x),
                        y: CGFloat(cur.y * phaseY)),
                    control1: CGPoint(
                        x: cpx,
                        y: CGFloat(prev.y * phaseY)),
                    control2: CGPoint(
                        x: cpx,
                        y: CGFloat(cur.y * phaseY)),
                    transform: valueToPixelMatrix)
            }
        }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        if dataSet.isDrawFilledEnabled
        {
            // Copy this path because we make changes to it
            let fillPath = cubicPath.mutableCopy()
            
            drawCubicFill(context: context, dataSet: dataSet, spline: fillPath!, matrix: valueToPixelMatrix, bounds: _xBounds)
        }

        if dataSet.isDrawLineWithGradientEnabled
        {
            drawGradientLine(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix)
        }
        else
        {
            renderLine(with: cubicPath, color: drawingColor, in: context, dataSet: dataSet)
        }
    }
    
    open func drawCubicFill(
        context: CGContext,
        dataSet: LineChartDataSetProtocol,
        spline: CGMutablePath,
        matrix: CGAffineTransform,
        bounds: XBounds)
    {
        guard
            let dataProvider = dataProvider
        else { return }
        
        if bounds.range <= 0
        {
            return
        }
        
        let fillMin = dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0

        var pt1 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min + bounds.range)?.x ?? 0.0), y: fillMin)
        var pt2 = CGPoint(x: CGFloat(dataSet.entryForIndex(bounds.min)?.x ?? 0.0), y: fillMin)
        pt1 = pt1.applying(matrix)
        pt2 = pt2.applying(matrix)
        
        spline.addLine(to: pt1)
        spline.addLine(to: pt2)
        spline.closeSubpath()
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: spline, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: spline, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    private var _lineSegments = [CGPoint](repeating: CGPoint(), count: 2)
    
    @objc open func drawLinear(context: CGContext, dataSet: LineChartDataSetProtocol)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let entryCount = dataSet.entryCount
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let pointsPerEntryPair = isDrawSteppedEnabled ? 4 : 2
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        // if drawing filled is enabled
        if dataSet.isDrawFilledEnabled && entryCount > 0
        {
            drawLinearFill(context: context, dataSet: dataSet, trans: trans, bounds: _xBounds)
        }
        
        context.saveGState()
        defer { context.restoreGState() }

        // more than 1 color
        if dataSet.colors.count > 1, !dataSet.isDrawLineWithGradientEnabled
        {
            if _lineSegments.count != pointsPerEntryPair
            {
                // Allocate once in correct size
                _lineSegments = [CGPoint](repeating: CGPoint(), count: pointsPerEntryPair)
            }

            for j in _xBounds.dropLast()
            {
                var e: ChartDataEntry! = dataSet.entryForIndex(j)
                
                if e == nil { continue }
                
                _lineSegments[0].x = CGFloat(e.x)
                _lineSegments[0].y = CGFloat(e.y * phaseY)
                
                if j < _xBounds.max
                {
                    // TODO: remove the check.
                    // With the new XBounds iterator, j is always smaller than _xBounds.max
                    // Keeping this check for a while, if xBounds have no further breaking changes, it should be safe to remove the check
                    e = dataSet.entryForIndex(j + 1)
                    
                    if e == nil { break }
                    
                    if isDrawSteppedEnabled
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: _lineSegments[0].y)
                        _lineSegments[2] = _lineSegments[1]
                        _lineSegments[3] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                    else
                    {
                        _lineSegments[1] = CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY))
                    }
                }
                else
                {
                    _lineSegments[1] = _lineSegments[0]
                }

                _lineSegments = _lineSegments.map { $0.applying(valueToPixelMatrix) }

                if (!viewPortHandler.isInBoundsRight(_lineSegments[0].x))
                {
                    break
                }

                // Determine the start and end coordinates of the line, and make sure they differ.
                guard
                    let firstCoordinate = _lineSegments.first,
                    let lastCoordinate = _lineSegments.last,
                    firstCoordinate != lastCoordinate else { continue }
                
                // make sure the lines don't do shitty things outside bounds
                if !viewPortHandler.isInBoundsLeft(lastCoordinate.x) ||
                    !viewPortHandler.isInBoundsTop(max(firstCoordinate.y, lastCoordinate.y)) ||
                    !viewPortHandler.isInBoundsBottom(min(firstCoordinate.y, lastCoordinate.y))
                {
                    continue
                }
                
                renderLine(between: _lineSegments, color: dataSet.color(atIndex: j), in: context, dataSet: dataSet)
            }
        }
        else
        { // only one color per dataset
            guard dataSet.entryForIndex(_xBounds.min) != nil else {
                return
            }

            var firstPoint = true

            let path = CGMutablePath()
            for x in stride(from: _xBounds.min, through: _xBounds.range + _xBounds.min, by: 1)
            {
                guard let e1 = dataSet.entryForIndex(x == 0 ? 0 : (x - 1)) else { continue }
                guard let e2 = dataSet.entryForIndex(x) else { continue }
                
                let startPoint =
                    CGPoint(
                        x: CGFloat(e1.x),
                        y: CGFloat(e1.y * phaseY))
                    .applying(valueToPixelMatrix)
                
                if firstPoint
                {
                    path.move(to: startPoint)
                    firstPoint = false
                }
                else
                {
                    path.addLine(to: startPoint)
                }
                
                if isDrawSteppedEnabled
                {
                    let steppedPoint =
                        CGPoint(
                            x: CGFloat(e2.x),
                            y: CGFloat(e1.y * phaseY))
                        .applying(valueToPixelMatrix)
                    path.addLine(to: steppedPoint)
                }

                let endPoint =
                    CGPoint(
                        x: CGFloat(e2.x),
                        y: CGFloat(e2.y * phaseY))
                    .applying(valueToPixelMatrix)
                path.addLine(to: endPoint)
            }
            
            if !firstPoint
            {
                if dataSet.isDrawLineWithGradientEnabled {
                    drawGradientLine(context: context, dataSet: dataSet, spline: path, matrix: valueToPixelMatrix)
                } else {
                    renderLine(with: path, color: dataSet.color(atIndex: 0), in: context, dataSet: dataSet)
                }
            }
        }
    }
    
    open func drawLinearFill(context: CGContext, dataSet: LineChartDataSetProtocol, trans: Transformer, bounds: XBounds)
    {
        guard let dataProvider = dataProvider else { return }
        
        let filled = generateFilledPath(
            dataSet: dataSet,
            fillMin: dataSet.fillFormatter?.getFillLinePosition(dataSet: dataSet, dataProvider: dataProvider) ?? 0.0,
            bounds: bounds,
            matrix: trans.valueToPixelMatrix)
        
        if dataSet.fill != nil
        {
            drawFilledPath(context: context, path: filled, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
        }
        else
        {
            drawFilledPath(context: context, path: filled, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
        }
    }
    
    /// Generates the path that is used for filled drawing.
    private func generateFilledPath(dataSet: LineChartDataSetProtocol, fillMin: CGFloat, bounds: XBounds, matrix: CGAffineTransform) -> CGPath
    {
        let phaseY = animator.phaseY
        let isDrawSteppedEnabled = dataSet.mode == .stepped
        let matrix = matrix
        
        var e: ChartDataEntry!
        
        let filled = CGMutablePath()
        
        e = dataSet.entryForIndex(bounds.min)
        if e != nil
        {
            filled.move(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // create a new path
        for x in stride(from: (bounds.min + 1), through: bounds.range + bounds.min, by: 1)
        {
            guard let e = dataSet.entryForIndex(x) else { continue }
            
            if isDrawSteppedEnabled
            {
                guard let ePrev = dataSet.entryForIndex(x-1) else { continue }
                filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(ePrev.y * phaseY)), transform: matrix)
            }
            
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: CGFloat(e.y * phaseY)), transform: matrix)
        }
        
        // close up
        e = dataSet.entryForIndex(bounds.range + bounds.min)
        if e != nil
        {
            filled.addLine(to: CGPoint(x: CGFloat(e.x), y: fillMin), transform: matrix)
        }
        filled.closeSubpath()
        
        return filled
    }
    
    open override func drawValues(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData
        else { return }

        if isDrawingValuesAllowed(dataProvider: dataProvider)
        {
            let phaseY = animator.phaseY
            
            var pt = CGPoint()
            
            for i in lineData.indices
            {
                guard let
                        dataSet = lineData[i] as? LineChartDataSetProtocol,
                      shouldDrawValues(forDataSet: dataSet)
                else { continue }
                
                let valueFont = dataSet.valueFont
                
                let formatter = dataSet.valueFormatter
                
                let angleRadians = dataSet.valueLabelAngle.DEG2RAD
                
                let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
                let valueToPixelMatrix = trans.valueToPixelMatrix
                
                let iconsOffset = dataSet.iconsOffset
                
                // make sure the values do not interfear with the circles
                var valOffset = Int(dataSet.circleRadius * 1.75)
                
                if !dataSet.isDrawCirclesEnabled
                {
                    valOffset = valOffset / 2
                }
                
                _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)

                for j in _xBounds
                {
                    guard let e = dataSet.entryForIndex(j) else { break }
                    
                    pt.x = CGFloat(e.x)
                    pt.y = CGFloat(e.y * phaseY)
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
                        context.drawText(formatter.stringForValue(e.y,
                                                                  entry: e,
                                                                  dataSetIndex: i,
                                                                  viewPortHandler: viewPortHandler),
                                         at: CGPoint(x: pt.x,
                                                     y: pt.y - CGFloat(valOffset) - valueFont.lineHeight),
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
        drawCircles(context: context)
    }
    
    private func drawCircles(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData
        else { return }
        
        let phaseY = animator.phaseY
        
        var pt = CGPoint()
        var rect = CGRect()
        
        // If we redraw the data, remove and repopulate accessible elements to update label values and frames
        accessibleChartElements.removeAll()
        accessibilityOrderedElements = accessibilityCreateEmptyOrderedElements()

        // Make the chart header the first element in the accessible elements array
        if let chart = dataProvider as? LineChartView {
            let element = createAccessibleHeader(usingChart: chart,
                                                 andData: lineData,
                                                 withDefaultDescription: "Line Chart")
            accessibleChartElements.append(element)
        }

        context.saveGState()

        for i in lineData.indices
        {
            guard let dataSet = lineData[i] as? LineChartDataSetProtocol else { continue }

            // Skip Circles and Accessibility if not enabled,
            // reduces CPU significantly if not needed
            if !dataSet.isVisible || !dataSet.isDrawCirclesEnabled || dataSet.entryCount == 0
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
            
            let circleRadius = dataSet.circleRadius
            let circleDiameter = circleRadius * 2.0
            let circleHoleRadius = dataSet.circleHoleRadius
            let circleHoleDiameter = circleHoleRadius * 2.0
            
            let drawCircleHole = dataSet.isDrawCircleHoleEnabled &&
                circleHoleRadius < circleRadius &&
                circleHoleRadius > 0.0
            let drawTransparentCircleHole = drawCircleHole &&
                (dataSet.circleHoleColor == nil ||
                    dataSet.circleHoleColor == NSUIColor.clear)
            
            for j in _xBounds
            {
                guard let e = dataSet.entryForIndex(j) else { break }

                pt.x = CGFloat(e.x)
                pt.y = CGFloat(e.y * phaseY)
                pt = pt.applying(valueToPixelMatrix)
                
                if (!viewPortHandler.isInBoundsRight(pt.x))
                {
                    break
                }
                
                // make sure the circles don't do shitty things outside bounds
                if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y))
                {
                    continue
                }
                
                // Accessibility element geometry
                let scaleFactor: CGFloat = 3
                let accessibilityRect = CGRect(x: pt.x - (scaleFactor * circleRadius),
                                               y: pt.y - (scaleFactor * circleRadius),
                                               width: scaleFactor * circleDiameter,
                                               height: scaleFactor * circleDiameter)
                // Create and append the corresponding accessibility element to accessibilityOrderedElements
                if let chart = dataProvider as? LineChartView
                {
                    let element = createAccessibleElement(withIndex: j,
                                                          container: chart,
                                                          dataSet: dataSet,
                                                          dataSetIndex: i)
                    { (element) in
                        element.accessibilityFrame = accessibilityRect
                    }

                    accessibilityOrderedElements[i].append(element)
                }

                context.setFillColor(dataSet.getCircleColor(atIndex: j)!.cgColor)

                rect.origin.x = pt.x - circleRadius
                rect.origin.y = pt.y - circleRadius
                rect.size.width = circleDiameter
                rect.size.height = circleDiameter

                if drawTransparentCircleHole
                {
                    // Begin path for circle with hole
                    context.beginPath()
                    context.addEllipse(in: rect)
                    
                    // Cut hole in path
                    rect.origin.x = pt.x - circleHoleRadius
                    rect.origin.y = pt.y - circleHoleRadius
                    rect.size.width = circleHoleDiameter
                    rect.size.height = circleHoleDiameter
                    context.addEllipse(in: rect)
                    
                    // Fill in-between
                    context.fillPath(using: .evenOdd)
                }
                else
                {
                    context.fillEllipse(in: rect)
                    
                    if drawCircleHole
                    {
                        context.setFillColor(dataSet.circleHoleColor!.cgColor)

                        // The hole rect
                        rect.origin.x = pt.x - circleHoleRadius
                        rect.origin.y = pt.y - circleHoleRadius
                        rect.size.width = circleHoleDiameter
                        rect.size.height = circleHoleDiameter
                        
                        context.fillEllipse(in: rect)
                    }
                }
            }
        }
        
        context.restoreGState()

        // Merge nested ordered arrays into the single accessibleChartElements.
        accessibleChartElements.append(contentsOf: accessibilityOrderedElements.flatMap { $0 } )
        accessibilityPostLayoutChangedNotification()
    }
    
    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let dataProvider = dataProvider,
            let lineData = dataProvider.lineData
        else { return }
        
        let chartXMax = dataProvider.chartXMax
        
        context.saveGState()
        
        for high in indices
        {
            guard let set = lineData[high.dataSetIndex] as? LineChartDataSetProtocol,
                  set.isHighlightEnabled
            else { continue }
            
            guard let e = set.entryForXValue(high.x, closestToY: high.y) else { continue }
            
            if !isInBoundsX(entry: e, dataSet: set)
            {
                continue
            }

            context.setStrokeColor(set.highlightColor.cgColor)
            context.setLineWidth(set.highlightLineWidth)
            if set.highlightLineDashLengths != nil
            {
                context.setLineDash(phase: set.highlightLineDashPhase, lengths: set.highlightLineDashLengths!)
            }
            else
            {
                context.setLineDash(phase: 0.0, lengths: [])
            }
            
            let x = e.x // get the x-position
            let y = e.y * Double(animator.phaseY)
            
            if x > chartXMax * animator.phaseX
            {
                continue
            }
            
            let trans = dataProvider.getTransformer(forAxis: set.axisDependency)
            
            let pt = trans.pixelForValues(x: x, y: y)
            
            high.setDraw(pt: pt)
            
            // draw the lines
            drawHighlightLines(context: context, point: pt, set: set)
        }
        
        context.restoreGState()
    }

    func drawGradientLine(context: CGContext, dataSet: LineChartDataSetProtocol, spline: CGPath, matrix: CGAffineTransform)
    {
        guard let gradientPositions = dataSet.gradientPositions else
        {
            assertionFailure("Must set `gradientPositions if `dataSet.isDrawLineWithGradientEnabled` is true")
            return
        }

        // `insetBy` is applied since bounding box
        // doesn't take into account line width
        // so that peaks are trimmed since
        // gradient start and gradient end calculated wrong
        let boundingBox = spline.boundingBox
            .insetBy(dx: -dataSet.lineWidth / 2, dy: -dataSet.lineWidth / 2)

        guard !boundingBox.isNull, !boundingBox.isInfinite, !boundingBox.isEmpty else {
            return
        }

        let gradientStart = CGPoint(x: 0, y: boundingBox.minY)
        let gradientEnd = CGPoint(x: 0, y: boundingBox.maxY)
        let gradientColorComponents: [CGFloat] = dataSet.colors
            .reversed()
            .reduce(into: []) { (components, color) in
                guard let (r, g, b, a) = color.nsuirgba else {
                    return
                }
                components += [r, g, b, a]
            }
        let gradientLocations: [CGFloat] = gradientPositions.reversed()
            .map { (position) in
                let location = CGPoint(x: boundingBox.minX, y: position)
                    .applying(matrix)
                let normalizedLocation = (location.y - boundingBox.minY)
                    / (boundingBox.maxY - boundingBox.minY)
                return normalizedLocation.clamped(to: 0...1)
            }

        let baseColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
                colorSpace: baseColorSpace,
                colorComponents: gradientColorComponents,
                locations: gradientLocations,
                count: gradientLocations.count) else {
            return
        }

        context.saveGState()
        defer { context.restoreGState() }

        renderGradientLine(with: spline, linearGradient: gradient, startingAt: gradientStart, endingAt: gradientEnd, in: context, dataSet: dataSet)
    }
    
    /// Creates a nested array of empty subarrays each of which will be populated with NSUIAccessibilityElements.
    /// This is marked internal to support HorizontalBarChartRenderer as well.
    private func accessibilityCreateEmptyOrderedElements() -> [[NSUIAccessibilityElement]]
    {
        guard let chart = dataProvider as? LineChartView else { return [] }

        let dataSetCount = chart.lineData?.dataSetCount ?? 0

        return Array(repeating: [NSUIAccessibilityElement](),
                     count: dataSetCount)
    }

    /// Creates an NSUIAccessibleElement representing the smallest meaningful bar of the chart
    /// i.e. in case of a stacked chart, this returns each stack, not the combined bar.
    /// Note that it is marked internal to support subclass modification in the HorizontalBarChart.
    private func createAccessibleElement(withIndex idx: Int,
                                         container: LineChartView,
                                         dataSet: LineChartDataSetProtocol,
                                         dataSetIndex: Int,
                                         modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement
    {
        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        let xAxis = container.xAxis

        guard let e = dataSet.entryForIndex(idx) else { return element }
        guard let dataProvider = dataProvider else { return element }

        // NOTE: The formatter can cause issues when the x-axis labels are consecutive ints.
        // i.e. due to the Double conversion, if there are more than one data set that are grouped,
        // there is the possibility of some labels being rounded up. A floor() might fix this, but seems to be a brute force solution.
        let label = xAxis.valueFormatter?.stringForValue(e.x, axis: xAxis) ?? "\(e.x)"

        let elementValueText = dataSet.valueFormatter.stringForValue(e.y,
                                                                     entry: e,
                                                                     dataSetIndex: dataSetIndex,
                                                                     viewPortHandler: viewPortHandler)

        let dataSetCount = dataProvider.lineData?.dataSetCount ?? -1
        let doesContainMultipleDataSets = dataSetCount > 1

        element.accessibilityLabel = "\(doesContainMultipleDataSets ? (dataSet.label ?? "")  + ", " : "") \(label): \(elementValueText)"

        modifier(element)

        return element
    }
    
    // MARK: - Rendering override points -
    
    /// Render a line.
    ///
    /// - Parameters:
    ///   - path: the path that should be rendered.
    ///   - color: the color of the line.
    ///   - context: the drawing context.
    ///   - dataSet: the dataset that is being rendered.
    @objc open func renderLine(with path: CGPath, color: NSUIColor, in context: CGContext, dataSet: LineChartDataSetProtocol) {
        context.saveGState()
        context.beginPath()
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.strokePath()
        context.restoreGState()
    }

    /// Render a line with a gradient.
    ///
    /// - Parameters:
    ///   - path: the path that should be rendered.
    ///   - gradient: the gradient.
    ///   - startPoint: the gradient's start point.
    ///   - endPoint: the gradient's end point.
    ///   - context: the drawing context.
    ///   - dataSet: the dataset that is being rendered.
    @objc open func renderGradientLine(with path: CGPath,
                                       linearGradient gradient: CGGradient,
                                       startingAt startPoint: CGPoint,
                                       endingAt endPoint: CGPoint,
                                       in context: CGContext,
                                       dataSet: LineChartDataSetProtocol) {
        context.saveGState()
        context.beginPath()
        context.addPath(path)
        context.replacePathWithStrokedPath()
        context.clip()
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        context.restoreGState()
    }
    
    /// Render a line between points.
    ///
    /// - Parameters:
    ///   - points: the collection of points to draw the line between.
    ///   - color: the color of the line.
    ///   - context: the drawing context.
    ///   - dataSet: the dataset that is being rendered.
    @objc open func renderLine(between points: [CGPoint], color: NSUIColor, in context: CGContext, dataSet: LineChartDataSetProtocol) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.strokeLineSegments(between: points)
        context.restoreGState()
    }
}
