// MARK: - VideoItemTests.swift
// YTPlayer — Tests/YTPlayerTests/VideoItemTests.swift

import XCTest
@testable import YTPlayer

final class VideoItemTests: XCTestCase {
    
    func testMockItemsNotEmpty() {
        let items = VideoItem.mockItems
        XCTAssertFalse(items.isEmpty, "Mock video items should not be empty")
        XCTAssertGreaterThanOrEqual(items.count, 5, "Should provide at least 5 mock items")
    }
    
    func testFormattedViewCount() {
        let video = VideoItem(
            id: "test1234",
            title: "Test Video",
            channelName: "Test Channel",
            channelId: "UC123",
            thumbnailURL: "https://example.com/thumb.jpg",
            duration: "10:00",
            viewCount: "1500000",
            publishedAt: "2 ngày trước",
            description: "Test description"
        )
        
        XCTAssertNotNil(video.formattedViewCount)
        XCTAssertFalse(video.formattedViewCount.isEmpty)
    }
    
    func testVideoItemCodable() throws {
        let original = VideoItem.mockItems[0]
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VideoItem.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
    }
}
