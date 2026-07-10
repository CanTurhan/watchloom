import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:watchloom/features/library/domain/entities/library_entry.dart';
import 'package:watchloom/features/library/domain/repositories/library_repository.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(this._repository);

  final LibraryRepository _repository;

  List<LibraryEntry> _entries = const [];
  bool _isLoading = false;
  Object? _error;

  UnmodifiableListView<LibraryEntry> get entries {
    return UnmodifiableListView(_entries);
  }

  List<LibraryEntry> get favoriteEntries {
    return _entries.where((entry) => entry.isFavorite).toList(growable: false);
  }

  bool get isLoading => _isLoading;
  Object? get error => _error;

  LibraryEntry? findByShowId(int showId) {
    for (final entry in _entries) {
      if (entry.showId == showId) {
        return entry;
      }
    }

    return null;
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _repository.getEntries();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveEntry(LibraryEntry entry) async {
    await _repository.saveEntry(entry);
    await load();
  }

  Future<void> toggleFavorite(int showId) async {
    final entry = findByShowId(showId);

    if (entry == null) {
      return;
    }

    await saveEntry(
      entry.copyWith(isFavorite: !entry.isFavorite, updatedAt: DateTime.now()),
    );
  }

  Future<void> updatePersonalNote({
    required int showId,
    required String note,
  }) async {
    final entry = findByShowId(showId);

    if (entry == null) {
      return;
    }

    await saveEntry(
      entry.copyWith(personalNote: note.trim(), updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteEntry(int showId) async {
    await _repository.deleteEntry(showId);
    await load();
  }
}
