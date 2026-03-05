import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';

/// Fetches the public user list from an Emby or Jellyfin server before login.
///
/// Both server types expose `/Users/Public` without authentication.
/// Requires a normalized server [url]. Returns the list of
/// [MediaServerUser] objects or an empty list on any error.
///
/// Used by [EmbyLoginScreen] (FE-EB-02) and [JellyfinLoginScreen] (FE-JF-02)
/// to render the user-picker avatar row before credentials are entered.
final mediaServerPublicUsersProvider = FutureProvider.autoDispose
    .family<List<MediaServerUser>, String>((ref, url) async {
      if (url.isEmpty) return [];
      try {
        final dio = Dio(BaseOptions(baseUrl: url));
        final response = await dio.get<List<dynamic>>('/Users/Public');
        final data = response.data;
        if (data == null) return [];
        return data
            .cast<Map<String, dynamic>>()
            .map(MediaServerUser.fromJson)
            .toList();
      } catch (_) {
        return [];
      }
    });
