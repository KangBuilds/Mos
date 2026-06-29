import XCTest
@testable import Mos_Debug

final class LogiReceiverConnectionStateTests: XCTestCase {

    func testMXAnywhere2SBLEKeyboardUsageIsHIDPPCandidate() {
        XCTAssertTrue(LogiDeviceSession.isBLEHIDPPCandidateForTests(
            productId: 0xB01A,
            usagePage: 0x0001,
            usage: 0x0006
        ))
    }

    func testOtherBLEKeyboardUsageIsNotHIDPPCandidate() {
        XCTAssertFalse(LogiDeviceSession.isBLEHIDPPCandidateForTests(
            productId: 0xB034,
            usagePage: 0x0001,
            usage: 0x0006
        ))
    }

    func testBLEMouseUsageIsNotHIDPPCandidateForThisFork() {
        XCTAssertFalse(LogiDeviceSession.isBLEHIDPPCandidateForTests(
            productId: 0xB01A,
            usagePage: 0x0001,
            usage: 0x0002
        ))
    }
}
