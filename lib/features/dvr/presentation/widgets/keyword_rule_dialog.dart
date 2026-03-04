import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../data/keyword_rule_provider.dart';

// ─────────────────────────────────────────────────────────
//  Public entry points
// ─────────────────────────────────────────────────────────

/// Shows the keyword rule builder dialog to create a new rule.
void showAddKeywordRuleDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (_) => _KeywordRuleDialog(ref: ref, existingRule: null),
  );
}

/// Shows the keyword rule builder dialog to edit an existing rule.
void showEditKeywordRuleDialog(
  BuildContext context,
  WidgetRef ref,
  KeywordRule rule,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _KeywordRuleDialog(ref: ref, existingRule: rule),
  );
}

// ─────────────────────────────────────────────────────────
//  Keyword Rules List Sheet
// ─────────────────────────────────────────────────────────

/// Bottom sheet listing active keyword auto-record rules with
/// add / edit / delete controls.
class KeywordRulesSheet extends ConsumerWidget {
  const KeywordRulesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(keywordRuleProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder:
          (context, scrollController) => Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.sm),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(CrispyRadius.full),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.manage_search, size: 20, color: cs.primary),
                    const SizedBox(width: CrispySpacing.sm),
                    Expanded(
                      child: Text(
                        'Keyword Auto-Record Rules',
                        style: tt.titleMedium,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => showAddKeywordRuleDialog(context, ref),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Rule'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: rulesAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                  data:
                      (rules) =>
                          rules.isEmpty
                              ? _EmptyRulesPlaceholder(
                                onAdd:
                                    () =>
                                        showAddKeywordRuleDialog(context, ref),
                              )
                              : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                  vertical: CrispySpacing.sm,
                                ),
                                itemCount: rules.length,
                                separatorBuilder:
                                    (context, _) => const Divider(
                                      height: 1,
                                      indent: CrispySpacing.md,
                                      endIndent: CrispySpacing.md,
                                    ),
                                itemBuilder:
                                    (context, i) =>
                                        _RuleTile(rule: rules[i], ref: ref),
                              ),
                ),
              ),
            ],
          ),
    );
  }
}

/// Shows the [KeywordRulesSheet] as a modal bottom sheet.
void showKeywordRulesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: CrispyRadius.top(CrispyRadius.md),
    ),
    builder: (_) => const KeywordRulesSheet(),
  );
}

// ─────────────────────────────────────────────────────────
//  Empty placeholder
// ─────────────────────────────────────────────────────────

class _EmptyRulesPlaceholder extends StatelessWidget {
  const _EmptyRulesPlaceholder({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'No keyword rules yet',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: CrispySpacing.xs),
            Text(
              'Add a rule to auto-record programs matching a keyword.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CrispySpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add First Rule'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Rule list tile
// ─────────────────────────────────────────────────────────

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.ref});

  final KeywordRule rule;
  final WidgetRef ref;

  String get _subtitle {
    final parts = <String>[rule.matchField.label];
    if (rule.channelFilter != null && rule.channelFilter!.isNotEmpty) {
      parts.add('Channel: ${rule.channelFilter}');
    }
    if (rule.hasTimeWindow) {
      parts.add('${rule.startHour!}:00 – ${rule.endHour!}:00');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: cs.primaryContainer,
        child: Icon(
          Icons.manage_search,
          size: 18,
          color: cs.onPrimaryContainer,
        ),
      ),
      title: Text(
        '"${rule.keyword}"',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit rule',
            onPressed: () => showEditKeywordRuleDialog(context, ref, rule),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
            tooltip: 'Delete rule',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Rule'),
            content: Text('Remove the rule for "${rule.keyword}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(keywordRuleProvider.notifier).removeRule(rule.id);
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Builder dialog
// ─────────────────────────────────────────────────────────

class _KeywordRuleDialog extends ConsumerStatefulWidget {
  const _KeywordRuleDialog({required this.ref, required this.existingRule});

  final WidgetRef ref;
  final KeywordRule? existingRule;

  @override
  ConsumerState<_KeywordRuleDialog> createState() => _KeywordRuleDialogState();
}

class _KeywordRuleDialogState extends ConsumerState<_KeywordRuleDialog> {
  late final TextEditingController _keywordCtrl;
  late final TextEditingController _channelCtrl;

  late KeywordMatchField _matchField;
  bool _enableTimeWindow = false;
  int _startHour = 6;
  int _endHour = 23;

  bool get _isEditing => widget.existingRule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    _keywordCtrl = TextEditingController(text: rule?.keyword ?? '');
    _channelCtrl = TextEditingController(text: rule?.channelFilter ?? '');
    _matchField = rule?.matchField ?? KeywordMatchField.any;
    _enableTimeWindow = rule?.hasTimeWindow ?? false;
    _startHour = rule?.startHour ?? 6;
    _endHour = rule?.endHour ?? 23;
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final keyword = _keywordCtrl.text.trim();
    if (keyword.isEmpty) return;

    final channel = _channelCtrl.text.trim();
    final rule = KeywordRule(
      id:
          widget.existingRule?.id ??
          'kw_${DateTime.now().millisecondsSinceEpoch}',
      keyword: keyword,
      matchField: _matchField,
      channelFilter: channel.isEmpty ? null : channel,
      startHour: _enableTimeWindow ? _startHour : null,
      endHour: _enableTimeWindow ? _endHour : null,
    );

    final notifier = widget.ref.read(keywordRuleProvider.notifier);
    if (_isEditing) {
      await notifier.updateRule(rule);
    } else {
      await notifier.addRule(rule);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Keyword Rule' : 'New Keyword Rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keyword input
            TextField(
              controller: _keywordCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Keyword',
                hintText: 'e.g. Formula 1',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: CrispySpacing.md),

            // Match field
            Text(
              'MATCH IN',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: CrispySpacing.xs),
            SegmentedButton<KeywordMatchField>(
              segments:
                  KeywordMatchField.values
                      .map(
                        (f) => ButtonSegment<KeywordMatchField>(
                          value: f,
                          label: Text(f.label),
                        ),
                      )
                      .toList(),
              selected: {_matchField},
              onSelectionChanged:
                  (sel) => setState(() => _matchField = sel.first),
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(tt.labelSmall),
              ),
            ),
            const SizedBox(height: CrispySpacing.md),

            // Channel filter
            TextField(
              controller: _channelCtrl,
              decoration: const InputDecoration(
                labelText: 'Channel Filter (optional)',
                hintText: 'Leave blank to match all channels',
                prefixIcon: Icon(Icons.tv),
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),

            // Time window toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time Window'),
              subtitle: const Text('Only record within a time range'),
              value: _enableTimeWindow,
              onChanged: (v) => setState(() => _enableTimeWindow = v),
            ),

            // Time pickers (visible when time window enabled)
            if (_enableTimeWindow) ...[
              const SizedBox(height: CrispySpacing.xs),
              _HourRangePicker(
                startHour: _startHour,
                endHour: _endHour,
                onChanged:
                    (start, end) => setState(() {
                      _startHour = start;
                      _endHour = end;
                    }),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _keywordCtrl.text.trim().isEmpty ? null : _submit,
          child: Text(_isEditing ? 'Save' : 'Add Rule'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Hour range picker
// ─────────────────────────────────────────────────────────

/// Compact inline picker for start/end hours (0–23).
class _HourRangePicker extends StatelessWidget {
  const _HourRangePicker({
    required this.startHour,
    required this.endHour,
    required this.onChanged,
  });

  final int startHour;
  final int endHour;
  final void Function(int start, int end) onChanged;

  String _fmt(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(CrispySpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(CrispyRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: CrispySpacing.sm),
          Text('From', style: tt.bodySmall),
          const SizedBox(width: CrispySpacing.sm),
          _HourDropdown(
            value: startHour,
            onChanged: (h) => onChanged(h, endHour > h ? endHour : h + 1),
          ),
          const SizedBox(width: CrispySpacing.sm),
          Text('to', style: tt.bodySmall),
          const SizedBox(width: CrispySpacing.sm),
          _HourDropdown(
            value: endHour,
            minValue: startHour + 1,
            onChanged: (h) => onChanged(startHour, h),
          ),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            '(${_fmt(startHour)} – ${_fmt(endHour)})',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _HourDropdown extends StatelessWidget {
  const _HourDropdown({
    required this.value,
    required this.onChanged,
    this.minValue = 0,
  });

  final int value;
  final int minValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: List.generate(24 - minValue, (i) {
        final h = i + minValue;
        return DropdownMenuItem(value: h, child: Text('$h'));
      }),
      onChanged: (h) {
        if (h != null) onChanged(h);
      },
    );
  }
}
