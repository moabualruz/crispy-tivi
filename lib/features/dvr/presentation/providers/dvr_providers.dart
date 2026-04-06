/// DVR presentation-layer provider re-exports.
///
/// Widgets import this file instead of reaching into the data layer
/// directly. The actual provider definitions remain in the data layer
/// (single source of truth); this file re-exports them so presentation
/// code does not need to depend on data-layer implementation files.
library;

export '../../../../core/data/cache_service.dart'
    show CacheService, cacheServiceProvider;
export '../../data/dvr_service.dart' show DvrService, dvrServiceProvider;
export '../../data/dvr_state.dart' show DvrState, ScheduleResult;
export '../../data/keyword_rule_provider.dart'
    show KeywordRule, KeywordMatchField, KeywordRuleNotifier, keywordRuleProvider;
export '../../data/transfer_service.dart'
    show TransferState, storageBackendsProvider, transferServiceProvider;
