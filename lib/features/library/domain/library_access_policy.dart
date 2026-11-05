/// Restricts new records only. Existing collections and their history are kept
/// after an upgrade, cancellation or refund, including collections above five.
class LibraryAccessPolicy {
  const LibraryAccessPolicy.free() : hasPremium = null;
  // Keep the callback live so a renewal, expiry or refund applies immediately.
  const LibraryAccessPolicy({required this.hasPremium});

  static const freeShowLimit = 5;
  final bool Function()? hasPremium;
  int? get maximumEntries =>
      (hasPremium?.call() ?? false) ? null : freeShowLimit;

  void checkSave({required bool alreadySaved, required int entryCount}) {
    final limit = maximumEntries;
    if (!alreadySaved && limit != null && entryCount >= limit) {
      throw LibraryLimitReached(limit);
    }
  }
}

class LibraryLimitReached implements Exception {
  const LibraryLimitReached(this.limit);
  final int limit;
}
