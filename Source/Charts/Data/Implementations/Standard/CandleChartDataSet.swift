//
//  CandleChartDataSet.swift
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


open class CandleChartDataSet: LineScatterCandleRadarChartDataSet, CandleChartDataSetProtocol
{
    
    public required init()
    {
        super.init()
    }
    
    public override init(entries: [ChartDataEntry], label: String)
    {
        super.init(entries: entries, label: label)
    }
    
    // MARK: - Data functions and accessors
    
    open override func calcMinMax(entry e: ChartDataEntry)
    {
        guard let e = e as? CandleChartDataEntry
            else { return }

        _yMin = Swift.min(e.low, _yMin)
        _yMax = Swift.max(e.high, _yMax)

        calcMinMaxX(entry: e)
    }
    
    open override func calcMinMaxY(entry e: ChartDataEntry)
    {
        guard let e = e as? CandleChartDataEntry
            else { return }

        _yMin = Swift.min(e.low, _yMin)
        _yMax = Swift.max(e.high, _yMin)

        _yMin = Swift.min(e.low, _yMax)
        _yMax = Swift.max(e.high, _yMax)
    }
    
    // MARK: - Styling functions and accessors
    
    /// the space between the candle entries
    ///
    /// **default**: 0.1 (10%)
    private var _barSpace: CGFloat = 0.1

    /// the space that is left out on the left and right side of each candle,
    /// **default**: 0.1 (10%), max 0.45, min 0.0
    open var barSpace: CGFloat
    {
        get
        {
            return _barSpace
        }
        set
        {
            _barSpace = newValue.clamped(to: 0...0.45)
        }
    }
    
    /// the corner radius of the candle bar,
    ///
    /// **default**: 0.0
    open var barCornerRadius = CGFloat(0.0)
    
    /// should the candle bars show?
    /// when false, only "ticks" will show
    ///
    /// **default**: true
    open var showCandleBar: Bool = true
    
    /// the width of the candle-shadow-line in pixels.
    ///
    /// **default**: 1.5
    open var shadowWidth = CGFloat(1.5)
    
    /// the color of the shadow line
    open var shadowColor: NSUIColor?
    
    /// use candle color for the shadow
    open var shadowColorSameAsCandle = false
    
    /// Is the shadow color same as the candle color?
    open var isShadowColorSameAsCandle: Bool { return shadowColorSameAsCandle }
    
    /// color for open == close
    open var neutralColor: NSUIColor?
    
    /// color for open > close
    open var increasingColor: NSUIColor?
    
    /// color for open < close
    open var decreasingColor: NSUIColor?
    
    /// Are increasing values drawn as filled?
    /// increasing candlesticks are traditionally hollow
    open var increasingFilled = false
    
    /// Are increasing values drawn as filled?
    open var isIncreasingFilled: Bool { return increasingFilled }
    
    /// Are decreasing values drawn as filled?
    /// descreasing candlesticks are traditionally filled
    open var decreasingFilled = true
    
    /// Are decreasing values drawn as filled?
    open var isDecreasingFilled: Bool { return decreasingFilled }
}
