@testable import Charts
import SnapshotTesting
import XCTest

class PieChartTests: XCTestCase {
    private lazy var icon = UIImage(named: "icon", in: Bundle(for: classForCoder), compatibleWith: nil)!

    var chart: PieChartView!
    var dataSet: PieChartDataSet!

    override func setUp() {
        super.setUp()

        // Set to `true` to re-capture all snapshots
        isRecording = false

        // Sample data
        let values: [Double] = [11, 33, 81, 52, 97, 101, 75]

        var entries: [PieChartDataEntry] = Array()

        for value in values {
            entries.append(PieChartDataEntry(value: value, icon: icon))
        }

        dataSet = PieChartDataSet(entries: entries, label: "First unit test data")
        dataSet.drawIconsEnabled = false
        dataSet.iconsOffset = CGPoint(x: 0, y: 20.0)

        let colors = ChartColorTemplates.vordiplom
            + ChartColorTemplates.joyful
            + ChartColorTemplates.colorful
            + ChartColorTemplates.liberty
            + ChartColorTemplates.pastel
            + [UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)]
        dataSet.colors = colors
        
        chart = PieChartView(frame: CGRect(x: 0, y: 0, width: 480, height: 350))
        chart.backgroundColor = NSUIColor.clear
        chart.centerText = "PieChart Unit Test"
        chart.data = PieChartData(dataSet: dataSet)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDefaultValues() {
        assertChartSnapshot(matching: chart)
    }

    func testHidesValues() {
        dataSet.drawValuesEnabled = false
        assertChartSnapshot(matching: chart)
    }

    func testDrawIcons() {
        dataSet.drawIconsEnabled = true
        assertChartSnapshot(matching: chart)
    }

    func testHideCenterLabel() {
        chart.drawCenterTextEnabled = false
        assertChartSnapshot(matching: chart)
    }

    func testHighlightDisabled() {
        chart.data?.dataSets[0].highlightEnabled = false
        chart.highlightValue(x: 1.0, dataSetIndex: 0, callDelegate: false)
        assertChartSnapshot(matching: chart)
    }

    func testHighlightEnabled() {
        // by default, it's enabled
        chart.highlightValue(x: 1.0, dataSetIndex: 0, callDelegate: false)
        assertChartSnapshot(matching: chart)
    }
}
