import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_contract.dart';
import 'package:flutter/services.dart';

class MockShellContractRepository {
  const MockShellContractRepository();

  static const String assetPath = 'assets/contracts/mock_shell_contract.json';

  Future<MockShellContractSupport> load() async {
    final String source = await rootBundle.loadString(assetPath);
    final MockShellContract contract = MockShellContract.fromJsonString(source);
    return MockShellContractSupport.fromContract(contract);
  }
}
