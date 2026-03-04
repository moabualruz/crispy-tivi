import 'package:crispy_tivi/features/iptv/domain/entities/'
    'channel.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/'
    'epg_entry.dart';
import 'package:crispy_tivi/core/domain/entities/playlist_source.dart';
import 'package:crispy_tivi/features/profiles/domain/entities/'
    'user_profile.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/'
    'dvr_permission.dart';
import 'package:crispy_tivi/features/profiles/domain/enums/'
    'user_role.dart';
import 'package:crispy_tivi/features/vod/domain/entities/'
    'vod_item.dart';

/// Comprehensive test data simulating a demo Xtream
/// source with 50 channels, 20 VOD items, and EPG data.
abstract final class TestData {
  // ── Credentials ──

  static const _server = 'https://xtream-codes-mock-api.wizju.com';
  static const _user = 'test_user';
  static const _pass = 'test_pass';
  static const _sourceId = 'test_xtream_wizju';

  // ── Profiles ──

  static const adminProfile = UserProfile(
    id: 'admin',
    name: 'Admin',
    avatarIndex: 0,
    isActive: true,
    pinVersion: 1,
    role: UserRole.admin,
    dvrPermission: DvrPermission.full,
  );

  static const childProfile = UserProfile(
    id: 'child',
    name: 'Kids',
    avatarIndex: 2,
    isChild: true,
    maxAllowedRating: 2,
    pinVersion: 1,
    role: UserRole.viewer,
    dvrPermission: DvrPermission.viewOnly,
  );

  static const pinnedProfile = UserProfile(
    id: 'pinned',
    name: 'Secure',
    avatarIndex: 1,
    pin: 'hashed_pin_value',
    pinVersion: 1,
    role: UserRole.viewer,
    dvrPermission: DvrPermission.full,
  );

  // ── Playlist Sources ──

  static const xtreamSource = PlaylistSource(
    id: _sourceId,
    name: 'Wizju Mock',
    url: _server,
    type: PlaylistSourceType.xtream,
    username: _user,
    password: _pass,
    epgUrl:
        '$_server/xmltv.php?'
        'username=$_user&password=$_pass',
  );

  static const m3uSource = PlaylistSource(
    id: 'src_2',
    name: 'Test M3U',
    url: 'http://test.iptv.com/playlist.m3u',
    type: PlaylistSourceType.m3u,
  );

  // ── Channels (50 across 10 groups) ──

  static List<Channel> get sampleChannels => const [
    // ── UK Entertainment (5) ──
    Channel(
      id: 'xc_1001',
      name: 'BBC One',
      streamUrl: '$_server/$_user/$_pass/1001',
      number: 1,
      group: 'UK Entertainment',
      logoUrl: 'https://example.com/logos/bbc_one.png',
      tvgId: 'BBC1.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_1002',
      name: 'BBC Two',
      streamUrl: '$_server/$_user/$_pass/1002',
      number: 2,
      group: 'UK Entertainment',
      logoUrl: 'https://example.com/logos/bbc_two.png',
      tvgId: 'BBC2.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_1003',
      name: 'ITV',
      streamUrl: '$_server/$_user/$_pass/1003',
      number: 3,
      group: 'UK Entertainment',
      logoUrl: 'https://example.com/logos/itv.png',
      tvgId: 'ITV1.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_1004',
      name: 'Channel 4',
      streamUrl: '$_server/$_user/$_pass/1004',
      number: 4,
      group: 'UK Entertainment',
      logoUrl: 'https://example.com/logos/channel4.png',
      tvgId: 'C4.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_1005',
      name: 'Channel 5',
      streamUrl: '$_server/$_user/$_pass/1005',
      number: 5,
      group: 'UK Entertainment',
      logoUrl: 'https://example.com/logos/channel5.png',
      tvgId: 'C5.uk',
      sourceId: _sourceId,
    ),

    // ── US News (5) ──
    Channel(
      id: 'xc_2001',
      name: 'CNN',
      streamUrl: '$_server/$_user/$_pass/2001',
      number: 6,
      group: 'US News',
      logoUrl: 'https://example.com/logos/cnn.png',
      tvgId: 'CNN.us',
      sourceId: _sourceId,
      hasCatchup: true,
      catchupDays: 3,
    ),
    Channel(
      id: 'xc_2002',
      name: 'Fox News',
      streamUrl: '$_server/$_user/$_pass/2002',
      number: 7,
      group: 'US News',
      logoUrl: 'https://example.com/logos/foxnews.png',
      tvgId: 'FOX.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_2003',
      name: 'MSNBC',
      streamUrl: '$_server/$_user/$_pass/2003',
      number: 8,
      group: 'US News',
      logoUrl: 'https://example.com/logos/msnbc.png',
      tvgId: 'MSNBC.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_2004',
      name: 'ABC News',
      streamUrl: '$_server/$_user/$_pass/2004',
      number: 9,
      group: 'US News',
      logoUrl: 'https://example.com/logos/abcnews.png',
      tvgId: 'ABCNEWS.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_2005',
      name: 'NBC News',
      streamUrl: '$_server/$_user/$_pass/2005',
      number: 10,
      group: 'US News',
      logoUrl: 'https://example.com/logos/nbcnews.png',
      tvgId: 'NBCNEWS.us',
      sourceId: _sourceId,
    ),

    // ── Sports (5) ──
    Channel(
      id: 'xc_3001',
      name: 'ESPN',
      streamUrl: '$_server/$_user/$_pass/3001',
      number: 11,
      group: 'Sports',
      logoUrl: 'https://example.com/logos/espn.png',
      tvgId: 'ESPN.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_3002',
      name: 'Sky Sports Main Event',
      streamUrl: '$_server/$_user/$_pass/3002',
      number: 12,
      group: 'Sports',
      logoUrl: 'https://example.com/logos/skysports.png',
      tvgId: 'SKYSME.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_3003',
      name: 'beIN Sports 1',
      streamUrl: '$_server/$_user/$_pass/3003',
      number: 13,
      group: 'Sports',
      logoUrl: 'https://example.com/logos/beinsports.png',
      tvgId: 'BEIN1.qa',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_3004',
      name: 'Eurosport 1',
      streamUrl: '$_server/$_user/$_pass/3004',
      number: 14,
      group: 'Sports',
      logoUrl: 'https://example.com/logos/eurosport.png',
      tvgId: 'EURO1.eu',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_3005',
      name: 'DAZN 1',
      streamUrl: '$_server/$_user/$_pass/3005',
      number: 15,
      group: 'Sports',
      logoUrl: 'https://example.com/logos/dazn.png',
      tvgId: 'DAZN1.de',
      sourceId: _sourceId,
    ),

    // ── Movies (5) ──
    Channel(
      id: 'xc_4001',
      name: 'Sky Cinema Premiere',
      streamUrl: '$_server/$_user/$_pass/4001',
      number: 16,
      group: 'Movies',
      logoUrl: 'https://example.com/logos/skycinema.png',
      tvgId: 'SKYCP.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_4002',
      name: 'HBO',
      streamUrl: '$_server/$_user/$_pass/4002',
      number: 17,
      group: 'Movies',
      logoUrl: 'https://example.com/logos/hbo.png',
      tvgId: 'HBO.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_4003',
      name: 'Cinemax',
      streamUrl: '$_server/$_user/$_pass/4003',
      number: 18,
      group: 'Movies',
      logoUrl: 'https://example.com/logos/cinemax.png',
      tvgId: 'CINEMAX.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_4004',
      name: 'Film4',
      streamUrl: '$_server/$_user/$_pass/4004',
      number: 19,
      group: 'Movies',
      logoUrl: 'https://example.com/logos/film4.png',
      tvgId: 'FILM4.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_4005',
      name: 'TCM',
      streamUrl: '$_server/$_user/$_pass/4005',
      number: 20,
      group: 'Movies',
      logoUrl: 'https://example.com/logos/tcm.png',
      tvgId: 'TCM.us',
      sourceId: _sourceId,
    ),

    // ── Kids (5) ──
    Channel(
      id: 'xc_5001',
      name: 'Cartoon Network',
      streamUrl: '$_server/$_user/$_pass/5001',
      number: 21,
      group: 'Kids',
      logoUrl:
          'https://example.com/logos/'
          'cartoonnetwork.png',
      tvgId: 'CN.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_5002',
      name: 'Nickelodeon',
      streamUrl: '$_server/$_user/$_pass/5002',
      number: 22,
      group: 'Kids',
      logoUrl: 'https://example.com/logos/nick.png',
      tvgId: 'NICK.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_5003',
      name: 'Disney Channel',
      streamUrl: '$_server/$_user/$_pass/5003',
      number: 23,
      group: 'Kids',
      logoUrl: 'https://example.com/logos/disney.png',
      tvgId: 'DISNEY.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_5004',
      name: 'CBeebies',
      streamUrl: '$_server/$_user/$_pass/5004',
      number: 24,
      group: 'Kids',
      logoUrl: 'https://example.com/logos/cbeebies.png',
      tvgId: 'CBEEB.uk',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_5005',
      name: 'Baby TV',
      streamUrl: '$_server/$_user/$_pass/5005',
      number: 25,
      group: 'Kids',
      logoUrl: 'https://example.com/logos/babytv.png',
      tvgId: 'BABYTV.il',
      sourceId: _sourceId,
    ),

    // ── Music (5) ──
    Channel(
      id: 'xc_6001',
      name: 'MTV',
      streamUrl: '$_server/$_user/$_pass/6001',
      number: 26,
      group: 'Music',
      logoUrl: 'https://example.com/logos/mtv.png',
      tvgId: 'MTV.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_6002',
      name: 'VH1',
      streamUrl: '$_server/$_user/$_pass/6002',
      number: 27,
      group: 'Music',
      logoUrl: 'https://example.com/logos/vh1.png',
      tvgId: 'VH1.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_6003',
      name: 'VIVA',
      streamUrl: '$_server/$_user/$_pass/6003',
      number: 28,
      group: 'Music',
      logoUrl: 'https://example.com/logos/viva.png',
      tvgId: 'VIVA.de',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_6004',
      name: 'Trace Urban',
      streamUrl: '$_server/$_user/$_pass/6004',
      number: 29,
      group: 'Music',
      logoUrl:
          'https://example.com/logos/'
          'traceurban.png',
      tvgId: 'TRACE.fr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_6005',
      name: 'Stingray Music',
      streamUrl: '$_server/$_user/$_pass/6005',
      number: 30,
      group: 'Music',
      logoUrl: 'https://example.com/logos/stingray.png',
      tvgId: 'STING.ca',
      sourceId: _sourceId,
    ),

    // ── Documentary (5) ──
    Channel(
      id: 'xc_7001',
      name: 'National Geographic',
      streamUrl: '$_server/$_user/$_pass/7001',
      number: 31,
      group: 'Documentary',
      logoUrl: 'https://example.com/logos/natgeo.png',
      tvgId: 'NATGEO.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_7002',
      name: 'Discovery Channel',
      streamUrl: '$_server/$_user/$_pass/7002',
      number: 32,
      group: 'Documentary',
      logoUrl: 'https://example.com/logos/discovery.png',
      tvgId: 'DISC.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_7003',
      name: 'History Channel',
      streamUrl: '$_server/$_user/$_pass/7003',
      number: 33,
      group: 'Documentary',
      logoUrl: 'https://example.com/logos/history.png',
      tvgId: 'HIST.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_7004',
      name: 'Animal Planet',
      streamUrl: '$_server/$_user/$_pass/7004',
      number: 34,
      group: 'Documentary',
      logoUrl:
          'https://example.com/logos/'
          'animalplanet.png',
      tvgId: 'ANIMAL.us',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_7005',
      name: 'BBC Earth',
      streamUrl: '$_server/$_user/$_pass/7005',
      number: 35,
      group: 'Documentary',
      logoUrl: 'https://example.com/logos/bbcearth.png',
      tvgId: 'BBCEARTH.uk',
      sourceId: _sourceId,
    ),

    // ── German (5) ──
    Channel(
      id: 'xc_8001',
      name: 'Das Erste',
      streamUrl: '$_server/$_user/$_pass/8001',
      number: 36,
      group: 'German',
      logoUrl: 'https://example.com/logos/daserste.png',
      tvgId: 'ARD.de',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_8002',
      name: 'ZDF',
      streamUrl: '$_server/$_user/$_pass/8002',
      number: 37,
      group: 'German',
      logoUrl: 'https://example.com/logos/zdf.png',
      tvgId: 'ZDF.de',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_8003',
      name: 'RTL',
      streamUrl: '$_server/$_user/$_pass/8003',
      number: 38,
      group: 'German',
      logoUrl: 'https://example.com/logos/rtl.png',
      tvgId: 'RTL.de',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_8004',
      name: 'ProSieben',
      streamUrl: '$_server/$_user/$_pass/8004',
      number: 39,
      group: 'German',
      logoUrl: 'https://example.com/logos/prosieben.png',
      tvgId: 'PRO7.de',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_8005',
      name: 'SAT.1',
      streamUrl: '$_server/$_user/$_pass/8005',
      number: 40,
      group: 'German',
      logoUrl: 'https://example.com/logos/sat1.png',
      tvgId: 'SAT1.de',
      sourceId: _sourceId,
    ),

    // ── French (5) ──
    Channel(
      id: 'xc_9001',
      name: 'TF1',
      streamUrl: '$_server/$_user/$_pass/9001',
      number: 41,
      group: 'French',
      logoUrl: 'https://example.com/logos/tf1.png',
      tvgId: 'TF1.fr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_9002',
      name: 'France 2',
      streamUrl: '$_server/$_user/$_pass/9002',
      number: 42,
      group: 'French',
      logoUrl: 'https://example.com/logos/france2.png',
      tvgId: 'FR2.fr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_9003',
      name: 'France 3',
      streamUrl: '$_server/$_user/$_pass/9003',
      number: 43,
      group: 'French',
      logoUrl: 'https://example.com/logos/france3.png',
      tvgId: 'FR3.fr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_9004',
      name: 'Canal+',
      streamUrl: '$_server/$_user/$_pass/9004',
      number: 44,
      group: 'French',
      logoUrl: 'https://example.com/logos/canalplus.png',
      tvgId: 'CANAL.fr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_9005',
      name: 'M6',
      streamUrl: '$_server/$_user/$_pass/9005',
      number: 45,
      group: 'French',
      logoUrl: 'https://example.com/logos/m6.png',
      tvgId: 'M6.fr',
      sourceId: _sourceId,
    ),

    // ── Turkish (5) ──
    Channel(
      id: 'xc_10001',
      name: 'TRT 1',
      streamUrl: '$_server/$_user/$_pass/10001',
      number: 46,
      group: 'Turkish',
      logoUrl: 'https://example.com/logos/trt1.png',
      tvgId: 'TRT1.tr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_10002',
      name: 'ATV',
      streamUrl: '$_server/$_user/$_pass/10002',
      number: 47,
      group: 'Turkish',
      logoUrl: 'https://example.com/logos/atv.png',
      tvgId: 'ATV.tr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_10003',
      name: 'Star TV',
      streamUrl: '$_server/$_user/$_pass/10003',
      number: 48,
      group: 'Turkish',
      logoUrl: 'https://example.com/logos/startv.png',
      tvgId: 'STAR.tr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_10004',
      name: 'Show TV',
      streamUrl: '$_server/$_user/$_pass/10004',
      number: 49,
      group: 'Turkish',
      logoUrl: 'https://example.com/logos/showtv.png',
      tvgId: 'SHOW.tr',
      sourceId: _sourceId,
    ),
    Channel(
      id: 'xc_10005',
      name: 'Kanal D',
      streamUrl: '$_server/$_user/$_pass/10005',
      number: 50,
      group: 'Turkish',
      logoUrl: 'https://example.com/logos/kanald.png',
      tvgId: 'KANALD.tr',
      sourceId: _sourceId,
    ),
  ];

  // ── VOD Items (15 movies + 5 series episodes) ──

  static const _movieBase = '$_server/movie/$_user/$_pass';

  static List<VodItem> get sampleVodItems => const [
    // ── Action (3) ──
    VodItem(
      id: 'vod_101',
      name: 'The Matrix',
      streamUrl: '$_movieBase/101.mkv',
      type: VodType.movie,
      posterUrl: 'https://example.com/posters/matrix.jpg',
      description:
          'A computer programmer discovers reality '
          'is a simulation.',
      rating: '8.7',
      year: 1999,
      duration: 136,
      category: 'Action',
    ),
    VodItem(
      id: 'vod_102',
      name: 'Mad Max: Fury Road',
      streamUrl: '$_movieBase/102.mkv',
      type: VodType.movie,
      posterUrl: 'https://example.com/posters/madmax.jpg',
      description:
          'In a post-apocalyptic wasteland, Max '
          'teams up with Furiosa.',
      rating: '8.1',
      year: 2015,
      duration: 120,
      category: 'Action',
    ),
    VodItem(
      id: 'vod_103',
      name: 'John Wick',
      streamUrl: '$_movieBase/103.mkv',
      type: VodType.movie,
      posterUrl: 'https://example.com/posters/johnwick.jpg',
      description:
          'A retired hitman seeks vengeance for '
          'the killing of his dog.',
      rating: '7.4',
      year: 2014,
      duration: 101,
      category: 'Action',
    ),

    // ── Sci-Fi (3) ──
    VodItem(
      id: 'vod_201',
      name: 'Inception',
      streamUrl: '$_movieBase/201.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'inception.jpg',
      description:
          'A thief who enters dreams to steal '
          'secrets.',
      rating: '8.8',
      year: 2010,
      duration: 148,
      category: 'Sci-Fi',
    ),
    VodItem(
      id: 'vod_202',
      name: 'Interstellar',
      streamUrl: '$_movieBase/202.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'interstellar.jpg',
      description:
          'Explorers travel through a wormhole '
          'near Saturn.',
      rating: '8.6',
      year: 2014,
      duration: 169,
      category: 'Sci-Fi',
    ),
    VodItem(
      id: 'vod_203',
      name: 'Blade Runner 2049',
      streamUrl: '$_movieBase/203.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'bladerunner2049.jpg',
      description:
          'A new blade runner unearths a long-'
          'buried secret.',
      rating: '8.0',
      year: 2017,
      duration: 164,
      category: 'Sci-Fi',
    ),

    // ── Drama (3) ──
    VodItem(
      id: 'vod_301',
      name: 'The Godfather',
      streamUrl: '$_movieBase/301.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'godfather.jpg',
      description:
          'The aging patriarch of a crime dynasty '
          'transfers control.',
      rating: '9.2',
      year: 1972,
      duration: 175,
      category: 'Drama',
    ),
    VodItem(
      id: 'vod_302',
      name: 'The Shawshank Redemption',
      streamUrl: '$_movieBase/302.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'shawshank.jpg',
      description:
          'Two imprisoned men bond over years, '
          'finding solace and redemption.',
      rating: '9.3',
      year: 1994,
      duration: 142,
      category: 'Drama',
    ),
    VodItem(
      id: 'vod_303',
      name: 'Schindlers List',
      streamUrl: '$_movieBase/303.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'schindler.jpg',
      description:
          'A German businessman saves the lives '
          'of over a thousand refugees.',
      rating: '9.0',
      year: 1993,
      duration: 195,
      category: 'Drama',
    ),

    // ── Comedy (3) ──
    VodItem(
      id: 'vod_401',
      name: 'The Grand Budapest Hotel',
      streamUrl: '$_movieBase/401.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'grandbudapest.jpg',
      description:
          'A legendary concierge and his protege '
          'solve a stolen painting mystery.',
      rating: '8.1',
      year: 2014,
      duration: 99,
      category: 'Comedy',
    ),
    VodItem(
      id: 'vod_402',
      name: 'Superbad',
      streamUrl: '$_movieBase/402.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'superbad.jpg',
      description:
          'Two teens try to make the most of '
          'their final weeks of high school.',
      rating: '7.6',
      year: 2007,
      duration: 113,
      category: 'Comedy',
    ),
    VodItem(
      id: 'vod_403',
      name: 'The Big Lebowski',
      streamUrl: '$_movieBase/403.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'lebowski.jpg',
      description:
          'The Dude gets mixed up in a '
          'kidnapping scheme.',
      rating: '8.1',
      year: 1998,
      duration: 117,
      category: 'Comedy',
    ),

    // ── Horror (3) ──
    VodItem(
      id: 'vod_501',
      name: 'The Shining',
      streamUrl: '$_movieBase/501.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'shining.jpg',
      description:
          'A family heads to an isolated hotel '
          'for the winter.',
      rating: '8.4',
      year: 1980,
      duration: 146,
      category: 'Horror',
    ),
    VodItem(
      id: 'vod_502',
      name: 'Get Out',
      streamUrl: '$_movieBase/502.mkv',
      type: VodType.movie,
      posterUrl:
          'https://example.com/posters/'
          'getout.jpg',
      description:
          'A young man visits his girlfriends '
          'mysterious family estate.',
      rating: '7.7',
      year: 2017,
      duration: 104,
      category: 'Horror',
    ),

    // ── Series: Breaking Bad (3 episodes) ──
    VodItem(
      id: 'vod_601',
      name: 'Breaking Bad S01E01',
      streamUrl: '$_movieBase/601.mkv',
      type: VodType.episode,
      posterUrl:
          'https://example.com/posters/'
          'breakingbad.jpg',
      description:
          'A chemistry teacher turns to making '
          'meth after a cancer diagnosis.',
      rating: '9.5',
      year: 2008,
      category: 'Drama',
      seriesId: 'series_bb',
      seasonNumber: 1,
      episodeNumber: 1,
    ),
    VodItem(
      id: 'vod_602',
      name: 'Breaking Bad S01E02',
      streamUrl: '$_movieBase/602.mkv',
      type: VodType.episode,
      posterUrl:
          'https://example.com/posters/'
          'breakingbad.jpg',
      description:
          'Walt and Jesse attempt to dispose of '
          'evidence.',
      rating: '9.0',
      year: 2008,
      category: 'Drama',
      seriesId: 'series_bb',
      seasonNumber: 1,
      episodeNumber: 2,
    ),
    VodItem(
      id: 'vod_603',
      name: 'Breaking Bad S01E03',
      streamUrl: '$_movieBase/603.mkv',
      type: VodType.episode,
      posterUrl:
          'https://example.com/posters/'
          'breakingbad.jpg',
      description:
          'Walt and Jesse face a new threat from '
          'a rival dealer.',
      rating: '8.8',
      year: 2008,
      category: 'Drama',
      seriesId: 'series_bb',
      seasonNumber: 1,
      episodeNumber: 3,
    ),

    // ── Series: Stranger Things (2 episodes) ──
    VodItem(
      id: 'vod_701',
      name: 'Stranger Things S01E01',
      streamUrl: '$_movieBase/701.mkv',
      type: VodType.episode,
      posterUrl:
          'https://example.com/posters/'
          'strangerthings.jpg',
      description:
          'A boy vanishes and his friends '
          'encounter a strange girl.',
      rating: '8.7',
      year: 2016,
      category: 'Sci-Fi',
      seriesId: 'series_st',
      seasonNumber: 1,
      episodeNumber: 1,
    ),
    VodItem(
      id: 'vod_702',
      name: 'Stranger Things S01E02',
      streamUrl: '$_movieBase/702.mkv',
      type: VodType.episode,
      posterUrl:
          'https://example.com/posters/'
          'strangerthings.jpg',
      description:
          'The search for the missing boy '
          'intensifies.',
      rating: '8.5',
      year: 2016,
      category: 'Sci-Fi',
      seriesId: 'series_st',
      seasonNumber: 1,
      episodeNumber: 2,
    ),
  ];

  // ── EPG Entries (first 10 channels, 3 programs each) ──

  /// Returns EPG data for the first 10 channels.
  ///
  /// Each channel gets three programmes:
  /// - Past (ended 1h ago)
  /// - Current (started 30min ago, ends in 30min)
  /// - Future (starts in 1h)
  static Map<String, List<EpgEntry>> get sampleEpg {
    final now = DateTime.now();
    final tvgIds = [
      'BBC1.uk',
      'BBC2.uk',
      'ITV1.uk',
      'C4.uk',
      'C5.uk',
      'CNN.us',
      'FOX.us',
      'MSNBC.us',
      'ABCNEWS.us',
      'NBCNEWS.us',
    ];

    // Descriptive programme titles per channel.
    const titles = [
      // BBC1.uk
      ['BBC Breakfast', 'Morning Live', 'Homes Under the Hammer'],
      // BBC2.uk
      ['Gardeners World', 'Politics Live', 'Antiques Roadshow'],
      // ITV1.uk
      ['Good Morning Britain', 'Lorraine', 'This Morning'],
      // C4.uk
      ['Countdown', 'A Place in the Sun', 'Come Dine with Me'],
      // C5.uk
      ['Milkshake!', 'Jeremy Vine', 'Home and Away'],
      // CNN.us
      ['CNN This Morning', 'Newsroom Live', 'The Situation Room'],
      // FOX.us
      ['Fox and Friends', 'Americas Newsroom', 'The Five'],
      // MSNBC.us
      ['Morning Joe', 'MSNBC Reports', 'Deadline: White House'],
      // ABCNEWS.us
      ['World News Now', 'Good Morning America', 'ABC News Live'],
      // NBCNEWS.us
      ['Early Today', 'Today Show', 'NBC Nightly News'],
    ];

    final result = <String, List<EpgEntry>>{};

    for (var i = 0; i < tvgIds.length; i++) {
      final id = tvgIds[i];
      final t = titles[i];
      result[id] = [
        // Past: ended 1h ago.
        EpgEntry(
          channelId: id,
          title: t[0],
          startTime: now.subtract(const Duration(hours: 2)),
          endTime: now.subtract(const Duration(hours: 1)),
          description: '${t[0]} — previously aired.',
        ),
        // Current: started 30min ago, ends in 30min.
        EpgEntry(
          channelId: id,
          title: t[1],
          startTime: now.subtract(const Duration(minutes: 30)),
          endTime: now.add(const Duration(minutes: 30)),
          description: '${t[1]} — currently airing.',
        ),
        // Future: starts in 1h.
        EpgEntry(
          channelId: id,
          title: t[2],
          startTime: now.add(const Duration(hours: 1)),
          endTime: now.add(const Duration(hours: 2)),
          description: '${t[2]} — upcoming.',
        ),
      ];
    }
    return result;
  }
}
