import 'package:meta/meta.dart';

import '../../../parental/domain/content_rating.dart';
import '../enums/dvr_permission.dart';
import '../enums/user_role.dart';

// FE-PM-02: Profile type enum distinguishing standard and kids profiles.

/// The type of a user profile.
///
/// - [standard]: full-access profile (subject to role/parental settings).
/// - [kids]: age-gated profile — content rating capped at PG (index 1),
///   simplified UI badge, and requires admin PIN to switch away from.
enum ProfileType {
  /// A regular profile with standard access controls.
  standard,

  /// A kids profile — content capped at PG, PIN-gated exit.
  kids,
}

/// A user profile for per-user settings and favorites.
///
/// Stored locally in ObjectBox. Supports PIN-protected
/// parental controls and role-based access control.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.avatarIndex = 0,
    this.pin,
    this.isChild = false,
    this.isActive = false,
    this.isGuest = false,
    this.pinVersion = 0,
    this.maxAllowedRating = 4,
    this.role = UserRole.viewer,
    this.dvrPermission = DvrPermission.full,
    this.dvrQuotaMB,
    this.accentColorValue,
    this.preferredAudioLanguage,
    this.preferredSubtitleLanguage,
    this.subtitleEnabledByDefault = false,
    // FE-PM-02
    this.profileType = ProfileType.standard,
  });

  /// Unique profile identifier.
  final String id;

  /// Display name.
  final String name;

  /// Avatar index (maps to a predefined avatar set).
  final int avatarIndex;

  /// Optional PIN for parental controls.
  /// Format depends on [pinVersion]: 0 = plaintext, 1 = SHA-256 hash.
  final String? pin;

  /// Whether this is a child/restricted profile.
  final bool isChild;

  /// Whether this is the currently active profile.
  final bool isActive;

  /// Whether this is a guest profile (FE-PM-10).
  ///
  /// Guest profiles have no PIN, and watch history is never
  /// persisted for them.
  final bool isGuest;

  /// PIN storage version: 0 = plaintext (legacy), 1 = SHA-256 hashed.
  final int pinVersion;

  /// Maximum allowed content rating value.
  /// Maps to [ContentRatingLevel]: 0=G, 1=PG, 2=PG-13, 3=R, 4=NC-17.
  final int maxAllowedRating;

  /// User role determining access permissions.
  final UserRole role;

  /// DVR permission level for recording access.
  final DvrPermission dvrPermission;

  /// Optional DVR storage quota in megabytes.
  /// Null means unlimited (subject to system limits).
  final int? dvrQuotaMB;

  /// Per-profile accent color as a 32-bit ARGB integer.
  ///
  /// When set, overrides the app-level accent color (ColorScheme.primary)
  /// for the duration of this profile's session (FE-PM-08).
  /// Null means use the global theme accent color.
  final int? accentColorValue;

  /// Preferred audio language as a BCP-47 language tag (e.g. "en", "fr").
  ///
  /// When set, the player will attempt to select the matching audio track
  /// automatically. Null means no preference (follow stream default).
  final String? preferredAudioLanguage;

  /// Preferred subtitle language as a BCP-47 language tag (e.g. "en", "fr").
  ///
  /// When set, the player will attempt to select the matching subtitle track
  /// automatically. Null means no preference.
  final String? preferredSubtitleLanguage;

  /// Whether subtitles are enabled by default for this profile.
  ///
  /// When true the player turns on subtitles at session start
  /// (subject to [preferredSubtitleLanguage] availability).
  final bool subtitleEnabledByDefault;

  /// FE-PM-02: The profile type (standard or kids).
  ///
  /// Kids profiles cap content at PG, display a "KIDS" badge,
  /// and require an admin PIN to switch away from.
  final ProfileType profileType;

  /// Whether PIN protection is enabled.
  bool get hasPIN => pin != null && pin!.isNotEmpty;

  /// FE-PM-02: Whether this is a kids profile.
  bool get isKids => profileType == ProfileType.kids;

  /// Whether this profile has content restrictions.
  bool get isRestricted => isChild || isKids || maxAllowedRating < 4;

  /// FE-PM-02: Effective max rating — kids profiles are always capped at PG.
  int get effectiveMaxRating => isKids ? 1 : maxAllowedRating;

  /// Whether this is an admin profile.
  bool get isAdmin => role == UserRole.admin;

  /// Whether this profile can access settings.
  bool get canAccessSettings => role.canAccessSettings;

  /// Whether this profile can manage other profiles.
  bool get canManageProfiles => role.canManageProfiles;

  /// Whether this profile has access to all sources by default.
  bool get hasAllSourceAccess => role.hasAllSourceAccess;

  /// Whether this profile can view recordings.
  bool get canViewRecordings => dvrPermission.canViewRecordings;

  /// Whether this profile can schedule recordings.
  bool get canScheduleRecordings => dvrPermission.canScheduleRecordings;

  /// Returns the content rating level for this profile.
  ContentRatingLevel get ratingLevel =>
      ContentRatingLevel.fromValue(maxAllowedRating);

  UserProfile copyWith({
    String? id,
    String? name,
    int? avatarIndex,
    String? pin,
    bool? isChild,
    bool? isActive,
    bool? isGuest,
    int? pinVersion,
    int? maxAllowedRating,
    UserRole? role,
    DvrPermission? dvrPermission,
    int? dvrQuotaMB,
    int? accentColorValue,
    String? preferredAudioLanguage,
    String? preferredSubtitleLanguage,
    bool? subtitleEnabledByDefault,
    // FE-PM-02
    ProfileType? profileType,
    bool clearPin = false,
    bool clearDvrQuota = false,
    bool clearAccentColor = false,
    bool clearAudioLanguage = false,
    bool clearSubtitleLanguage = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      pin: clearPin ? null : (pin ?? this.pin),
      isChild: isChild ?? this.isChild,
      isActive: isActive ?? this.isActive,
      isGuest: isGuest ?? this.isGuest,
      pinVersion: pinVersion ?? this.pinVersion,
      maxAllowedRating: maxAllowedRating ?? this.maxAllowedRating,
      role: role ?? this.role,
      dvrPermission: dvrPermission ?? this.dvrPermission,
      dvrQuotaMB: clearDvrQuota ? null : (dvrQuotaMB ?? this.dvrQuotaMB),
      accentColorValue:
          clearAccentColor ? null : (accentColorValue ?? this.accentColorValue),
      preferredAudioLanguage:
          clearAudioLanguage
              ? null
              : (preferredAudioLanguage ?? this.preferredAudioLanguage),
      preferredSubtitleLanguage:
          clearSubtitleLanguage
              ? null
              : (preferredSubtitleLanguage ?? this.preferredSubtitleLanguage),
      subtitleEnabledByDefault:
          subtitleEnabledByDefault ?? this.subtitleEnabledByDefault,
      // FE-PM-02
      profileType: profileType ?? this.profileType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => 'UserProfile($name)';
}
