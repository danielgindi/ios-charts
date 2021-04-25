//
//  ChartData.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation

open class ChartData: NSObject, ExpressibleByArrayLiteral
{

    @objc public internal(set) var xMax = -Double.greatestFiniteMagnitude
    @objc public internal(set) var xMin = Double.greatestFiniteMagnitude
    @objc public internal(set) var yMax = -Double.greatestFiniteMagnitude
    @objc public internal(set) var yMin = Double.greatestFiniteMagnitude
    var leftAxisMax = -Double.greatestFiniteMagnitude
    var leftAxisMin = Double.greatestFiniteMagnitude
    var rightAxisMax = -Double.greatestFiniteMagnitude
    var rightAxisMin = Double.greatestFiniteMagnitude

    // MARK: - Accessibility
    
    /// When the data entry labels are generated identifiers, set this property to prepend a string before each identifier
    ///
    /// For example, if a label is "#3", settings this property to "Item" allows it to be spoken as "Item #3"
    @objc open var accessibilityEntryLabelPrefix: String?
    
    /// When the data entry value requires a unit, use this property to append the string representation of the unit to the value
    ///
    /// For example, if a value is "44.1", setting this property to "m" allows it to be spoken as "44.1 m"
    @objc open var accessibilityEntryLabelSuffix: String?
    
    /// If the data entry value is a count, set this to true to allow plurals and other grammatical changes
    /// **default**: false
    @objc open var accessibilityEntryLabelSuffixIsCount: Bool = false
    
    var _dataSets = [Element]()
    
    public override required init()
    {
        super.init()
    }

    public required init(arrayLiteral elements: Element...)
    {
        super.init()
        self.dataSets = elements
    }

    @objc public init(dataSets: [Element])
    {
        super.init()
        self.dataSets = dataSets
    }
    
    @objc public convenience init(dataSet: Element)
    {
        self.init(dataSets: [dataSet])
    }

    /// Call this method to let the ChartData know that the underlying data has changed.
    /// Calling this performs all necessary recalculations needed when the contained data has changed.
    @objc open func notifyDataChanged()
    {
        calcMinMax()
    }
    
    @objc open func calcMinMaxY(fromX: Double, toX: Double)
    {
        forEach { $0.calcMinMaxY(fromX: fromX, toX: toX) }
        
        // apply the new data
        calcMinMax()
    }
    
    /// calc minimum and maximum y value over all datasets
    @objc open func calcMinMax()
    {
        leftAxisMax = -.greatestFiniteMagnitude
        leftAxisMin = .greatestFiniteMagnitude
        rightAxisMax = -.greatestFiniteMagnitude
        rightAxisMin = .greatestFiniteMagnitude
        yMax = -.greatestFiniteMagnitude
        yMin = .greatestFiniteMagnitude
        xMax = -.greatestFiniteMagnitude
        xMin = .greatestFiniteMagnitude

        forEach { calcMinMax(dataSet: $0) }

        // left axis
        let firstLeft = getFirstLeft(dataSets: dataSets)
        
        if firstLeft !== nil
        {
            leftAxisMax = firstLeft!.yMax
            leftAxisMin = firstLeft!.yMin

            for dataSet in _dataSets where dataSet.axisDependency == .left
            {
                if dataSet.yMin < leftAxisMin
                {
                    leftAxisMin = dataSet.yMin
                }

                if dataSet.yMax > leftAxisMax
                {
                    leftAxisMax = dataSet.yMax
                }
            }
        }
        
        // right axis
        let firstRight = getFirstRight(dataSets: dataSets)
        
        if firstRight !== nil
        {
            rightAxisMax = firstRight!.yMax
            rightAxisMin = firstRight!.yMin
            
            for dataSet in _dataSets where dataSet.axisDependency == .right
            {
                if dataSet.yMin < rightAxisMin
                {
                    rightAxisMin = dataSet.yMin
                }

                if dataSet.yMax > rightAxisMax
                {
                    rightAxisMax = dataSet.yMax
                }
            }
        }
    }

    /// Adjusts the current minimum and maximum values based on the provided Entry object.
    @objc open func calcMinMax(entry e: ChartDataEntry, axis: YAxis.AxisDependency)
    {
        xMax = Swift.max(xMax, e.x)
        xMin = Swift.min(xMin, e.x)
        yMax = Swift.max(yMax, e.y)
        yMin = Swift.min(yMin, e.y)

        switch axis
        {
        case .left:
            leftAxisMax = Swift.max(leftAxisMax, e.y)
            leftAxisMin = Swift.min(leftAxisMin, e.y)

        case .right:
            rightAxisMax = Swift.max(rightAxisMax, e.y)
            rightAxisMin = Swift.min(rightAxisMin, e.y)
        }
    }
    
    /// Adjusts the minimum and maximum values based on the given DataSet.
    @objc open func calcMinMax(dataSet d: Element)
    {
        xMax = Swift.max(xMax, d.xMax)
        xMin = Swift.min(xMin, d.xMin)
        yMax = Swift.max(yMax, d.yMax)
        yMin = Swift.min(yMin, d.yMin)

        switch d.axisDependency
        {
        case .left:
            leftAxisMax = Swift.max(leftAxisMax, d.yMax)
            leftAxisMin = Swift.min(leftAxisMin, d.yMin)

        case .right:
            rightAxisMax = Swift.max(rightAxisMax, d.yMax)
            rightAxisMin = Swift.min(rightAxisMin, d.yMin)
        }
    }
    
    /// The number of LineDataSets this object contains
    // exists only for objc compatibility
    @objc open var dataSetCount: Int
    {
        return dataSets.count
    }

    @objc open func getYMin(axis: YAxis.AxisDependency) -> Double
    {
        // TODO: Why does it make sense to return the other axisMin if there is none for the one requested?
        switch axis
        {
        case .left:
            if leftAxisMin == .greatestFiniteMagnitude
            {
                return rightAxisMin
            }
            else
            {
                return leftAxisMin
            }

        case .right:
            if rightAxisMin == .greatestFiniteMagnitude
            {
                return leftAxisMin
            }
            else
            {
                return rightAxisMin
            }
        }
    }
    
    @objc open func getYMax(axis: YAxis.AxisDependency) -> Double
    {
        if axis == .left
        {
            if leftAxisMax == -.greatestFiniteMagnitude
            {
                return rightAxisMax
            }
            else
            {
                return leftAxisMax
            }
        }
        else
        {
            if rightAxisMax == -.greatestFiniteMagnitude
            {
                return leftAxisMax
            }
            else
            {
                return rightAxisMax
            }
        }
    }
    
    /// All DataSet objects this ChartData object holds.
    @objc open var dataSets: [Element]
    {
        get
        {
            return _dataSets
        }
        set
        {
            _dataSets = newValue
            notifyDataChanged()
        }
    }

    /// Get the Entry for a corresponding highlight object
    ///
    /// - Parameters:
    ///   - highlight:
    /// - Returns: The entry that is highlighted
    @objc open func entry(for highlight: Highlight) -> ChartDataEntry?
    {
        guard highlight.dataSetIndex < dataSets.endIndex else { return nil }
        return self[highlight.dataSetIndex].entryForXValue(highlight.x, closestToY: highlight.y)
    }
    
    /// **IMPORTANT: This method does calculations at runtime. Use with care in performance critical situations.**
    ///
    /// - Parameters:
    ///   - label:
    ///   - ignorecase:
    /// - Returns: The DataSet Object with the given label. Sensitive or not.
    @objc open func dataSet(forLabel label: String, ignorecase: Bool) -> Element?
    {
        guard let index = index(forLabel: label, ignoreCase: ignorecase) else { return nil }
        return self[index]
    }
    
    @objc(dataSetAtIndex:)
    open func dataSet(at index: Index) -> Element?
    {
        guard dataSets.indices.contains(index) else { return nil }
        return self[index]
    }

    /// Removes the given DataSet from this data object.
    /// Also recalculates all minimum and maximum values.
    ///
    /// - Returns: `true` if a DataSet was removed, `false` ifno DataSet could be removed.
    @objc @discardableResult open func removeDataSet(_ dataSet: Element) -> Element?
    {
        guard let index = firstIndex(where: { $0 === dataSet }) else { return nil }
        return remove(at: index)
    }

    /// Adds an Entry to the DataSet at the specified index. Entries are added to the end of the list.
    @objc(addEntry:dataSetIndex:)
    open func appendEntry(_ e: ChartDataEntry, toDataSet dataSetIndex: Index)
    {
        guard dataSets.indices.contains(dataSetIndex) else {
            return print("ChartData.addEntry() - Cannot add Entry because dataSetIndex too high or too low.", terminator: "\n")
        }

        let set = self[dataSetIndex]
        if !set.addEntry(e) { return }
        calcMinMax(entry: e, axis: set.axisDependency)
    }

    /// Removes the given Entry object from the DataSet at the specified index.
    @objc @discardableResult open func removeEntry(_ entry: ChartDataEntry, dataSetIndex: Index) -> Bool
    {
        guard dataSets.indices.contains(dataSetIndex) else { return false }

        // remove the entry from the dataset
        let removed = self[dataSetIndex].removeEntry(entry)
        
        if removed
        {
            calcMinMax()
        }
        
        return removed
    }
    
    /// Removes the Entry object closest to the given xIndex from the ChartDataSet at the
    /// specified index. 
    ///
    /// - Returns: `true` if an entry was removed, `false` ifno Entry was found that meets the specified requirements.
    @objc @discardableResult open func removeEntry(xValue: Double, dataSetIndex: Index) -> Bool
    {
        guard
            dataSets.indices.contains(dataSetIndex),
            let entry = self[dataSetIndex].entryForXValue(xValue, closestToY: .nan)
            else { return false }

        return removeEntry(entry, dataSetIndex: dataSetIndex)
    }
    
    /// - Returns: The DataSet that contains the provided Entry, or null, if no DataSet contains this entry.
    @objc open func getDataSetForEntry(_ e: ChartDataEntry) -> Element?
    {
        return first { $0.entryForXValue(e.x, closestToY: e.y) === e }
    }

    /// - Returns: The index of the provided DataSet in the DataSet array of this data object, or -1 if it does not exist.
    @objc open func index(of dataSet: Element) -> Index
    {
        // TODO: Return nil instead of -1
        return firstIndex(where: { $0 === dataSet }) ?? -1
    }
    
    /// - Returns: The first DataSet from the datasets-array that has it's dependency on the left axis. Returns null if no DataSet with left dependency could be found.
    @objc open func getFirstLeft(dataSets: [Element]) -> Element?
    {
        return first { $0.axisDependency == .left }
    }
    
    /// - Returns: The first DataSet from the datasets-array that has it's dependency on the right axis. Returns null if no DataSet with right dependency could be found.
    @objc open func getFirstRight(dataSets: [Element]) -> Element?
    {
        return first { $0.axisDependency == .right }
    }
    
    /// - Returns: All colors used across all DataSet objects this object represents.
    @objc open var colors: [NSUIColor]
    {
        // TODO: Don't return nil
        return reduce(into: []) { $0 += $1.colors }
    }
    
    /// Sets a custom ValueFormatter for all DataSets this data object contains.
    @objc open func setValueFormatter(_ formatter: ValueFormatter)
    {
        forEach { $0.valueFormatter = formatter }
    }
    
    /// Sets the color of the value-text (color in which the value-labels are drawn) for all DataSets this data object contains.
    @objc open func setValueTextColor(_ color: NSUIColor)
    {
        forEach { $0.valueTextColor = color }
    }
    
    /// Sets the font for all value-labels for all DataSets this data object contains.
    @objc open func setValueFont(_ font: NSUIFont)
    {
        forEach { $0.valueFont = font }
    }

    /// Enables / disables drawing values (value-text) for all DataSets this data object contains.
    @objc open func setDrawValues(_ enabled: Bool)
    {
        forEach { $0.drawValuesEnabled = enabled }
    }
    
    /// Enables / disables highlighting values for all DataSets this data object contains.
    /// If set to true, this means that values can be highlighted programmatically or by touch gesture.
    @objc open var isHighlightEnabled: Bool
    {
        get { return allSatisfy { $0.isHighlightEnabled } }
        set { forEach { $0.highlightEnabled = newValue } }
    }

    /// Clears this data object from all DataSets and removes all Entries.
    /// Don't forget to invalidate the chart after this.
    @objc open func clearValues()
    {
        removeAll(keepingCapacity: false)
    }
    
    /// Checks if this data object contains the specified DataSet. 
    ///
    /// - Returns: `true` if so, `false` ifnot.
    @objc open func contains(dataSet: Element) -> Bool
    {
        return contains { $0 === dataSet }
    }
    
    /// The total entry count across all DataSet objects this data object contains.
    @objc open var entryCount: Int
    {
        return reduce(0) { return $0 + $1.entryCount }
    }

    /// The DataSet object with the maximum number of entries or null if there are no DataSets.
    @objc open var maxEntryCountSet: Element?
    {
        return self.max(by: \.entryCount)
    }
}

// MARK: MutableCollection
extension ChartData: MutableCollection
{
    public typealias Index = Int
    public typealias Element = ChartDataSetProtocol

    public var startIndex: Index
    {
        return dataSets.startIndex
    }

    public var endIndex: Index
    {
        return dataSets.endIndex
    }

    public func index(after: Index) -> Index
    {
        return dataSets.index(after: after)
    }

    public subscript(position: Index) -> Element
    {
        get { return dataSets[position] }
        set { self._dataSets[position] = newValue }
    }
}

// MARK: RandomAccessCollection
extension ChartData: RandomAccessCollection
{
    public func index(before: Index) -> Index
    {
        return dataSets.index(before: before)
    }
}

// TODO: Conform when dropping Objective-C support
// MARK: RangeReplaceableCollection
extension ChartData//: RangeReplaceableCollection
{
    @objc(addDataSet:)
    public func append(_ newElement: Element)
    {
        _dataSets.append(newElement)
        calcMinMax(dataSet: newElement)
    }

    @objc(removeDataSetByIndex:)
    public func remove(at position: Index) -> Element
    {
        let element = _dataSets.remove(at: position)
        calcMinMax()
        return element
    }

    public func removeFirst() -> Element
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        let element = _dataSets.removeFirst()
        notifyDataChanged()
        return element
    }

    public func removeFirst(_ n: Int)
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        _dataSets.removeFirst(n)
        notifyDataChanged()
    }

    public func removeLast() -> Element
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        let element = _dataSets.removeLast()
        notifyDataChanged()
        return element
    }

    public func removeLast(_ n: Int)
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        _dataSets.removeLast(n)
        notifyDataChanged()
    }

    public func removeSubrange<R>(_ bounds: R) where R : RangeExpression, Index == R.Bound
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        _dataSets.removeSubrange(bounds)
        notifyDataChanged()
    }

    public func removeAll(keepingCapacity keepCapacity: Bool)
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        _dataSets.removeAll(keepingCapacity: keepCapacity)
        notifyDataChanged()
    }

    public func replaceSubrange<C>(_ subrange: Swift.Range<Index>, with newElements: C) where C : Collection, Element == C.Element
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        _dataSets.replaceSubrange(subrange, with: newElements)
        newElements.forEach { self.calcMinMax(dataSet: $0) }
    }
}

// MARK: Swift Accessors
extension ChartData
{
    /// Retrieve the index of a ChartDataSet with a specific label from the ChartData. Search can be case sensitive or not.
    /// **IMPORTANT: This method does calculations at runtime, do not over-use in performance critical situations.**
    ///
    /// - Parameters:
    ///   - label: The label to search for
    ///   - ignoreCase: if true, the search is not case-sensitive
    /// - Returns: The index of the DataSet Object with the given label. `nil` if not found
    public func index(forLabel label: String, ignoreCase: Bool) -> Index?
    {
        return ignoreCase
            ? firstIndex { $0.label?.caseInsensitiveCompare(label) == .orderedSame }
            : firstIndex { $0.label == label }
    }

    public subscript(label label: String, ignoreCase ignoreCase: Bool) -> Element?
    {
        guard let index = index(forLabel: label, ignoreCase: ignoreCase) else { return nil }
        return self[index]
    }

    public subscript(entry entry: ChartDataEntry) -> Element?
    {
        assert(!(self is CombinedChartData), "\(#function) not supported for CombinedData")

        guard let index = firstIndex(where: { $0.entryForXValue(entry.x, closestToY: entry.y) === entry }) else { return nil }
        return self[index]
    }
}
