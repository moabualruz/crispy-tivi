import 'package:crispy_tivi/features/shell/data/shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:flutter/services.dart';

class AssetShellContractRepository extends ShellContractRepository {
  const AssetShellContractRepository();

  static const String assetPath = 'assets/contracts/asset_shell_contract.json';

  @override
  Future<ShellContractSupport> load() async {
    final String source = await rootBundle.loadString(assetPath);
    final ShellContract contract = ShellContract.fromJsonString(source);
    return ShellContractSupport.fromContract(contract);
  }
}
