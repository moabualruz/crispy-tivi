// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sports_score_overlay.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages live sports score data for a multiview slot.
///
/// FE-MV-09: Implemented using ESPN's public scoreboard API.
/// Note: Since we don't have the explicit event ID, this demo implementation
/// fetches the first active game as an example to demonstrate the UI overlay.
/// In production, the `channelId` should map to a specific `gameId`.

@ProviderFor(SportsScore)
final sportsScoreProvider = SportsScoreFamily._();

/// Manages live sports score data for a multiview slot.
///
/// FE-MV-09: Implemented using ESPN's public scoreboard API.
/// Note: Since we don't have the explicit event ID, this demo implementation
/// fetches the first active game as an example to demonstrate the UI overlay.
/// In production, the `channelId` should map to a specific `gameId`.
final class SportsScoreProvider
    extends $AsyncNotifierProvider<SportsScore, SportsScoreState> {
  /// Manages live sports score data for a multiview slot.
  ///
  /// FE-MV-09: Implemented using ESPN's public scoreboard API.
  /// Note: Since we don't have the explicit event ID, this demo implementation
  /// fetches the first active game as an example to demonstrate the UI overlay.
  /// In production, the `channelId` should map to a specific `gameId`.
  SportsScoreProvider._({
    required SportsScoreFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sportsScoreProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sportsScoreHash();

  @override
  String toString() {
    return r'sportsScoreProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SportsScore create() => SportsScore();

  @override
  bool operator ==(Object other) {
    return other is SportsScoreProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sportsScoreHash() => r'088112a38250dfa55b86ed66e1f6272e64fae1dd';

/// Manages live sports score data for a multiview slot.
///
/// FE-MV-09: Implemented using ESPN's public scoreboard API.
/// Note: Since we don't have the explicit event ID, this demo implementation
/// fetches the first active game as an example to demonstrate the UI overlay.
/// In production, the `channelId` should map to a specific `gameId`.

final class SportsScoreFamily extends $Family
    with
        $ClassFamilyOverride<
          SportsScore,
          AsyncValue<SportsScoreState>,
          SportsScoreState,
          FutureOr<SportsScoreState>,
          String
        > {
  SportsScoreFamily._()
    : super(
        retry: null,
        name: r'sportsScoreProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Manages live sports score data for a multiview slot.
  ///
  /// FE-MV-09: Implemented using ESPN's public scoreboard API.
  /// Note: Since we don't have the explicit event ID, this demo implementation
  /// fetches the first active game as an example to demonstrate the UI overlay.
  /// In production, the `channelId` should map to a specific `gameId`.

  SportsScoreProvider call(String channelId) =>
      SportsScoreProvider._(argument: channelId, from: this);

  @override
  String toString() => r'sportsScoreProvider';
}

/// Manages live sports score data for a multiview slot.
///
/// FE-MV-09: Implemented using ESPN's public scoreboard API.
/// Note: Since we don't have the explicit event ID, this demo implementation
/// fetches the first active game as an example to demonstrate the UI overlay.
/// In production, the `channelId` should map to a specific `gameId`.

abstract class _$SportsScore extends $AsyncNotifier<SportsScoreState> {
  late final _$args = ref.$arg as String;
  String get channelId => _$args;

  FutureOr<SportsScoreState> build(String channelId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<SportsScoreState>, SportsScoreState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SportsScoreState>, SportsScoreState>,
              AsyncValue<SportsScoreState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
