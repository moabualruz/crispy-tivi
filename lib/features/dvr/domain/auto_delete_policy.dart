// Auto-delete policy domain types for DVR recordings.
//
// Re-exports [AutoDeletePolicy] from recording.dart for callers
// that only need the policy without the full [Recording] entity.
export 'entities/recording.dart' show AutoDeletePolicy;
