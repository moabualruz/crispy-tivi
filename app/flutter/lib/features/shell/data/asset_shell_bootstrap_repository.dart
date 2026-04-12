import 'package:crispy_tivi/features/shell/data/asset_shell_content_repository.dart';
import 'package:crispy_tivi/features/shell/data/asset_shell_contract_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';

class ShellBootstrap {
  const ShellBootstrap({required this.contract, required this.content});

  final ShellContractSupport contract;
  final ShellContentSnapshot content;
}

class AssetShellBootstrapRepository {
  const AssetShellBootstrapRepository({
    this.contractRepository = const AssetShellContractRepository(),
    this.contentRepository = const AssetShellContentRepository(),
  });

  final AssetShellContractRepository contractRepository;
  final AssetShellContentRepository contentRepository;

  Future<ShellBootstrap> load() async {
    final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
      contractRepository.load(),
      contentRepository.load(),
    ]);
    return ShellBootstrap(
      contract: loaded[0] as ShellContractSupport,
      content: loaded[1] as ShellContentSnapshot,
    );
  }
}
