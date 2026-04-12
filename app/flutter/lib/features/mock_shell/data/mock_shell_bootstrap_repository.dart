import 'package:crispy_tivi/features/mock_shell/data/mock_shell_content_repository.dart';
import 'package:crispy_tivi/features/mock_shell/data/mock_shell_contract_repository.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_content.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_contract.dart';

class MockShellBootstrap {
  const MockShellBootstrap({required this.contract, required this.content});

  final MockShellContractSupport contract;
  final MockShellContentSnapshot content;
}

class MockShellBootstrapRepository {
  const MockShellBootstrapRepository({
    this.contractRepository = const MockShellContractRepository(),
    this.contentRepository = const MockShellContentRepository(),
  });

  final MockShellContractRepository contractRepository;
  final MockShellContentRepository contentRepository;

  Future<MockShellBootstrap> load() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      contractRepository.load(),
      contentRepository.load(),
    ]);
    return MockShellBootstrap(
      contract: loaded[0] as MockShellContractSupport,
      content: loaded[1] as MockShellContentSnapshot,
    );
  }
}
