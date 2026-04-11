import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';

const List<String> liveTvGroups = <String>[
  'All channels',
  'Favorites',
  'News',
  'Sports',
  'Movies',
  'Kids',
];

const List<ChannelEntry> liveTvChannels = <ChannelEntry>[
  ChannelEntry(
    number: '101',
    name: 'Crispy One',
    program: 'Midnight Bulletin',
    timeRange: '21:00 - 22:00',
  ),
  ChannelEntry(
    number: '118',
    name: 'Arena Live',
    program: 'Championship Replay',
    timeRange: '21:30 - 23:30',
  ),
  ChannelEntry(
    number: '205',
    name: 'Cinema Vault',
    program: 'Coastal Drive',
    timeRange: '20:45 - 22:35',
  ),
  ChannelEntry(
    number: '311',
    name: 'Nature Atlas',
    program: 'Winter Oceans',
    timeRange: '21:15 - 22:15',
  ),
];

const List<List<String>> guideRows = <List<String>>[
  <String>['Now', '21:30', '22:00', '22:30', '23:00'],
  <String>['Crispy One', 'Bulletin', 'Market Close', 'Nightline', 'Forecast'],
  <String>['Arena Live', 'Replay', 'Analysis', 'Locker Room', 'Highlights'],
  <String>[
    'Cinema Vault',
    'Coastal Drive',
    'Coastal Drive',
    'Studio Cut',
    'Trailer Reel',
  ],
  <String>[
    'Nature Atlas',
    'Winter Oceans',
    'Arctic Voices',
    'Wild Frontiers',
    'Night Shift',
  ],
];
