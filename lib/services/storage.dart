abstract interface class Storage {
  Future<String?> read();

  Future<void> write(String contents);
}

class InMemoryStorage implements Storage {
  InMemoryStorage([this._contents]);

  String? _contents;

  @override
  Future<String?> read() async => _contents;

  @override
  Future<void> write(String contents) async {
    _contents = contents;
  }
}
