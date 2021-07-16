//
//  BarLineScatterCandleBubbleRenderer.swift
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

@objc(BarLineScatterCandleBubbleChartRenderer)
open class BarLineScatterCandleBubbleRenderer: NSObject, DataRenderer
{
    public let viewPortHandler: ViewPortHandler

    public final var accessibleChartElements: [NSUIAccessibilityElement] = []

    public let animator: Animator

    internal var _xBounds = XBounds() // Reusable XBounds object
    
    public init(animator: Animator, viewPortHandler: ViewPortHandler)
    {
        self.viewPortHandler = viewPortHandler
        self.animator = animator

        super.init()
    }

    open func drawData(context: CGContext) { }

    open func drawValues(context: CGContext) { }

    open func drawExtras(context: CGContext) { }

    open func drawHighlighted(context: CGContext, indices: [Highlight]) { }

    /// Checks if the provided entry object is in bounds for drawing considering the current animation phase.
    internal func isInBoundsX(entry e: ChartDataEntry, dataSet: BarLineScatterCandleBubbleChartDataSetProtocol) -> Bool
    {
        let entryIndex = dataSet.entryIndex(entry: e)
        return Double(entryIndex) < Double(dataSet.entryCount) * animator.phaseX
    }

    /// Calculates and returns the x-bounds for the given DataSet in terms of index in their values array.
    /// This includes minimum and maximum visible x, as well as range.
    internal func xBounds(chart: BarLineScatterCandleBubbleChartDataProvider,
                          dataSet: BarLineScatterCandleBubbleChartDataSetProtocol,
                          animator: Animator?) -> XBounds
    {
        return XBounds(chart: chart, dataSet: dataSet, animator: animator)
    }
    
    /// - Returns: `true` if the DataSet values should be drawn, `false` if not.
    internal func shouldDrawValues(forDataSet set: ChartDataSetProtocol) -> Bool
    {
        return set.isVisible && (set.isDrawValuesEnabled || set.isDrawIconsEnabled)
    }

    open func initBuffers() { }

    open func isDrawingValuesAllowed(dataProvider: ChartDataProvider?) -> Bool
    {
        guard let data = dataProvider?.data else { return false }
        return data.entryCount < Int(CGFloat(dataProvider?.maxVisibleCount ?? 0) * viewPortHandler.scaleX)
    }

    /// Class representing the bounds of the current viewport in terms of indices in the values array of a DataSet.
    open class XBounds
    {
        /// minimum visible entry index
        open var min: Int = 0

        /// maximum visible entry index
        open var max: Int = 0

        /// range of visible entry indices
        open var range: Int = 0

        public init()
        {
            
        }
        
        public init(chart: BarLineScatterCandleBubbleChartDataProvider,
                    dataSet: BarLineScatterCandleBubbleChartDataSetProtocol,
                    animator: Animator?)
        {
            self.set(chart: chart, dataSet: dataSet, animator: animator)
        }
        
        /// Calculates the minimum and maximum x values as well as the range between them.
        open func set(chart: BarLineScatterCandleBubbleChartDataProvider,
                      dataSet: BarLineScatterCandleBubbleChartDataSetProtocol,
                      animator: Animator?)
        {
            let phaseX = Swift.max(0.0, Swift.min(1.0, animator?.phaseX ?? 1.0))
            
            let low = chart.lowestVisibleX > dataSet.xMin ? chart.lowestVisibleX : dataSet.xMin
            let high = chart.highestVisibleX > dataSet.xMax ? dataSet.xMax : chart.highestVisibleX
            
            let entryFrom = dataSet.entryForXValue(low, closestToY: .nan, rounding: .down)
            let entryTo = dataSet.entryForXValue(high, closestToY: .nan, rounding: .up)
            
            self.min = entryFrom == nil ? 0 : dataSet.entryIndex(entry: entryFrom!)
            self.max = entryTo == nil ? 0 : dataSet.entryIndex(entry: entryTo!)
            range = Int(Double(self.max - self.min) * phaseX)
        }
    }
    
    public func createAccessibleHeader(usingChart chart: ChartViewBase, andData data: ChartData, withDefaultDescription defaultDescription: String) -> NSUIAccessibilityElement {
        return AccessibleHeader.create(usingChart: chart, andData: data, withDefaultDescription: defaultDescription)
    }
}

extension BarLineScatterCandleBubbleRenderer.XBounds: RangeExpression {
    public func relative<C>(to collection: C) -> Swift.Range<Int>
        where C : Collection, Bound == C.Index
    {
        return Swift.Range<Int>(min...min + range)
    }

    public func contains(_ element: Int) -> Bool {
        return (min...min + range).contains(element)
    }
}

extension BarLineScatterCandleBubbleRenderer.XBounds: Sequence {
    public struct Iterator: IteratorProtocol {
        private var iterator: IndexingIterator<ClosedRange<Int>>
        
        fileprivate init(min: Int, max: Int) {
            self.iterator = (min...max).makeIterator()
        }
        
        public mutating func next() -> Int? {
            return self.iterator.next()
        }
    }
    
    public func makeIterator() -> Iterator {
        return Iterator(min: self.min, max: self.min + self.range)
    }
}

extension BarLineScatterCandleBubbleRenderer.XBounds: CustomDebugStringConvertible
{
    public var debugDescription: String
    {
        return "min:\(self.min), max:\(self.max), range:\(self.range)"
    }
}
