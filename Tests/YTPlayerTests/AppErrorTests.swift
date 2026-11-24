// MARK: - AppErrorTests.swift
// YTPlayer — Tests/YTPlayerTests/AppErrorTests.swift

import XCTest
@testable import YTPlayer

final class AppErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        let errors: [AppError] = [
            .networkError("Connection failed"),
            .apiError(404, "Not Found"),
            .quotaExceeded,
            .noInternet,
            .notFound,
            .invalidResponse,
            .unknown
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Each AppError case should have a valid errorDescription")
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testQuotaExceededDescription() {
        let quotaError = AppError.quotaExceeded
        XCTAssertTrue(quotaError.errorDescription?.contains("quota") == true || quotaError.errorDescription?.contains("hạn ngạch") == true)
    }
    
    func testEquality() {
        XCTAssertEqual(AppError.quotaExceeded, AppError.quotaExceeded)
        XCTAssertEqual(AppError.noInternet, AppError.noInternet)
        XCTAssertNotEqual(AppError.notFound, AppError.quotaExceeded)
    }
}
