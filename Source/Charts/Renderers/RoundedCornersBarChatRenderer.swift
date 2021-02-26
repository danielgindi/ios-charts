import Foundation

#if os(iOS)
open class RoundedCornersBarChatRenderer: BarChartRenderer {
    
    open var cornerRadius: CGFloat = 0.0
    
    open var corners: UIRectCorner = [.allCorners]
        
    open override func drawDataSet(context: CGContext, dataSet: BarChartDataSetProtocol, index: Int) {
        drawDataSet(context: context, dataSet: dataSet, index: index, cornerRadius: cornerRadius, roundedCorners: corners)
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
                                
                let maskPath = UIBezierPath(roundedRect: barRect,
                                            byRoundingCorners: corners,
                            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
                )
                 
                let cgPath = maskPath.cgPath
                context.addPath(cgPath)
                context.fillPath()
            }
        }
    }

    public init?(renderer: DataRenderer?) {
        guard let renderer = renderer as? BarChartRenderer, let dataProvider = renderer.dataProvider else { return nil }

        super.init(dataProvider: dataProvider, animator: renderer.animator, viewPortHandler: renderer.viewPortHandler)
    }
}
#endif
