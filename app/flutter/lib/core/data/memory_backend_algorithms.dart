part of 'memory_backend.dart';

/// Algorithm implementations for [MemoryBackend].
///
/// This mixin is a thin combiner — all algorithm
/// implementations live in the domain-specific
/// part files:
/// - [_MemoryAlgoCoreMixin] — normalize, dedup,
///   sorting, categories, group icon, URL, config,
///   permission, source filter, cloud sync, DVR,
///   EPG window merge
/// - [_MemoryAlgoVodMixin] — VOD sorting,
///   categorisation, episode progress, content
///   rating filter
/// - [_MemoryAlgoTimeMixin] — timezone, EPG time
///   formatting, watch progress, playback duration
mixin _MemoryAlgorithmsMixin
    on
        _MemoryStorage,
        _MemoryAlgoCoreMixin,
        _MemoryAlgoVodMixin,
        _MemoryAlgoTimeMixin {}
