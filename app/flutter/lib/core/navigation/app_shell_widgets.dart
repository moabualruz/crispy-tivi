import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profiles/data/profile_service.dart';
import '../../features/profiles/presentation/profile_constants.dart';
import '../theme/crispy_radius.dart';
import '../widgets/async_value_ui.dart';
import 'nav_destinations.dart';
import 'shell_providers.dart';
import 'side_nav.dart';

/// Small avatar button shown in the top-right corner of the compact
/// (mobile) layout. Tapping opens [ProfileSwitcherSheet].
class CompactProfileAvatar extends ConsumerWidget {
  /// Creates a compact profile avatar.
  const CompactProfileAvatar({required this.colorScheme, super.key});

  /// The current color scheme for icon tinting.
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileServiceProvider);

    return profileAsync.whenShrink(
      data: (state) {
        final profile = state.activeProfile;
        if (profile == null) return const SizedBox.shrink();
        final avatarIcon =
            kProfileAvatarIcons[profile.avatarIndex %
                kProfileAvatarIcons.length];
        final avatarColor =
            kProfileAvatarColors[profile.avatarIndex %
                kProfileAvatarColors.length];
        final hasMultipleProfiles = state.profiles.length > 1;

        return Tooltip(
          message: profile.name,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(CrispyRadius.xl),
              onTap:
                  hasMultipleProfiles
                      ? () => ProfileSwitcherSheet.show(context)
                      : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: profileAvatarGradient(avatarColor),
                  shape: BoxShape.circle,
                ),
                child: Icon(avatarIcon, size: 20, color: colorScheme.onPrimary),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Encapsulates rail hover/focus state so changes rebuild only
/// the rail — not the entire AppShell subtree.
class RailNavWidget extends ConsumerStatefulWidget {
  /// Creates a rail navigation widget.
  const RailNavWidget({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onExtendedChanged,
    super.key,
  });

  /// Currently selected navigation index.
  final int selectedIndex;

  /// Callback when a destination is selected.
  final ValueChanged<int> onDestinationSelected;

  /// Called when the rail's extended state changes (hover/focus).
  final ValueChanged<bool>? onExtendedChanged;

  @override
  ConsumerState<RailNavWidget> createState() => _RailNavWidgetState();
}

class _RailNavWidgetState extends ConsumerState<RailNavWidget> {
  final FocusScopeNode _railFocusScope = FocusScopeNode();
  bool _isHovering = false;
  bool _isFocused = false;
  bool get _isExtended => _isHovering || _isFocused;

  late final FocusEscalationNotifier _escalation;

  @override
  void initState() {
    super.initState();
    _escalation = ref.read(focusEscalationProvider.notifier);
    _railFocusScope.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _escalation.setRailNode(_railFocusScope);
    });
  }

  @override
  void dispose() {
    _railFocusScope.removeListener(_onFocusChange);
    _railFocusScope.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _railFocusScope.hasFocus;
    if (_isFocused != hasFocus) {
      setState(() => _isFocused = hasFocus);
      widget.onExtendedChanged?.call(_isExtended);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovering = true);
          widget.onExtendedChanged?.call(_isExtended);
        },
        onExit: (_) {
          setState(() => _isHovering = false);
          widget.onExtendedChanged?.call(_isExtended);
        },
        child: FocusScope(
          node: _railFocusScope,
          child: SideNav(
            extended: _isExtended,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            destinations: sideDestinations,
          ),
        ),
      ),
    );
  }
}
