import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';

abstract class ShellContractRepository {
  const ShellContractRepository();

  Future<ShellContractSupport> load();
}
