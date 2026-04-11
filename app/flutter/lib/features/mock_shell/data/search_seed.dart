import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';

const List<SearchResultGroup> searchGroups = <SearchResultGroup>[
  SearchResultGroup(
    title: 'Live TV',
    results: <ShelfItem>[
      ShelfItem(title: 'Arena Live', caption: 'Channel 118'),
      ShelfItem(title: 'Cinema Vault', caption: 'Channel 205'),
    ],
  ),
  SearchResultGroup(
    title: 'Movies',
    results: <ShelfItem>[
      ShelfItem(title: 'The Last Harbor', caption: 'Thriller'),
      ShelfItem(title: 'Atlas Run', caption: 'Action'),
    ],
  ),
  SearchResultGroup(
    title: 'Series',
    results: <ShelfItem>[
      ShelfItem(title: 'Shadow Signals', caption: 'Sci-fi drama'),
      ShelfItem(title: 'Northline', caption: 'New season'),
    ],
  ),
];
