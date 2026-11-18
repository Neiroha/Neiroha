/// Cooperative cancellation shared by the queue, transports and consumers.
class TtsCancelToken {
  bool _cancelled = false;
  final Set<void Function()> _listeners = {};

  bool get isCancelled => _cancelled;

  void throwIfCancelled() {
    if (_cancelled) throw const TtsCancelledException();
  }

  /// Returns a remover. Registering after cancellation invokes immediately.
  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = List.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

class TtsCancelledException implements Exception {
  const TtsCancelledException();

  @override
  String toString() => 'Cancelled';
}
