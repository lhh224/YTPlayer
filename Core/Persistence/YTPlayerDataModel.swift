import Foundation

// NOTE: Tạo file YTPlayer.xcdatamodeld trong Xcode (File → New → File → Data Model),
// đặt tên "YTPlayer", rồi thêm 2 entities sau:
//
// ─────────────────────────────────────────────────
// Entity: WatchHistoryItem
// ─────────────────────────────────────────────────
// Attributes:
//   videoId      | String  | Optional: NO
//   title        | String  | Optional: NO
//   channelName  | String  | Optional: NO
//   thumbnailURL | String  | Optional: NO
//   watchedAt    | Date    | Optional: NO
//   duration     | String  | Optional: NO
//
// ─────────────────────────────────────────────────
// Entity: FavoriteItem
// ─────────────────────────────────────────────────
// Attributes:
//   videoId      | String  | Optional: NO
//   title        | String  | Optional: NO
//   channelName  | String  | Optional: NO
//   thumbnailURL | String  | Optional: NO
//   addedAt      | Date    | Optional: NO
//   duration     | String  | Optional: NO
//
// ─────────────────────────────────────────────────
// Codegen: Manual/None for both entities (LibraryRepository uses NSManagedObject KVC directly).
// Module: Current Product Module.
// ─────────────────────────────────────────────────
//
// After creating the data model, make sure the .xcdatamodeld file is included
// in the app target's "Copy Bundle Resources" build phase.
