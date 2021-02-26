//
//  LegendRenderer.swift
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

@objc(ChartLegendRenderer)
open class LegendRenderer: NSObject, Renderer
{
    @objc public let viewPortHandler: ViewPortHandler

    /// the legend object this renderer renders
    @objc open var legend: Legend?

    @objc public init(viewPortHandler: ViewPortHandler, legend: Legend?)
    {
        self.viewPortHandler = viewPortHandler
        self.legend = legend

        super.init()
    }

    /// Prepares the legend and calculates all needed forms, labels and colors.
    @objc open func computeLegend(data: ChartData)
    {
        guard let legend = legend else { return }
        
        if !legend.isLegendCustom
        {
            var entries: [LegendEntry] = []
            
            // loop for building up the colors and labels used in the legend
            for dataSet in data
            {                
                let clrs: [NSUIColor] = dataSet.colors
                let entryCount = dataSet.entryCount
                
                // if we have a barchart with stacked bars
                if dataSet is BarChartDataSetProtocol &&
                    (dataSet as! BarChartDataSetProtocol).isStacked
                {
                    let bds = dataSet as! BarChartDataSetProtocol
                    let sLabels = bds.stackLabels
                    let minEntries = min(clrs.count, bds.stackSize)

                    for j in 0..<minEntries
                    {
                        let label: String?
                        if !sLabels.isEmpty && minEntries > 0
                        {
                            let labelIndex = j % minEntries
                            label = sLabels.indices.contains(labelIndex) ? sLabels[labelIndex] : nil
                        }
                        else
                        {
                            label = nil
                        }

                        let entry = LegendEntry(label: label)
                        entry.form = dataSet.form
                        entry.formSize = dataSet.formSize
                        entry.formLineWidth = dataSet.formLineWidth
                        entry.formLineDashPhase = dataSet.formLineDashPhase
                        entry.formLineDashLengths = dataSet.formLineDashLengths
                        entry.formColor = clrs[j]

                        entries.append(entry)
                    }
                    
                    if dataSet.label != nil
                    {
                        // add the legend description label
                        let entry = LegendEntry(label: dataSet.label)
                        entry.form = .none

                        entries.append(entry)
                    }
                }
                else if dataSet is PieChartDataSetProtocol
                {
                    let pds = dataSet as! PieChartDataSetProtocol
                    
                    for j in 0..<min(clrs.count, entryCount)
                    {
                        let entry = LegendEntry(label: (pds.entryForIndex(j) as? PieChartDataEntry)?.label)
                        entry.form = dataSet.form
                        entry.formSize = dataSet.formSize
                        entry.formLineWidth = dataSet.formLineWidth
                        entry.formLineDashPhase = dataSet.formLineDashPhase
                        entry.formLineDashLengths = dataSet.formLineDashLengths
                        entry.formColor = clrs[j]

                        entries.append(entry)
                    }
                    
                    if dataSet.label != nil
                    {
                        // add the legend description label
                        let entry = LegendEntry(label: dataSet.label)
                        entry.form = .none

                        entries.append(entry)
                    }
                }
                else if dataSet is CandleChartDataSetProtocol &&
                    (dataSet as! CandleChartDataSetProtocol).decreasingColor != nil
                {
                    let candleDataSet = dataSet as! CandleChartDataSetProtocol

                    let decreasingEntry = LegendEntry(label: nil)
                    decreasingEntry.form = dataSet.form
                    decreasingEntry.formSize = dataSet.formSize
                    decreasingEntry.formLineWidth = dataSet.formLineWidth
                    decreasingEntry.formLineDashPhase = dataSet.formLineDashPhase
                    decreasingEntry.formLineDashLengths = dataSet.formLineDashLengths
                    decreasingEntry.formColor = candleDataSet.decreasingColor

                    entries.append(decreasingEntry)

                    let increasingEntry = LegendEntry(label: dataSet.label)
                    increasingEntry.form = dataSet.form
                    increasingEntry.formSize = dataSet.formSize
                    increasingEntry.formLineWidth = dataSet.formLineWidth
                    increasingEntry.formLineDashPhase = dataSet.formLineDashPhase
                    increasingEntry.formLineDashLengths = dataSet.formLineDashLengths
                    increasingEntry.formColor = candleDataSet.increasingColor

                    entries.append(increasingEntry)
                }
                else
                { // all others
                    
                    for j in 0..<min(clrs.count, entryCount)
                    {
                        let label: String?
                        
                        // if multiple colors are set for a DataSet, group them
                        if j < clrs.count - 1 && j < entryCount - 1
                        {
                            label = nil
                        }
                        else
                        { // add label to the last entry
                            label = dataSet.label
                        }

                        let entry = LegendEntry(label: label)
                        entry.form = dataSet.form
                        entry.formSize = dataSet.formSize
                        entry.formLineWidth = dataSet.formLineWidth
                        entry.formLineDashPhase = dataSet.formLineDashPhase
                        entry.formLineDashLengths = dataSet.formLineDashLengths
                        entry.formColor = clrs[j]

                        entries.append(entry)
                    }
                }
            }
            
            legend.entries = entries + legend.extraEntries
        }
        
        // calculate all dimensions of the legend
        legend.calculateDimensions(labelFont: legend.font, viewPortHandler: viewPortHandler)
    }
    
    @objc open func renderLegend(context: CGContext)
    {
        guard let legend = legend else { return }
        
        if !legend.enabled
        {
            return
        }
        
        let labelFont = legend.font
        let labelTextColor = legend.textColor
        let labelLineHeight = labelFont.lineHeight
        let formYOffset = labelLineHeight / 2.0

        let entries = legend.entries
        
        let defaultFormSize = legend.formSize
        let formToTextSpace = legend.formToTextSpace
        let xEntrySpace = legend.xEntrySpace
        let yEntrySpace = legend.yEntrySpace
        
        let orientation = legend.orientation
        let horizontalAlignment = legend.horizontalAlignment
        let verticalAlignment = legend.verticalAlignment
        let direction = legend.direction

        // space between the entries
        let stackSpace = legend.stackSpace

        let yoffset = legend.yOffset
        let xoffset = legend.xOffset
        var originPosX: CGFloat = 0.0
        
        switch horizontalAlignment
        {
        case .left:
            
            if orientation == .vertical
            {
                originPosX = xoffset
            }
            else
            {
                originPosX = viewPortHandler.contentLeft + xoffset
            }
            
            if direction == .rightToLeft
            {
                originPosX += legend.neededWidth
            }
            
        case .right:
            
            if orientation == .vertical
            {
                originPosX = viewPortHandler.chartWidth - xoffset
            }
            else
            {
                originPosX = viewPortHandler.contentRight - xoffset
            }
            
            if direction == .leftToRight
            {
                originPosX -= legend.neededWidth
            }
            
        case .center:
            
            if orientation == .vertical
            {
                originPosX = viewPortHandler.chartWidth / 2.0
            }
            else
            {
                originPosX = viewPortHandler.contentLeft
                    + viewPortHandler.contentWidth / 2.0
            }
            
            originPosX += (direction == .leftToRight
                    ? +xoffset
                    : -xoffset)
            
            // Horizontally layed out legends do the center offset on a line basis,
            // So here we offset the vertical ones only.
            if orientation == .vertical
            {
                if direction == .leftToRight
                {
                    originPosX -= legend.neededWidth / 2.0 - xoffset
                }
                else
                {
                    originPosX += legend.neededWidth / 2.0 - xoffset
                }
            }
        }
        
        switch orientation
        {
        case .horizontal:
            
            let calculatedLineSizes = legend.calculatedLineSizes
            let calculatedLabelSizes = legend.calculatedLabelSizes
            let calculatedLabelBreakPoints = legend.calculatedLabelBreakPoints
            
            var posX: CGFloat = originPosX
            var posY: CGFloat
            
            switch verticalAlignment
            {
            case .top:
                posY = yoffset
                
            case .bottom:
                posY = viewPortHandler.chartHeight - yoffset - legend.neededHeight
                
            case .center:
                posY = (viewPortHandler.chartHeight - legend.neededHeight) / 2.0 + yoffset
            }
            
            var lineIndex: Int = 0
            
            for i in entries.indices
            {
                let e = entries[i]
                let drawingForm = e.form != .none
                let formSize = e.formSize.isNaN ? defaultFormSize : e.formSize
                
                if i < calculatedLabelBreakPoints.endIndex &&
                    calculatedLabelBreakPoints[i]
                {
                    posX = originPosX
                    posY += labelLineHeight + yEntrySpace
                }
                
                if posX == originPosX &&
                    horizontalAlignment == .center &&
                    lineIndex < calculatedLineSizes.endIndex
                {
                    posX += (direction == .rightToLeft
                        ? calculatedLineSizes[lineIndex].width
                        : -calculatedLineSizes[lineIndex].width) / 2.0
                    lineIndex += 1
                }
                
                let isStacked = e.label == nil // grouped forms have null labels
                
                if drawingForm
                {
                    if direction == .rightToLeft
                    {
                        posX -= formSize
                    }
                    
                    drawForm(
                        context: context,
                        x: posX,
                        y: posY + formYOffset,
                        entry: e,
                        legend: legend)
                    
                    if direction == .leftToRight
                    {
                        posX += formSize
                    }
                }
                
                if !isStacked
                {
                    if drawingForm
                    {
                        posX += direction == .rightToLeft ? -formToTextSpace : formToTextSpace
                    }
                    
                    if direction == .rightToLeft
                    {
                        posX -= calculatedLabelSizes[i].width
                    }
                    
                    drawLabel(
                        context: context,
                        x: posX,
                        y: posY,
                        label: e.label!,
                        font: labelFont,
                        textColor: e.labelColor ?? labelTextColor)
                    
                    if direction == .leftToRight
                    {
                        posX += calculatedLabelSizes[i].width
                    }
                    
                    posX += direction == .rightToLeft ? -xEntrySpace : xEntrySpace
                }
                else
                {
                    posX += direction == .rightToLeft ? -stackSpace : stackSpace
                }
            }
            
        case .vertical:
            
            // contains the stacked legend size in pixels
            var stack = CGFloat(0.0)
            var wasStacked = false
            
            var posY: CGFloat = 0.0
            
            switch verticalAlignment
            {
            case .top:
                posY = (horizontalAlignment == .center
                    ? 0.0
                    : viewPortHandler.contentTop)
                posY += yoffset
                
            case .bottom:
                posY = (horizontalAlignment == .center
                    ? viewPortHandler.chartHeight
                    : viewPortHandler.contentBottom)
                posY -= legend.neededHeight + yoffset
                
            case .center:
                
                posY = viewPortHandler.chartHeight / 2.0 - legend.neededHeight / 2.0 + legend.yOffset
            }
            
            for i in entries.indices
            {
                let e = entries[i]
                let drawingForm = e.form != .none
                let formSize = e.formSize.isNaN ? defaultFormSize : e.formSize
                
                var posX = originPosX
                
                if drawingForm
                {
                    if direction == .leftToRight
                    {
                        posX += stack
                    }
                    else
                    {
                        posX -= formSize - stack
                    }
                    
                    drawForm(
                        context: context,
                        x: posX,
                        y: posY + formYOffset,
                        entry: e,
                        legend: legend)
                    
                    if direction == .leftToRight
                    {
                        posX += formSize
                    }
                }
                
                if e.label != nil
                {
                    if drawingForm && !wasStacked
                    {
                        posX += direction == .leftToRight ? formToTextSpace : -formToTextSpace
                    }
                    else if wasStacked
                    {
                        posX = originPosX
                    }
                    
                    if direction == .rightToLeft
                    {
                        posX -= (e.label! as NSString).size(withAttributes: [.font: labelFont]).width
                    }
                    
                    if !wasStacked
                    {
                        drawLabel(context: context, x: posX, y: posY, label: e.label!, font: labelFont, textColor: e.labelColor ?? labelTextColor)
                    }
                    else
                    {
                        posY += labelLineHeight + yEntrySpace
                        drawLabel(context: context, x: posX, y: posY, label: e.label!, font: labelFont, textColor: e.labelColor ?? labelTextColor)
                    }
                    
                    // make a step down
                    posY += labelLineHeight + yEntrySpace
                    stack = 0.0
                }
                else
                {
                    stack += formSize + stackSpace
                    wasStacked = true
                }
            }
        }
    }

    private var _formLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    /// Draws the Legend-form at the given position with the color at the given index.
    @objc open func drawForm(
        context: CGContext,
        x: CGFloat,
        y: CGFloat,
        entry: LegendEntry,
        legend: Legend)
    {
        guard
            let formColor = entry.formColor,
            formColor != NSUIColor.clear
            else { return }
        
        var form = entry.form
        if form == .default
        {
            form = legend.form
        }
        
        let formSize = entry.formSize.isNaN ? legend.formSize : entry.formSize
        
        context.saveGState()
        defer { context.restoreGState() }
        
        switch form
        {
        case .none:
            // Do nothing
            break
            
        case .empty:
            // Do not draw, but keep space for the form
            break
            
        case .default: fallthrough
        case .circle:
            
            renderCircle(with: formColor,
                         for: CGRect(x: x, y: y - formSize / 2.0, width: formSize, height: formSize),
                         in: context,
                         entry: entry,
                         legend: legend)
            
        case .square:
            
            renderSquare(with: formColor,
                         for: CGRect(x: x, y: y - formSize / 2.0, width: formSize, height: formSize),
                         in: context,
                         entry: entry,
                         legend: legend)
            
        case .line:
            
            let formLineWidth = entry.formLineWidth.isNaN ? legend.formLineWidth : entry.formLineWidth
            let formLineDashPhase = entry.formLineDashPhase.isNaN ? legend.formLineDashPhase : entry.formLineDashPhase
            let formLineDashLengths = entry.formLineDashLengths == nil ? legend.formLineDashLengths : entry.formLineDashLengths

            _formLineSegmentsBuffer[0].x = x
            _formLineSegmentsBuffer[0].y = y
            _formLineSegmentsBuffer[1].x = x + formSize
            _formLineSegmentsBuffer[1].y = y
            
            var dashPhase: CGFloat = 0.0
            var dashLengths = [CGFloat]()
            
            if let formLineDashLengths = formLineDashLengths, !formLineDashLengths.isEmpty {
                dashPhase = formLineDashPhase
                dashLengths = formLineDashLengths
            }
            
            renderLine(with: formColor,
                       lineWidth: formLineWidth,
                       dashPhase: dashPhase,
                       dashLengths: dashLengths,
                       between: _formLineSegmentsBuffer,
                       in: context,
                       entry: entry,
                       legend: legend)
        }
    }

    /// Draws the provided label at the given position.
    @objc open func drawLabel(context: CGContext, x: CGFloat, y: CGFloat, label: String, font: NSUIFont, textColor: NSUIColor)
    {
        context.drawText(label, at: CGPoint(x: x, y: y), align: .left, attributes: [.font: font, .foregroundColor: textColor])
    }
    
    // MARK: - Rendering override points -
    
    /// Render a round legend.
    ///
    /// - Parameters:
    ///   - color: the fill color of the legend.
    ///   - rect: the rectangle for which to render the circle.
    ///   - context: the drawing context.
    ///   - entry: the legend entry.
    ///   - legend: the legend.
    @objc open func renderCircle(with color: NSUIColor, for rect: CGRect, in context: CGContext, entry: LegendEntry, legend: Legend) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        context.restoreGState()
    }
    
    /// Render a square legend
    ///
    /// - Parameters:
    ///   - color: the fill color of the legend.
    ///   - rect: the rectangle of the square to render.
    ///   - context: the drawing context.
    ///   - entry: the legend entry.
    ///   - legend: the legend.
    @objc open func renderSquare(with color: NSUIColor, for rect: CGRect, in context: CGContext, entry: LegendEntry, legend: Legend) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.fill(rect)
        context.restoreGState()
    }
    
    /// Render a line legend.
    ///
    /// - Parameters:
    ///   - color: the line color.
    ///   - lineWidth: the width of the line.
    ///   - dashPhase: the dash phase pattern for dashed lines.
    ///   - dashLengths: the pattern for dashed lines.
    ///   - between: stroke a sequence of line segments.
    ///   - context: the drawing context.
    ///   - entry: the legend entry.
    ///   - legend: the legend.
    @objc open func renderLine(with color: NSUIColor,
                               lineWidth: CGFloat,
                               dashPhase: CGFloat,
                               dashLengths: [CGFloat],
                               between: [CGPoint],
                               in context: CGContext,
                               entry: LegendEntry,
                               legend: Legend) {
        context.saveGState()
        context.setLineWidth(lineWidth)
        context.setLineDash(phase: dashPhase, lengths: dashLengths)
        context.setStrokeColor(color.cgColor)
        context.strokeLineSegments(between: _formLineSegmentsBuffer)
        context.restoreGState()
    }
}
