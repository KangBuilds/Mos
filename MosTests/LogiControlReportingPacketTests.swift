import XCTest
@testable import Mos_Debug

final class LogiControlReportingPacketTests: XCTestCase {

    func testBLEDiverOnKeepsExistingTargetCID() {
        let params = LogiDeviceSession.controlReportingParamsForTests(
            connectionMode: .bleDirect,
            cid: 0x0053,
            divert: true
        )

        XCTAssertEqual(params, [0x00, 0x53, 0x03, 0x00, 0x00])
    }

    func testBLEDiverOffKeepsExistingTargetCID() {
        let params = LogiDeviceSession.controlReportingParamsForTests(
            connectionMode: .bleDirect,
            cid: 0x0053,
            divert: false
        )

        XCTAssertEqual(params, [0x00, 0x53, 0x02, 0x00, 0x00])
    }

}
