import Foundation

struct VideoItem: Identifiable, Codable, Hashable {
    let id: String          // videoId
    let title: String
    let channelName: String
    let channelId: String
    let thumbnailURL: String
    let duration: String
    let viewCount: String
    let publishedAt: String
    let description: String

    // MARK: - Computed Properties

    var formattedViewCount: String {
        guard !viewCount.isEmpty else { return "" }
        guard let count = Int(viewCount) else { return viewCount }
        switch count {
        case 1_000_000_000...:
            return String(format: "%.1fB views", Double(count) / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM views", Double(count) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK views", Double(count) / 1_000)
        default:
            return "\(count) views"
        }
    }

    // MARK: - Mock Data

    static let mockItems: [VideoItem] = [
        VideoItem(
            id: "dQw4w9WgXcQ",
            title: "Rick Astley - Never Gonna Give You Up (Official Music Video)",
            channelName: "Rick Astley",
            channelId: "UCuAXFkgsw1L7xaCfnd5JJOw",
            thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
            duration: "3:33",
            viewCount: "1400000000",
            publishedAt: "2009-10-25",
            description: "The official video for 'Never Gonna Give You Up' by Rick Astley."
        ),
        VideoItem(
            id: "9bZkp7q19f0",
            title: "PSY - GANGNAM STYLE (강남스타일) M/V",
            channelName: "officialpsy",
            channelId: "UCrDkAvwZum-UTjHmzDI2iIw",
            thumbnailURL: "https://i.ytimg.com/vi/9bZkp7q19f0/hqdefault.jpg",
            duration: "4:13",
            viewCount: "4900000000",
            publishedAt: "2012-07-15",
            description: "PSY - 'GANGNAM STYLE(강남스타일)' M/V @ https://www.youtube.com/officialpsy"
        ),
        VideoItem(
            id: "kJQP7kiw5Fk",
            title: "Luis Fonsi - Despacito ft. Daddy Yankee",
            channelName: "Luis Fonsi",
            channelId: "UCxoq-4NaGjJQMUKlRALdrzA",
            thumbnailURL: "https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg",
            duration: "4:42",
            viewCount: "8200000000",
            publishedAt: "2017-01-12",
            description: "Luis Fonsi - Despacito ft. Daddy Yankee. The most watched video on YouTube."
        ),
        VideoItem(
            id: "JGwWNGJdvx8",
            title: "Ed Sheeran - Shape of You (Official Music Video)",
            channelName: "Ed Sheeran",
            channelId: "UC0C-w0YjGpqDXGB8IHb662A",
            thumbnailURL: "https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg",
            duration: "4:24",
            viewCount: "5900000000",
            publishedAt: "2017-01-30",
            description: "The official music video for Ed Sheeran - Shape Of You."
        ),
        VideoItem(
            id: "RgKAFK5djSk",
            title: "Wiz Khalifa - See You Again ft. Charlie Puth (Official Video)",
            channelName: "Wiz Khalifa",
            channelId: "UCVmHa2bFGhBe3AyMSB7uoNg",
            thumbnailURL: "https://i.ytimg.com/vi/RgKAFK5djSk/hqdefault.jpg",
            duration: "3:57",
            viewCount: "5700000000",
            publishedAt: "2015-04-06",
            description: "Wiz Khalifa - See You Again ft. Charlie Puth from the Furious 7 Soundtrack."
        ),
        VideoItem(
            id: "Llw9Q6akRo4",
            title: "SƠN TÙNG M-TP | CHÚNG TA CỦA TƯƠNG LAI | OFFICIAL MUSIC VIDEO",
            channelName: "Sơn Tùng M-TP Official",
            channelId: "UClyA28-01x4z60eWQ2kiNbA",
            thumbnailURL: "https://i.ytimg.com/vi/Llw9Q6akRo4/hqdefault.jpg",
            duration: "4:15",
            viewCount: "68000000",
            publishedAt: "2024-03-08",
            description: "SƠN TÙNG M-TP | CHÚNG TA CỦA TƯƠNG LAI | OFFICIAL MUSIC VIDEO."
        ),
        VideoItem(
            id: "Ws-QlpSlTR8",
            title: "Đen - Nấu ăn cho em ft. PiaLinh (M/V)",
            channelName: "Đen Vâu Official",
            channelId: "UCWu91J5KWEj1bQhCBuGeJxw",
            thumbnailURL: "https://i.ytimg.com/vi/Ws-QlpSlTR8/hqdefault.jpg",
            duration: "4:32",
            viewCount: "54000000",
            publishedAt: "2023-05-13",
            description: "Đen - Nấu ăn cho em ft. PiaLinh (M/V)."
        ),
        VideoItem(
            id: "jfKfPfyJRdk",
            title: "lofi hip hop radio - beats to relax/study to",
            channelName: "Lofi Girl",
            channelId: "UCSJ4gkVC6NrvII8umztf0Ow",
            thumbnailURL: "https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg",
            duration: "LIVE",
            viewCount: "120000000",
            publishedAt: "2022-07-12",
            description: "Peaceful lofi hip hop radio beats to relax, study, code and chill to."
        )
    ]
}
