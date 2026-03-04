/// Static UTC offset table (minutes) for common IANA timezone names.
///
/// Used as a synchronous fallback in [MemoryBackend] and [WsBackend]
/// where async backend calls are not possible. Does NOT account for
/// DST — offsets are standard-time values.
const Map<String, int> kStaticTimezoneOffsetMinutes = {
  'UTC': 0,
  'America/New_York': -300,
  'America/Chicago': -360,
  'America/Denver': -420,
  'America/Los_Angeles': -480,
  'America/Sao_Paulo': -180,
  'Europe/London': 0,
  'Europe/Paris': 60,
  'Europe/Berlin': 60,
  'Europe/Moscow': 180,
  'Asia/Dubai': 240,
  'Asia/Kolkata': 330,
  'Asia/Shanghai': 480,
  'Asia/Tokyo': 540,
  'Asia/Seoul': 540,
  'Australia/Sydney': 600,
};
