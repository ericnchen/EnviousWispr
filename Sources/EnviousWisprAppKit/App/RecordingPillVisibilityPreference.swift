/// Personal-fork preference shared by Settings and the overlay director.
/// UserDefaults.bool returns false when absent, preserving the visible default.
enum RecordingPillVisibilityPreference {
  static let key = "personalHideRecordingPill"
}
