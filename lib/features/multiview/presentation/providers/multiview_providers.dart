import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/layout_repository_impl.dart';

export '../../data/layout_repository_impl.dart' show layoutRepositoryProvider;
import '../../domain/entities/active_stream.dart';
import '../../domain/entities/multiview_session.dart';
import '../../domain/entities/saved_layout.dart';
import '../../domain/repositories/layout_repository.dart';

/// List of saved layouts (async).
final savedLayoutsProvider = FutureProvider.autoDispose<List<SavedLayout>>((
  ref,
) {
  final repo = ref.watch(layoutRepositoryProvider);
  return repo.getAll();
});

final multiViewProvider =
    NotifierProvider.autoDispose<MultiViewNotifier, MultiViewSession>(
      MultiViewNotifier.new,
    );

class MultiViewNotifier extends Notifier<MultiViewSession> {
  @override
  MultiViewSession build() {
    return const MultiViewSession(
      layout: MultiViewLayout.twoByTwo,
      preset: MultiViewPreset.quad,
      slots: [null, null, null, null], // Default 2x2
      audioFocusIndex: 0,
    );
  }

  /// Select a named [preset] and apply its underlying layout.
  void setPreset(MultiViewPreset preset) {
    _applyLayout(preset.layout, preset: preset);
  }

  void setLayout(MultiViewLayout layout) {
    _applyLayout(layout);
  }

  void _applyLayout(MultiViewLayout layout, {MultiViewPreset? preset}) {
    // Resize slots list to match new layout count
    final currentSlots = state.slots;
    final newCount = layout.cellCount;
    final newSlots = <ActiveStream?>[];

    for (var i = 0; i < newCount; i++) {
      if (i < currentSlots.length) {
        newSlots.add(currentSlots[i]);
      } else {
        newSlots.add(null);
      }
    }

    state = state.copyWith(
      layout: layout,
      preset: preset,
      slots: newSlots,
      audioFocusIndex:
          state.audioFocusIndex >= newCount ? 0 : state.audioFocusIndex,
    );
  }

  void setAudioFocus(int index) {
    if (index >= 0 && index < state.slots.length) {
      state = state.copyWith(audioFocusIndex: index);
    }
  }

  void addSlot(int index, ActiveStream stream) {
    if (index >= 0 && index < state.slots.length) {
      final newSlots = List<ActiveStream?>.from(state.slots);
      newSlots[index] = stream;
      state = state.copyWith(slots: newSlots);
    }
  }

  void removeSlot(int index) {
    if (index >= 0 && index < state.slots.length) {
      final newSlots = List<ActiveStream?>.from(state.slots);
      newSlots[index] = null;
      state = state.copyWith(slots: newSlots);
    }
  }

  void swapSlots(int index1, int index2) {
    if (index1 >= 0 &&
        index1 < state.slots.length &&
        index2 >= 0 &&
        index2 < state.slots.length) {
      final newSlots = List<ActiveStream?>.from(state.slots);
      final temp = newSlots[index1];
      newSlots[index1] = newSlots[index2];
      newSlots[index2] = temp;

      // Keep focus on the slot index (spatial focus), not the content.
      state = state.copyWith(slots: newSlots);
    }
  }

  /// Save current layout configuration with the given name.
  Future<void> saveCurrentLayout(String name) async {
    final repo = ref.read(layoutRepositoryProvider);

    final streams =
        state.slots.map((slot) {
          if (slot == null) return null;
          return SavedStream(
            channelId: slot.url, // Use URL as ID for now
            channelName: slot.channelName,
            logoUrl: slot.logoUrl,
          );
        }).toList();

    final now = DateTime.now();
    final layout = SavedLayout(
      id: repo.generateId(),
      name: name,
      layout: state.layout,
      streams: streams,
      createdAt: now,
    );

    await repo.save(layout);
    ref.invalidate(savedLayoutsProvider);
  }

  /// Load a saved layout, restoring channels to slots.
  void loadLayout(SavedLayout layout) {
    // Convert saved streams back to active streams.
    final slots =
        layout.streams.map((saved) {
          if (saved == null) return null;
          return ActiveStream(
            url: saved.channelId, // URL was stored as channelId
            channelName: saved.channelName,
            logoUrl: saved.logoUrl,
          );
        }).toList();

    // Infer the best-matching preset for the loaded layout.
    final inferredPreset = _presetForLayout(layout.layout);

    state = MultiViewSession(
      layout: layout.layout,
      preset: inferredPreset,
      slots: slots,
      audioFocusIndex: 0,
    );
  }

  /// Returns the first [MultiViewPreset] whose layout matches [layout],
  /// falling back to [MultiViewPreset.quad].
  static MultiViewPreset _presetForLayout(MultiViewLayout layout) {
    return MultiViewPreset.values.firstWhere(
      (p) => p.layout == layout,
      orElse: () => MultiViewPreset.quad,
    );
  }

  /// Delete a saved layout.
  Future<void> deleteLayout(String id) async {
    final repo = ref.read(layoutRepositoryProvider);
    await repo.delete(id);
    ref.invalidate(savedLayoutsProvider);
  }

  /// Clear all slots.
  void clearAll() {
    final emptySlots = List<ActiveStream?>.filled(state.layout.cellCount, null);
    state = state.copyWith(slots: emptySlots, audioFocusIndex: 0);
  }
}
