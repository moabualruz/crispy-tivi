import '../../../iptv/domain/entities/channel.dart';
import '../../../iptv/domain/entities/epg_entry.dart';

/// A single upcoming programme entry shown in the home screen.
class UpcomingProgram {
  const UpcomingProgram({required this.channel, required this.entry});

  /// The favourite channel this programme airs on.
  final Channel channel;

  /// The upcoming EPG entry.
  final EpgEntry entry;
}
