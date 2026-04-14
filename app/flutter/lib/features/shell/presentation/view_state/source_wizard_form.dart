enum SourceWizardFieldKind { text, url, password, choice, multiline, readonly }

final class SourceWizardFieldOption {
  const SourceWizardFieldOption({required this.value, required this.label});

  final String value;
  final String label;
}

final class SourceWizardFieldSpec {
  const SourceWizardFieldSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.placeholder,
    this.options = const <SourceWizardFieldOption>[],
    this.readOnlyValue,
    this.required = true,
  });

  final String key;
  final String label;
  final SourceWizardFieldKind kind;
  final String? placeholder;
  final List<SourceWizardFieldOption> options;
  final String? readOnlyValue;
  final bool required;
}
