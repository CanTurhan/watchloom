import 'package:flutter_test/flutter_test.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/domain/library_access_policy.dart';
import 'package:watchloom/features/library/domain/repositories/library_repository.dart';
import 'package:watchloom/features/library/presentation/controllers/library_controller.dart';

LibraryEntry entry(int id) => LibraryEntry(
  showId: id,
  name: 'Show $id',
  summary: '',
  genres: const [],
  status: LibraryStatus.watchlist,
  addedAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Library implements LibraryRepository {
  final entries = <int, LibraryEntry>{};
  @override
  Future<List<LibraryEntry>> getEntries() async => entries.values.toList();
  @override
  Future<LibraryEntry?> getEntry(int showId) async => entries[showId];
  @override
  Future<void> saveEntry(LibraryEntry entry) async {
    entries[entry.showId] = entry;
  }

  @override
  Future<void> deleteEntry(int showId) async {
    entries.remove(showId);
  }
}

void main() {
  test('free saves five; the sixth is rejected and nothing is lost', () async {
    final repository = _Library();
    final library = LibraryController(repository);
    addTearDown(library.dispose);
    for (var id = 1; id <= 5; id++) {
      await library.saveEntry(entry(id));
    }
    expect(library.canAddShow, isFalse);
    await expectLater(
      library.saveEntry(entry(6)),
      throwsA(isA<LibraryLimitReached>()),
    );
    expect(library.entries.map((e) => e.showId), [1, 2, 3, 4, 5]);
    await library.toggleFavorite(1);
    await library.updatePersonalNote(showId: 1, note: 'Keep this');
    expect(library.findByShowId(1)?.isFavorite, isTrue);
    expect(library.findByShowId(1)?.personalNote, 'Keep this');
    await library.deleteEntry(2);
    await library.saveEntry(entry(6));
    expect(library.entries.length, 5);
    expect(library.findByShowId(6), isNotNull);
  });

  test('simultaneous additions cannot bypass the five-show quota', () async {
    final repository = _Library();
    final library = LibraryController(repository);
    addTearDown(library.dispose);
    for (var id = 1; id <= 4; id++) {
      await library.saveEntry(entry(id));
    }
    final outcomes = await Future.wait(
      List.generate(8, (i) async {
        try {
          await library.saveEntry(entry(i + 5));
          return true;
        } on LibraryLimitReached {
          return false;
        }
      }),
    );
    expect(outcomes.where((success) => success).length, 1);
    expect(repository.entries.length, 5);
    // A failed write does not poison the queue.
    await library.deleteEntry(1);
    await library.saveEntry(entry(20));
    expect(repository.entries.length, 5);
  });

  test(
    'Premium permits unlimited; downgrade preserves all saved shows',
    () async {
      var premium = true;
      final repository = _Library();
      final library = LibraryController(
        repository,
        accessPolicy: LibraryAccessPolicy(hasPremium: () => premium),
      );
      addTearDown(library.dispose);
      for (var id = 1; id <= 12; id++) {
        await library.saveEntry(entry(id));
      }
      expect(library.canAddShow, isTrue);
      premium = false;
      expect(library.entries.length, 12);
      expect(library.canAddShow, isFalse);
      await expectLater(
        library.saveEntry(entry(13)),
        throwsA(isA<LibraryLimitReached>()),
      );
      await library.saveEntry(
        entry(12).copyWith(status: LibraryStatus.watching),
      );
      expect(library.findByShowId(12)?.status, LibraryStatus.watching);
      expect(library.entries.length, 12);
      premium = true;
      await library.saveEntry(entry(13));
      expect(library.entries.length, 13);
    },
  );

  test('quota uses persisted records even before a UI load', () async {
    final repository = _Library();
    for (var id = 1; id <= 6; id++) {
      repository.entries[id] = entry(id);
    }
    final library = LibraryController(repository);
    addTearDown(library.dispose);
    await expectLater(
      library.saveEntry(entry(7)),
      throwsA(isA<LibraryLimitReached>()),
    );
    expect(repository.entries.length, 6);
  });
}
