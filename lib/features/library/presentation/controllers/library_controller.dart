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

  Future<void> deleteEntry(int showId) async {
    await _repository.deleteEntry(showId);
    await load();
  }
}
