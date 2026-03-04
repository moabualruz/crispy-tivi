import 'package:crispy_tivi/features/iptv/data/models/'
    'channel_model.dart';
import 'package:crispy_tivi/features/iptv/domain/entities/'
    'channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChannelModel', () {
    // ── Helpers ────────────────────────────────────────

    ChannelModel makeModel({
      String id = 'ch1',
      String name = 'Test Channel',
      String streamUrl = 'http://example.com/stream',
      int? number,
      String? group,
      String? logoUrl,
      String? tvgId,
      String? tvgName,
      bool isFavorite = false,
      String? userAgent,
      String? sourceId,
      bool hasCatchup = false,
      int catchupDays = 0,
      String? catchupType,
      String? catchupSource,
    }) {
      return ChannelModel(
        id: id,
        name: name,
        streamUrl: streamUrl,
        number: number,
        group: group,
        logoUrl: logoUrl,
        tvgId: tvgId,
        tvgName: tvgName,
        isFavorite: isFavorite,
        userAgent: userAgent,
        sourceId: sourceId,
        hasCatchup: hasCatchup,
        catchupDays: catchupDays,
        catchupType: catchupType,
        catchupSource: catchupSource,
      );
    }

    Channel makeDomain({
      String id = 'ch1',
      String name = 'Test Channel',
      String streamUrl = 'http://example.com/stream',
      int? number,
      String? group,
      String? logoUrl,
      String? tvgId,
      String? tvgName,
      bool isFavorite = false,
      String? userAgent,
      bool hasCatchup = false,
      int catchupDays = 0,
      String? catchupType,
      String? catchupSource,
      String? sourceId,
    }) {
      return Channel(
        id: id,
        name: name,
        streamUrl: streamUrl,
        number: number,
        group: group,
        logoUrl: logoUrl,
        tvgId: tvgId,
        tvgName: tvgName,
        isFavorite: isFavorite,
        userAgent: userAgent,
        hasCatchup: hasCatchup,
        catchupDays: catchupDays,
        catchupType: catchupType,
        catchupSource: catchupSource,
        sourceId: sourceId,
      );
    }

    // ── Constructor ────────────────────────────────────

    group('constructor', () {
      test('creates model with required fields', () {
        final model = ChannelModel(
          id: 'ch1',
          name: 'CNN',
          streamUrl: 'http://cnn.com/live',
        );
        expect(model.id, 'ch1');
        expect(model.name, 'CNN');
        expect(model.streamUrl, 'http://cnn.com/live');
        expect(model.obxId, 0);
        expect(model.isFavorite, false);
        expect(model.hasCatchup, false);
        expect(model.catchupDays, 0);
      });

      test('creates model with all optional fields', () {
        final model = makeModel(
          number: 42,
          group: 'News',
          logoUrl: 'http://logo.png',
          tvgId: 'cnn.us',
          tvgName: 'CNN US',
          isFavorite: true,
          userAgent: 'CustomAgent/1.0',
          sourceId: 'src1',
          hasCatchup: true,
          catchupDays: 7,
          catchupType: 'flussonic',
          catchupSource: 'http://catchup/{utc}',
        );
        expect(model.number, 42);
        expect(model.group, 'News');
        expect(model.logoUrl, 'http://logo.png');
        expect(model.tvgId, 'cnn.us');
        expect(model.tvgName, 'CNN US');
        expect(model.isFavorite, true);
        expect(model.userAgent, 'CustomAgent/1.0');
        expect(model.sourceId, 'src1');
        expect(model.hasCatchup, true);
        expect(model.catchupDays, 7);
        expect(model.catchupType, 'flussonic');
        expect(model.catchupSource, 'http://catchup/{utc}');
      });

      test('defaults optional fields to null or'
          ' false', () {
        final model = makeModel();
        expect(model.number, isNull);
        expect(model.group, isNull);
        expect(model.logoUrl, isNull);
        expect(model.tvgId, isNull);
        expect(model.tvgName, isNull);
        expect(model.userAgent, isNull);
        expect(model.sourceId, isNull);
        expect(model.catchupType, isNull);
        expect(model.catchupSource, isNull);
      });
    });

    // ── toDomain ──────────────────────────────────────

    group('toDomain', () {
      test('maps all required fields to domain entity', () {
        final model = makeModel();
        final domain = model.toDomain();
        expect(domain, isA<Channel>());
        expect(domain.id, 'ch1');
        expect(domain.name, 'Test Channel');
        expect(domain.streamUrl, 'http://example.com/stream');
      });

      test('maps all optional fields to domain entity', () {
        final model = makeModel(
          number: 5,
          group: 'Sports',
          logoUrl: 'http://logo.png',
          tvgId: 'espn.us',
          tvgName: 'ESPN',
          isFavorite: true,
          userAgent: 'Agent/2.0',
          sourceId: 'src2',
          hasCatchup: true,
          catchupDays: 3,
          catchupType: 'shift',
          catchupSource: 'http://shift/{utc}',
        );
        final domain = model.toDomain();
        expect(domain.number, 5);
        expect(domain.group, 'Sports');
        expect(domain.logoUrl, 'http://logo.png');
        expect(domain.tvgId, 'espn.us');
        expect(domain.tvgName, 'ESPN');
        expect(domain.isFavorite, true);
        expect(domain.userAgent, 'Agent/2.0');
        expect(domain.sourceId, 'src2');
        expect(domain.hasCatchup, true);
        expect(domain.catchupDays, 3);
        expect(domain.catchupType, 'shift');
        expect(domain.catchupSource, 'http://shift/{utc}');
      });

      test('preserves null optionals in domain entity', () {
        final model = makeModel();
        final domain = model.toDomain();
        expect(domain.number, isNull);
        expect(domain.group, isNull);
        expect(domain.logoUrl, isNull);
        expect(domain.tvgId, isNull);
        expect(domain.tvgName, isNull);
        expect(domain.userAgent, isNull);
        expect(domain.catchupType, isNull);
        expect(domain.catchupSource, isNull);
      });

      test('preserves favorite false by default', () {
        final model = makeModel();
        expect(model.toDomain().isFavorite, false);
      });
    });

    // ── fromDomain ────────────────────────────────────

    group('fromDomain', () {
      test('maps all required fields from domain', () {
        final domain = makeDomain();
        final model = ChannelModel.fromDomain(domain);
        expect(model.id, 'ch1');
        expect(model.name, 'Test Channel');
        expect(model.streamUrl, 'http://example.com/stream');
      });

      test('maps all optional fields from domain', () {
        final domain = makeDomain(
          number: 10,
          group: 'Movies',
          logoUrl: 'http://m.png',
          tvgId: 'movie.1',
          tvgName: 'Movie Ch',
          isFavorite: true,
          userAgent: 'UA/3',
          hasCatchup: true,
          catchupDays: 14,
          catchupType: 'append',
          catchupSource: 'http://a/{utc}',
          sourceId: 'src3',
        );
        final model = ChannelModel.fromDomain(domain, sourceId: 'override-src');
        expect(model.number, 10);
        expect(model.group, 'Movies');
        expect(model.logoUrl, 'http://m.png');
        expect(model.tvgId, 'movie.1');
        expect(model.tvgName, 'Movie Ch');
        expect(model.isFavorite, true);
        expect(model.userAgent, 'UA/3');
        expect(model.hasCatchup, true);
        expect(model.catchupDays, 14);
        expect(model.catchupType, 'append');
        expect(model.catchupSource, 'http://a/{utc}');
        // sourceId param overrides domain
        expect(model.sourceId, 'override-src');
      });

      test('uses provided sourceId parameter', () {
        final domain = makeDomain(sourceId: 'x');
        final model = ChannelModel.fromDomain(domain, sourceId: 'y');
        expect(model.sourceId, 'y');
      });

      test('uses null sourceId when not provided', () {
        final domain = makeDomain();
        final model = ChannelModel.fromDomain(domain);
        expect(model.sourceId, isNull);
      });
    });

    // ── Round-trip ─────────────────────────────────────

    group('round-trip', () {
      test('model -> domain -> model preserves data', () {
        final original = makeModel(
          id: 'rt1',
          name: 'Round Trip',
          streamUrl: 'http://rt.com/s',
          number: 99,
          group: 'Test Group',
          logoUrl: 'http://logo.rt',
          tvgId: 'rt.id',
          tvgName: 'RT Name',
          isFavorite: true,
          userAgent: 'RT/1',
          sourceId: 'src-rt',
          hasCatchup: true,
          catchupDays: 5,
          catchupType: 'flussonic',
          catchupSource: 'http://c/{utc}',
        );
        final domain = original.toDomain();
        final restored = ChannelModel.fromDomain(domain, sourceId: 'src-rt');
        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.streamUrl, original.streamUrl);
        expect(restored.number, original.number);
        expect(restored.group, original.group);
        expect(restored.logoUrl, original.logoUrl);
        expect(restored.tvgId, original.tvgId);
        expect(restored.tvgName, original.tvgName);
        expect(restored.isFavorite, original.isFavorite);
        expect(restored.userAgent, original.userAgent);
        expect(restored.hasCatchup, original.hasCatchup);
        expect(restored.catchupDays, original.catchupDays);
        expect(restored.catchupType, original.catchupType);
        expect(restored.catchupSource, original.catchupSource);
      });

      test('domain -> model -> domain preserves data', () {
        final original = makeDomain(
          id: 'rt2',
          name: 'Round Trip 2',
          streamUrl: 'http://rt2.com/s',
          number: 7,
          group: 'G',
          isFavorite: false,
          hasCatchup: false,
        );
        final model = ChannelModel.fromDomain(original);
        final restored = model.toDomain();
        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.streamUrl, original.streamUrl);
        expect(restored.number, original.number);
        expect(restored.group, original.group);
        expect(restored.isFavorite, original.isFavorite);
        expect(restored.hasCatchup, original.hasCatchup);
      });

      test('round-trip preserves null optionals', () {
        final original = makeModel();
        final roundTripped = ChannelModel.fromDomain(original.toDomain());
        expect(roundTripped.number, isNull);
        expect(roundTripped.group, isNull);
        expect(roundTripped.logoUrl, isNull);
      });
    });
  });
}
