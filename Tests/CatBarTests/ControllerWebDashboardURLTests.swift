import XCTest
@testable import CatBar

final class ControllerWebDashboardURLTests: XCTestCase {
    func testBuildsTLSDashboardURLFromRuntimeUIConfig() {
        let url = ControllerWebDashboardURL(
            controller: "127.0.0.1:9090",
            tlsController: "0.0.0.0:9443",
            externalUI: "ui",
            externalUIName: "zashboard",
            secret: "631121",
            publicHost: "10.0.0.1")
            .url()

        XCTAssertEqual(
            url?.absoluteString,
            "http://10.0.0.1:9443/ui/zashboard/?host=10.0.0.1&hostname=10.0.0.1&port=9443&secret=631121")
    }

    func testFallsBackToPlainControllerAndDefaultUIPath() {
        let url = ControllerWebDashboardURL(
            controller: "127.0.0.1:9090",
            tlsController: nil,
            externalUI: nil,
            externalUIName: nil,
            secret: nil,
            publicHost: nil)
            .url()

        XCTAssertEqual(
            url?.absoluteString,
            "http://127.0.0.1:9090/ui?host=127.0.0.1&hostname=127.0.0.1&port=9090")
    }
}
