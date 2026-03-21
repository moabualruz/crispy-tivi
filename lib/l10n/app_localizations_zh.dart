// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonRetry => '重试';

  @override
  String get commonSomethingWentWrong => '出了点问题';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonSubmit => '提交';

  @override
  String get commonBack => '返回';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonAll => '全部';

  @override
  String get commonOn => '开';

  @override
  String get commonOff => '关';

  @override
  String get commonAuto => '自动';

  @override
  String get commonNone => '无';

  @override
  String commonError(String message) {
    return '错误：$message';
  }

  @override
  String get commonOr => '或';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonDone => '完成';

  @override
  String get commonPlay => '播放';

  @override
  String get commonPause => '暂停';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonGoToSettings => '前往设置';

  @override
  String get commonNew => '新';

  @override
  String get commonLive => '直播';

  @override
  String get commonFavorites => '收藏';

  @override
  String get keyboardShortcuts => '键盘快捷键';

  @override
  String get navHome => '首页';

  @override
  String get navSearch => '搜索';

  @override
  String get navLiveTv => '直播电视';

  @override
  String get navGuide => '节目指南';

  @override
  String get navMovies => '电影';

  @override
  String get navSeries => '剧集';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => '收藏';

  @override
  String get navSettings => '设置';

  @override
  String get breadcrumbProfiles => '档案';

  @override
  String get breadcrumbJellyfin => 'Jellyfin';

  @override
  String get breadcrumbEmby => 'Emby';

  @override
  String get breadcrumbPlex => 'Plex';

  @override
  String get breadcrumbCloud => '云';

  @override
  String get breadcrumbMultiView => '多画面';

  @override
  String get breadcrumbDetail => '详情';

  @override
  String get breadcrumbNavigateToParent => '返回上级';

  @override
  String get sideNavSwitchProfile => '切换档案';

  @override
  String get sideNavManageProfiles => '管理档案';

  @override
  String sideNavSwitchProfileFor(String name) {
    return '切换档案：$name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return '输入 $name 的 PIN 码';
  }

  @override
  String get sideNavActive => '当前使用';

  @override
  String get sideNavPinProtected => '已设置 PIN 保护';

  @override
  String get fabWhatsOn => '正在播出';

  @override
  String get fabRandomPick => '随机选择';

  @override
  String get fabLastChannel => '上一个频道';

  @override
  String get fabSchedule => '时间表';

  @override
  String get fabNewList => '新建列表';

  @override
  String get offlineNoConnection => '无网络连接';

  @override
  String get offlineConnectionRestored => '网络连接已恢复';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => '页面未找到';

  @override
  String get pinConfirmPin => '确认 PIN 码';

  @override
  String get pinEnterAllDigits => '请输入全部 4 位数字';

  @override
  String get pinDoNotMatch => 'PIN 码不匹配';

  @override
  String get pinTooManyAttempts => '错误次数过多。';

  @override
  String pinTryAgainIn(String countdown) {
    return '请在 $countdown 后重试';
  }

  @override
  String get pinEnterSameAgain => '请再次输入相同的 PIN 码以确认';

  @override
  String get pinUseBiometric => '使用指纹或面部识别';

  @override
  String pinDigitN(int n) {
    return 'PIN 第 $n 位';
  }

  @override
  String get pinIncorrect => 'PIN 码错误';

  @override
  String get pinVerificationFailed => '验证失败';

  @override
  String get pinBiometricFailed => '生物识别认证失败或已取消';

  @override
  String get contextMenuRemoveFromFavorites => '从收藏中删除';

  @override
  String get contextMenuAddToFavorites => '添加到收藏';

  @override
  String get contextMenuSwitchStreamSource => '切换流来源';

  @override
  String get contextMenuSmartGroup => '智能分组';

  @override
  String get contextMenuMultiView => '多画面';

  @override
  String get contextMenuAssignEpg => '分配 EPG';

  @override
  String get contextMenuHideChannel => '隐藏频道';

  @override
  String get contextMenuCopyStreamUrl => '复制直播地址';

  @override
  String get contextMenuPlayExternal => '用外部播放器打开';

  @override
  String get contextMenuBlockChannel => '屏蔽频道';

  @override
  String get contextMenuViewDetails => '查看详情';

  @override
  String get contextMenuRemoveFromFavoriteCategories => '从收藏分类中删除';

  @override
  String get contextMenuAddToFavoriteCategories => '添加到收藏分类';

  @override
  String get contextMenuFilterByCategory => '按此分类筛选';

  @override
  String get contextMenuCloseContextMenu => '关闭菜单';

  @override
  String get sourceAllSources => '全部来源';

  @override
  String sourceFilterLabel(String label) {
    return '$label 来源过滤';
  }

  @override
  String get categoryLabel => '分类';

  @override
  String categoryAll(String label) {
    return '全部 $label';
  }

  @override
  String categorySelect(String label) {
    return '选择 $label';
  }

  @override
  String get categorySearchHint => '搜索分类…';

  @override
  String get categorySearchLabel => '搜索分类';

  @override
  String get categoryRemoveFromFavorites => '从收藏分类中删除';

  @override
  String get categoryAddToFavorites => '添加到收藏分类';

  @override
  String get sidebarExpandSidebar => '展开侧栏';

  @override
  String get sidebarCollapseSidebar => '收起侧栏';

  @override
  String get badgeNewEpisode => '新集';

  @override
  String get badgeNewSeason => '新季';

  @override
  String get badgeRecording => '录制';

  @override
  String get badgeExpiring => '即将过期';

  @override
  String get toggleFavorite => '切换收藏';

  @override
  String get playerSkipBack => '后退 10 秒';

  @override
  String get playerSkipForward => '前进 10 秒';

  @override
  String get playerChannels => '频道';

  @override
  String get playerRecordings => '录制';

  @override
  String get playerCloseGuide => '关闭节目指南 (G)';

  @override
  String get playerTvGuide => '电视节目指南 (G)';

  @override
  String get playerAudioSubtitles => '音频与字幕';

  @override
  String get playerNoTracksAvailable => '暂无可用音轨';

  @override
  String get playerExitFullscreen => '退出全屏';

  @override
  String get playerFullscreen => '全屏';

  @override
  String get playerUnlockScreen => '解锁屏幕';

  @override
  String get playerLockScreen => '锁定屏幕';

  @override
  String get playerStreamQuality => '流画质';

  @override
  String get playerRotationLock => '锁定屏幕旋转';

  @override
  String get playerScreenBrightness => '屏幕亮度';

  @override
  String get playerShaderPreset => '着色器预设';

  @override
  String get playerAutoSystem => '自动（系统）';

  @override
  String get playerResetToAuto => '重置为自动';

  @override
  String get playerPortrait => '竖屏';

  @override
  String get playerPortraitUpsideDown => '竖屏（倒置）';

  @override
  String get playerLandscapeLeft => '横屏向左';

  @override
  String get playerLandscapeRight => '横屏向右';

  @override
  String get playerDeinterlaceAuto => '自动';

  @override
  String get playerMoreOptions => '更多选项';

  @override
  String get playerRemoveFavorite => '取消收藏';

  @override
  String get playerAddFavorite => '添加收藏';

  @override
  String get playerAudioTrack => '音轨';

  @override
  String playerAspectRatio(String label) {
    return '画面比例 ($label)';
  }

  @override
  String get playerRefreshStream => '刷新直播流';

  @override
  String get playerStreamInfo => '流信息';

  @override
  String get playerPip => '画中画';

  @override
  String get playerSleepTimer => '睡眠定时器';

  @override
  String get playerExternalPlayer => '外部播放器';

  @override
  String get playerSearchChannels => '搜索频道';

  @override
  String get playerChannelList => '频道列表';

  @override
  String get playerScreenshot => '截图';

  @override
  String playerStreamQualityOption(String label) {
    return '流画质 ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return '去隔行 ($mode)';
  }

  @override
  String get playerSyncOffset => '同步偏移';

  @override
  String playerAudioPassthrough(String state) {
    return '音频直通 ($state)';
  }

  @override
  String get playerAudioOutputDevice => '音频输出设备';

  @override
  String playerAlwaysOnTop(String state) {
    return '始终置顶 ($state)';
  }

  @override
  String playerShaders(String label) {
    return '着色器 ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => '音频';

  @override
  String get playerSubtitlesSectionSubtitles => '字幕';

  @override
  String get playerSubtitlesSecondHint => '（长按 = 第 2 条）';

  @override
  String get playerSubtitlesCcStyle => '字幕样式';

  @override
  String get playerSyncOffsetAudio => '音频';

  @override
  String get playerSyncOffsetSubtitle => '字幕';

  @override
  String get playerSyncOffsetResetToZero => '重置为 0';

  @override
  String get playerNoAudioDevices => '未找到音频设备。';

  @override
  String get playerSpeedLive => '速度（直播）';

  @override
  String get playerSpeed => '速度';

  @override
  String get playerVolumeLabel => '音量';

  @override
  String playerVolumePercent(int percent) {
    return '音量 $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return '切换档案 ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return '剩余 $duration';
  }

  @override
  String get playerSubtitleFontWeight => '字体粗细';

  @override
  String get playerSubtitleBold => '粗体';

  @override
  String get playerSubtitleNormal => '正常';

  @override
  String get playerSubtitleFontSize => '字体大小';

  @override
  String playerSubtitlePosition(int value) {
    return '位置 ($value%)';
  }

  @override
  String get playerSubtitleTextColor => '文字颜色';

  @override
  String get playerSubtitleOutlineColor => '描边颜色';

  @override
  String playerSubtitleOutlineSize(String value) {
    return '描边大小 ($value)';
  }

  @override
  String get playerSubtitleBackground => '背景';

  @override
  String playerSubtitleBgOpacity(int value) {
    return '背景透明度 ($value%)';
  }

  @override
  String get playerSubtitleShadow => '阴影';

  @override
  String get playerSubtitlePreview => '预览';

  @override
  String get playerSubtitleSampleText => '字幕示例文字';

  @override
  String get playerSubtitleResetDefaults => '恢复默认设置';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return '将在 $duration 后停止';
  }

  @override
  String get playerSleepTimerCancelTimer => '取消定时器';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return '设置睡眠定时器为 $minutes 分钟';
  }

  @override
  String get playerStreamStats => '流统计';

  @override
  String get playerStreamStatsBuffer => '缓冲';

  @override
  String get playerStreamStatsFps => '帧率';

  @override
  String get playerStreamStatsCopied => '已复制！';

  @override
  String get playerStreamStatsCopy => '复制统计信息';

  @override
  String get playerStreamStatsInterlaced => '隔行扫描';

  @override
  String playerNextUpIn(int seconds) {
    return '$seconds 秒后播放下一集';
  }

  @override
  String get playerPlayNow => '立即播放';

  @override
  String get playerFinished => '已播放完毕';

  @override
  String get playerWatchAgain => '再次观看';

  @override
  String get playerBrowseMore => '浏览更多';

  @override
  String get playerShortcutsTitle => '键盘快捷键';

  @override
  String get playerShortcutsCloseEsc => '关闭 (Esc)';

  @override
  String get playerShortcutsPlayback => '播放控制';

  @override
  String get playerShortcutsPlayPause => '播放 / 暂停';

  @override
  String get playerShortcutsSeek => '快进/退 ±10 秒';

  @override
  String get playerShortcutsSpeedStep => '速度 −/+ 档位';

  @override
  String get playerShortcutsSpeedFine => '速度 −/+ 0.1x';

  @override
  String get playerShortcutsJumpPercent => '跳转到 %（VOD）';

  @override
  String get playerShortcutsFrameStep => '逐帧 ±1';

  @override
  String get playerShortcutsAspectRatio => '循环切换画面比例';

  @override
  String get playerShortcutsCycleSubtitles => '循环切换字幕';

  @override
  String get playerShortcutsVolume => '音量';

  @override
  String get playerShortcutsVolumeAdjust => '音量 ±10%';

  @override
  String get playerShortcutsMute => '静音 / 取消静音';

  @override
  String get playerShortcutsDisplay => '显示';

  @override
  String get playerShortcutsFullscreenToggle => '切换全屏';

  @override
  String get playerShortcutsExitFullscreen => '退出全屏 / 返回';

  @override
  String get playerShortcutsStreamInfo => '流信息';

  @override
  String get playerShortcutsLiveTv => '直播电视';

  @override
  String get playerShortcutsChannelUp => '上一频道';

  @override
  String get playerShortcutsChannelDown => '下一频道';

  @override
  String get playerShortcutsChannelList => '频道列表';

  @override
  String get playerShortcutsToggleZap => '切换换台覆盖层';

  @override
  String get playerShortcutsGeneral => '通用';

  @override
  String get playerShortcutsSubtitlesCc => '字幕 / CC';

  @override
  String get playerShortcutsScreenLock => '锁定屏幕';

  @override
  String get playerShortcutsThisHelp => '此帮助界面';

  @override
  String get playerShortcutsEscToClose => '按 Esc 或 ? 关闭';

  @override
  String get playerZapChannels => '频道';

  @override
  String get playerBookmark => '书签';

  @override
  String get playerEditBookmark => '编辑书签';

  @override
  String get playerBookmarkLabelHint => '书签标签（可选）';

  @override
  String get playerBookmarkLabelInput => '书签标签';

  @override
  String playerBookmarkAdded(String label) {
    return '已在 $label 添加书签';
  }

  @override
  String get playerExpandToFullscreen => '展开至全屏';

  @override
  String get playerUnmute => '取消静音';

  @override
  String get playerMute => '静音';

  @override
  String get playerStopPlayback => '停止播放';

  @override
  String get playerQueueUpNext => '即将播放';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return '第 $number 季剧集';
  }

  @override
  String get playerQueueEpisodes => '剧集';

  @override
  String get playerQueueEmpty => '播放队列为空';

  @override
  String get playerQueueClose => '关闭队列';

  @override
  String get playerQueueOpen => '队列';

  @override
  String playerEpisodeNumber(String number) {
    return '第 $number 集';
  }

  @override
  String get playerScreenLocked => '屏幕已锁定';

  @override
  String get playerHoldToUnlock => '长按解锁';

  @override
  String get playerScreenshotSaved => '截图已保存';

  @override
  String get playerScreenshotFailed => '截图失败';

  @override
  String get playerSkipSegment => '跳过片段';

  @override
  String playerSkipType(String type) {
    return '跳过 $type';
  }

  @override
  String get playerCouldNotOpenExternal => '无法打开外部播放器';

  @override
  String get playerExitMultiView => '退出多画面';

  @override
  String get playerScreensaverBouncingLogo => '弹跳 Logo';

  @override
  String get playerScreensaverClock => '时钟';

  @override
  String get playerScreensaverBlackScreen => '黑屏';

  @override
  String get streamProfileAuto => '自动';

  @override
  String get streamProfileAutoDesc => '根据网络自动调整画质';

  @override
  String get streamProfileLow => '低';

  @override
  String get streamProfileLowDesc => 'SD 画质，最高约 1 Mbps';

  @override
  String get streamProfileMedium => '中';

  @override
  String get streamProfileMediumDesc => 'HD 画质，最高约 3 Mbps';

  @override
  String get streamProfileHigh => '高';

  @override
  String get streamProfileHighDesc => 'Full HD 画质，最高约 8 Mbps';

  @override
  String get streamProfileMaximum => '最高';

  @override
  String get streamProfileMaximumDesc => '最佳画质，无限制';

  @override
  String get segmentIntro => '片头';

  @override
  String get segmentOutro => '片尾 / 字幕';

  @override
  String get segmentRecap => '前情回顾';

  @override
  String get segmentCommercial => '广告';

  @override
  String get segmentPreview => '预告';

  @override
  String get segmentSkipNone => '不跳过';

  @override
  String get segmentSkipAsk => '询问是否跳过';

  @override
  String get segmentSkipOnce => '跳过一次';

  @override
  String get segmentSkipAlways => '始终跳过';

  @override
  String get nextUpOff => '关';

  @override
  String get nextUpStatic => '固定（结束前 32 秒）';

  @override
  String get nextUpSmart => '智能（感知片尾字幕）';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSearchSettings => '搜索设置';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsSources => '来源';

  @override
  String get settingsPlayback => '播放';

  @override
  String get settingsData => '数据';

  @override
  String get settingsAdvanced => '高级';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsAboutVersion => '版本';

  @override
  String get settingsAboutUpdates => '更新';

  @override
  String get settingsAboutCheckForUpdates => '检查更新';

  @override
  String get settingsAboutUpToDate => '已是最新版本';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return '发现新版本：$version';
  }

  @override
  String get settingsAboutLicenses => '许可证';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsAccentColor => '强调色';

  @override
  String get settingsTextScale => '文字缩放';

  @override
  String get settingsDensity => '显示密度';

  @override
  String get settingsBackup => '备份与恢复';

  @override
  String get settingsBackupCreate => '创建备份';

  @override
  String get settingsBackupRestore => '恢复备份';

  @override
  String get settingsBackupAuto => '自动备份';

  @override
  String get settingsBackupCloudSync => '云同步';

  @override
  String get settingsParentalControls => '家长控制';

  @override
  String get settingsParentalSetPin => '设置 PIN';

  @override
  String get settingsParentalChangePin => '修改 PIN';

  @override
  String get settingsParentalRemovePin => '删除 PIN';

  @override
  String get settingsParentalBlockedCategories => '已屏蔽分类';

  @override
  String get settingsNetwork => '网络';

  @override
  String get settingsNetworkDiagnostics => '网络诊断';

  @override
  String get settingsNetworkProxy => '代理';

  @override
  String get settingsPlaybackHardwareDecoder => '硬件解码器';

  @override
  String get settingsPlaybackBufferSize => '缓冲大小';

  @override
  String get settingsPlaybackDeinterlace => '去隔行';

  @override
  String get settingsPlaybackUpscaling => '超分辨率';

  @override
  String get settingsPlaybackAudioOutput => '音频输出';

  @override
  String get settingsPlaybackLoudnessNorm => '响度标准化';

  @override
  String get settingsPlaybackVolumeBoost => '音量增强';

  @override
  String get settingsPlaybackAudioPassthrough => '音频直通';

  @override
  String get settingsPlaybackSegmentSkip => '片段跳过';

  @override
  String get settingsPlaybackNextUp => '下一集';

  @override
  String get settingsPlaybackScreensaver => '屏保';

  @override
  String get settingsPlaybackExternalPlayer => '外部播放器';

  @override
  String get settingsSourceAdd => '添加来源';

  @override
  String get settingsSourceEdit => '编辑来源';

  @override
  String get settingsSourceDelete => '删除来源';

  @override
  String get settingsSourceSync => '立即同步';

  @override
  String get settingsSourceSortOrder => '排列顺序';

  @override
  String get settingsDataClearCache => '清除缓存';

  @override
  String get settingsDataClearHistory => '清除观看历史';

  @override
  String get settingsDataExport => '导出数据';

  @override
  String get settingsDataImport => '导入数据';

  @override
  String get settingsAdvancedDebug => '调试模式';

  @override
  String get settingsAdvancedStreamProxy => '流代理';

  @override
  String get settingsAdvancedAutoUpdate => '自动更新';

  @override
  String get iptvMultiView => '多画面';

  @override
  String get iptvTvGuide => '电视节目指南';

  @override
  String get iptvBackToGroups => '返回分组';

  @override
  String get iptvSearchChannels => '搜索频道';

  @override
  String get iptvListGridView => '列表视图';

  @override
  String get iptvGridView => '网格视图';

  @override
  String iptvChannelHidden(String name) {
    return '$name 已隐藏';
  }

  @override
  String get iptvSortDone => '完成';

  @override
  String get iptvSortResetToDefault => '恢复默认';

  @override
  String get iptvSortByPlaylistOrder => '按播放列表顺序';

  @override
  String get iptvSortByName => '按名称';

  @override
  String get iptvSortByRecent => '按最近';

  @override
  String get iptvSortByPopularity => '按热度';

  @override
  String get epgNowPlaying => '正在播出';

  @override
  String get epgNoData => '暂无 EPG 数据';

  @override
  String get epgSetReminder => '设置提醒';

  @override
  String get epgCancelReminder => '取消提醒';

  @override
  String get epgRecord => '录制';

  @override
  String get epgCancelRecording => '取消录制';

  @override
  String get vodMovies => '电影';

  @override
  String get vodSeries => '剧集';

  @override
  String vodSeasonN(int number) {
    return '第 $number 季';
  }

  @override
  String vodEpisodeN(int number) {
    return '第 $number 集';
  }

  @override
  String get vodWatchNow => '立即观看';

  @override
  String get vodResume => '继续观看';

  @override
  String get vodContinueWatching => '继续观看';

  @override
  String get vodRecommended => '推荐';

  @override
  String get vodRecentlyAdded => '最近添加';

  @override
  String get vodNoItems => '未找到内容';

  @override
  String get dvrSchedule => '时间表';

  @override
  String get dvrRecordings => '录制';

  @override
  String get dvrScheduleRecording => '定时录制';

  @override
  String get dvrEditRecording => '编辑录制';

  @override
  String get dvrDeleteRecording => '删除录制';

  @override
  String get dvrNoRecordings => '暂无录制';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchHint => '搜索频道、电影、剧集…';

  @override
  String get searchNoResults => '未找到结果';

  @override
  String get searchFilterAll => '全部';

  @override
  String get searchFilterChannels => '频道';

  @override
  String get searchFilterMovies => '电影';

  @override
  String get searchFilterSeries => '剧集';

  @override
  String get searchFilterPrograms => 'Programs';

  @override
  String get searchEmptyHint =>
      'Search for channels, movies, series, or programs';

  @override
  String get searchRecentSearches => 'Recent Searches';

  @override
  String get searchClearAll => 'Clear All';

  @override
  String get searchRemoveFromHistory => 'Remove from history';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
  }

  @override
  String get homeWhatsOn => '正在播出';

  @override
  String get homeContinueWatching => '继续观看';

  @override
  String get homeRecentChannels => '最近频道';

  @override
  String get homeMyList => '我的列表';

  @override
  String get homeQuickAccess => '快速访问';

  @override
  String get favoritesTitle => '收藏';

  @override
  String get favoritesEmpty => '暂无收藏';

  @override
  String get favoritesAddSome => '将频道、电影或剧集添加到收藏';

  @override
  String get profilesTitle => '档案';

  @override
  String get profilesCreate => '创建档案';

  @override
  String get profilesEdit => '编辑档案';

  @override
  String get profilesDelete => '删除档案';

  @override
  String get profilesManage => '管理档案';

  @override
  String get profilesWhoIsWatching => '谁在观看？';

  @override
  String get onboardingWelcome => '欢迎使用 CrispyTivi';

  @override
  String get onboardingAddSource => '添加第一个来源';

  @override
  String get onboardingChooseType => '选择来源类型';

  @override
  String get onboardingIptv => 'IPTV（M3U / Xtream）';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => '正在连接并加载频道…';

  @override
  String get onboardingDone => '全部完成！';

  @override
  String get onboardingStartWatching => '开始观看';

  @override
  String get cloudSyncTitle => '云同步';

  @override
  String get cloudSyncSignInGoogle => '使用 Google 账号登录';

  @override
  String get cloudSyncSignOut => '退出登录';

  @override
  String cloudSyncLastSync(String time) {
    return '上次同步：$time';
  }

  @override
  String get cloudSyncNever => '从未';

  @override
  String get cloudSyncConflict => '同步冲突';

  @override
  String get cloudSyncKeepLocal => '保留本地数据';

  @override
  String get cloudSyncKeepRemote => '保留云端数据';

  @override
  String get castTitle => '投屏';

  @override
  String get castSearching => '正在搜索设备…';

  @override
  String get castNoDevices => '未找到设备';

  @override
  String get castDisconnect => '断开连接';

  @override
  String get multiviewTitle => '多画面';

  @override
  String get multiviewAddStream => '添加流';

  @override
  String get multiviewRemoveStream => '删除流';

  @override
  String get multiviewSaveLayout => '保存布局';

  @override
  String get multiviewLoadLayout => '加载布局';

  @override
  String get multiviewLayoutName => '布局名称';

  @override
  String get multiviewDeleteLayout => '删除布局';

  @override
  String get mediaServerUrl => '服务器地址';

  @override
  String get mediaServerUsername => '用户名';

  @override
  String get mediaServerPassword => '密码';

  @override
  String get mediaServerSignIn => '登录';

  @override
  String get mediaServerConnecting => '连接中…';

  @override
  String get mediaServerConnectionFailed => '连接失败';

  @override
  String onboardingChannelsLoaded(int count) {
    return '已加载 $count 个频道！';
  }

  @override
  String get onboardingEnterApp => '进入应用';

  @override
  String get onboardingEnterAppLabel => '进入应用';

  @override
  String get onboardingCouldNotConnect => '无法连接';

  @override
  String get onboardingRetryLabel => '重新连接';

  @override
  String get onboardingEditSource => '编辑来源详情';

  @override
  String get playerAudioSectionLabel => '音频';

  @override
  String get playerSubtitlesSectionLabel => '字幕';

  @override
  String get playerSwitchProfileTitle => '切换档案';

  @override
  String get playerCopyStreamUrl => '复制直播地址';

  @override
  String get cloudSyncSyncing => '同步中…';

  @override
  String get cloudSyncNow => '立即同步';

  @override
  String get cloudSyncForceUpload => '强制上传';

  @override
  String get cloudSyncForceDownload => '强制下载';

  @override
  String get cloudSyncAutoSync => '自动同步';

  @override
  String get cloudSyncThisDevice => '本设备';

  @override
  String get cloudSyncCloud => '云端';

  @override
  String get cloudSyncNewer => '更新';

  @override
  String get contextMenuAddFavorite => '添加到收藏';

  @override
  String get contextMenuRemoveFavorite => '从收藏中删除';

  @override
  String get contextMenuSwitchStream => '切换流来源';

  @override
  String get contextMenuCopyUrl => '复制直播地址';

  @override
  String get contextMenuOpenExternal => '用外部播放器打开';

  @override
  String get contextMenuPlay => '播放';

  @override
  String get contextMenuAddFavoriteCategory => '添加到收藏分类';

  @override
  String get contextMenuRemoveFavoriteCategory => '从收藏分类中删除';

  @override
  String get contextMenuFilterCategory => '按此分类筛选';

  @override
  String get confirmDeleteCancel => '取消';

  @override
  String get confirmDeleteAction => '删除';
}
