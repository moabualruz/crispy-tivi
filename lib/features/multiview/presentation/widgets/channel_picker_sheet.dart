import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';

/// Bottom sheet for picking a channel to add to a
/// multi-view slot.
class ChannelPickerSheet extends ConsumerStatefulWidget {
  const ChannelPickerSheet({super.key, required this.onSelect});

  /// Called when the user taps a channel row.
  final ValueChanged<Channel> onSelect;

  @override
  ConsumerState<ChannelPickerSheet> createState() => _ChannelPickerSheetState();
}

class _ChannelPickerSheetState extends ConsumerState<ChannelPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allChannels = ref.watch(channelListProvider).channels;
    final displayed =
        _query.isEmpty
            ? allChannels
            : allChannels
                .where((c) => c.name.toLowerCase().contains(_query))
                .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(CrispySpacing.md),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search channels...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (q) => setState(() => _query = q.toLowerCase()),
                autofocus: true,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: displayed.length,
                itemBuilder: (context, index) {
                  final channel = displayed[index];
                  return ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child:
                          channel.logoUrl != null
                              ? Image.network(
                                channel.logoUrl!,
                                errorBuilder: (_, _, _) => const Icon(Icons.tv),
                              )
                              : const Icon(Icons.tv),
                    ),
                    title: Text(channel.name),
                    onTap: () => widget.onSelect(channel),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
