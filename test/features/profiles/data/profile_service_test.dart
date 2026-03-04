import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/profiles/data/profile_service.dart';

void main() {
  late ProviderContainer container;
  late CrispyBackend backend;

  setUp(() {
    backend = MemoryBackend();

    container = ProviderContainer(
      overrides: [
        crispyBackendProvider.overrideWithValue(backend),
        cacheServiceProvider.overrideWithValue(CacheService(backend)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  /// Read ProfileState, handling async build.
  Future<ProfileState> readState() async {
    final notifier = container.read(profileServiceProvider.notifier);
    await notifier.future;
    final asyncVal = container.read(profileServiceProvider);
    return asyncVal.asData?.value ?? const ProfileState();
  }

  group('ProfileService', () {
    test('starts with a default profile', () async {
      final state = await readState();
      expect(state.profiles.length, 1);
      expect(state.profiles.first.name, 'Default');
      expect(state.activeProfileId, 'default');
    });

    test('addProfile creates a new profile', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Kid');
      final state = await readState();
      expect(state.profiles.length, 2);
      expect(state.profiles.last.name, 'Kid');
    });

    test('addProfile with PIN sets hasPIN', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Locked', pin: '1234');
      final state = await readState();
      final profile = state.profiles.firstWhere((p) => p.name == 'Locked');
      expect(profile.hasPIN, isTrue);
      // PIN is hashed (SHA-256), verify version.
      expect(profile.pinVersion, 1);
      // Verify PIN works via switchProfile.
      final valid = await notifier.switchProfile(profile.id, pin: '1234');
      expect(valid, isTrue);
    });

    test('addProfile with isChild creates child profile', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Junior', isChild: true);
      final state = await readState();
      final profile = state.profiles.firstWhere((p) => p.name == 'Junior');
      expect(profile.isChild, isTrue);
    });

    test('removeProfile removes a profile', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Alice');
      var state = await readState();
      final alice = state.profiles.firstWhere((p) => p.name == 'Alice');
      await notifier.removeProfile(alice.id);
      state = await readState();
      expect(state.profiles.length, 1);
      expect(state.profiles.first.name, 'Default');
    });

    test('removeProfile does not remove the last profile', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.removeProfile('default');
      final state = await readState();
      expect(state.profiles.length, 1);
    });

    test('removeProfile switches active if removing '
        'active', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Bob');
      var state = await readState();
      final bob = state.profiles.firstWhere((p) => p.name == 'Bob');
      await notifier.switchProfile(bob.id);
      await notifier.removeProfile(bob.id);
      state = await readState();
      expect(state.activeProfileId, 'default');
    });

    test('switchProfile changes active profile', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Charlie');
      var state = await readState();
      final charlie = state.profiles.firstWhere((p) => p.name == 'Charlie');
      final result = await notifier.switchProfile(charlie.id);
      expect(result, isTrue);
      state = await readState();
      expect(state.activeProfileId, charlie.id);
    });

    test('switchProfile validates PIN', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Secure', pin: '9999');
      final state = await readState();
      final secure = state.profiles.firstWhere((p) => p.name == 'Secure');
      // Wrong PIN
      expect(await notifier.switchProfile(secure.id, pin: '0000'), isFalse);
      // Correct PIN
      expect(await notifier.switchProfile(secure.id, pin: '9999'), isTrue);
    });

    test('switchProfile returns false for unknown profile', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      expect(await notifier.switchProfile('nonexistent'), isFalse);
    });

    test('updateProfile changes name', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.updateProfile('default', name: 'Admin');
      final state = await readState();
      expect(state.profiles.first.name, 'Admin');
    });

    test('updateProfile can set and clear PIN', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.updateProfile('default', pin: '5678');
      var state = await readState();
      expect(state.profiles.first.hasPIN, isTrue);
      await notifier.updateProfile('default', clearPin: true);
      state = await readState();
      expect(state.profiles.first.hasPIN, isFalse);
    });

    test('activeProfile returns the active one', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Eve');
      var state = await readState();
      final eve = state.profiles.firstWhere((p) => p.name == 'Eve');
      await notifier.switchProfile(eve.id);
      state = await readState();
      expect(state.activeProfile?.name, 'Eve');
    });

    test('profiles persist across container rebuilds', () async {
      final notifier = container.read(profileServiceProvider.notifier);
      await notifier.future;
      await notifier.addProfile(name: 'Persistent');

      // Create a new container with same backend.
      final container2 = ProviderContainer(
        overrides: [
          crispyBackendProvider.overrideWithValue(backend),
          cacheServiceProvider.overrideWithValue(CacheService(backend)),
        ],
      );

      final notifier2 = container2.read(profileServiceProvider.notifier);
      await notifier2.future;
      final state2 = container2.read(profileServiceProvider).asData!.value;

      expect(state2.profiles.length, 2);
      expect(state2.profiles.any((p) => p.name == 'Persistent'), isTrue);

      container2.dispose();
    });
  });
}
