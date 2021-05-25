//
//  ChartDataTests.swift
//  ChartsTests
//
//  Created by Peter Kaminski on 1/23/20.
//

@testable import Charts
import XCTest

class ChartDataTests: XCTestCase {
    var data: ScatterChartData!

    private enum SetLabels {
        static let one = "label1"
        static let two = "label2"
        static let three = "label3"
        static let badLabel = "Bad label"
    }

    override func setUp() {
        super.setUp()

        let setCount = 5
        let range: UInt32 = 32
        let values1 = (0 ..< setCount).map { (i) -> ChartDataEntry in
            let val = Double(arc4random_uniform(range) + 3)
            return ChartDataEntry(x: Double(i), y: val)
        }
        let values2 = (0 ..< setCount).map { (i) -> ChartDataEntry in
            let val = Double(arc4random_uniform(range) + 3)
            return ChartDataEntry(x: Double(i), y: val)
        }
        let values3 = (0 ..< setCount).map { (i) -> ChartDataEntry in
            let val = Double(arc4random_uniform(range) + 3)
            return ChartDataEntry(x: Double(i), y: val)
        }

        let set1 = ScatterChartDataSet(entries: values1, label: SetLabels.one)
        let set2 = ScatterChartDataSet(entries: values2, label: SetLabels.two)
        let set3 = ScatterChartDataSet(entries: values3, label: SetLabels.three)

        data = ScatterChartData(dataSets: [set1, set2, set3])
    }

    func testGetDataSetByLabelCaseSensitive() {
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.one, ignorecase: false)?.label == SetLabels.one)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.two, ignorecase: false)?.label == SetLabels.two)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.three, ignorecase: false)?.label == SetLabels.three)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.one.uppercased(), ignorecase: false) == nil)
    }

    func testGetDataSetByLabelIgnoreCase() {
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.one, ignorecase: true)?.label == SetLabels.one)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.two, ignorecase: true)?.label == SetLabels.two)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.three, ignorecase: true)?.label == SetLabels.three)

        XCTAssertTrue(data.dataSet(forLabel: SetLabels.one.uppercased(), ignorecase: true)?.label == SetLabels.one)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.two.uppercased(), ignorecase: true)?.label == SetLabels.two)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.three.uppercased(), ignorecase: true)?.label == SetLabels.three)
    }

    func testGetDataSetByLabelNilWithBadLabel() {
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.badLabel, ignorecase: true) == nil)
        XCTAssertTrue(data.dataSet(forLabel: SetLabels.badLabel, ignorecase: false) == nil)
    }

    func testEntriesForXValue() {
        let entryCount = 38
        let startX = Double(1621858800.0)
        let entries = (0 ..< entryCount).map { (i) -> ChartDataEntry in
            let val = Double.random(in: 70...73)
            return ChartDataEntry(x: startX+Double(i)*60.0, y: val)
        }

        let set = ChartDataSet(entries: entries)
        let slowMatch = set.firstIndex { $0.x == Double(1621860300)}

        let test1 = entries.partitioningIndex { $0.x >= Double(1621860300) }

        XCTAssertTrue(test1 == slowMatch)

        let test2 = entries.partitioningIndex { $0.x == Double(1621860300) }

        //this will fail since an exact match would rely on a 'mid' value in the partition algo to be a matching value.
        //partitioningIndex(partitioningPoint) is not the same as binary search and should noot be used with exact matching criteria as it will not give a reliable result.
        XCTAssertTrue(test1 != slowMatch)

        let res = set.entriesForXValue(Double(1621860300))
        let res2 = set.entriesForXValue(Double(1621860310))

        XCTAssertTrue(test1 == slowMatch)

        let closestIdx = set.entryIndex(x: Double(1621860310), closestToY: .nan, rounding: .closest)

        XCTAssertTrue(closestIdx == slowMatch)

        let closestIdx2 = set.entryIndex(x: Double(1621860350), closestToY: .nan, rounding: .closest)

        XCTAssertTrue(closestIdx2 == slowMatch?.advanced(by: 1))

        let closestIdx3 = set.entryIndex(x: Double(1621860330), closestToY: .nan, rounding: .closest)

        XCTAssertTrue(closestIdx3 == slowMatch)
    }
}
