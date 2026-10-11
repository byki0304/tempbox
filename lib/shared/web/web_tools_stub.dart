import 'dart:typed_data';

import '../../entities/models.dart';
import 'web_tools_api.dart';

class StubWebTools implements WebTools {
  final Map<String, String> _memory = {};
  String _path = '/';

  @override
  String? read(String key) => _memory[key];

  @override
  void write(String key, String? value) {
    if (value == null) {
      _memory.remove(key);
    } else {
      _memory[key] = value;
    }
  }

  @override
  bool get online => true;

  @override
  String currentPath() => _path;

  @override
  void setPath(String path) => _path = path;

  @override
  void listenPop(void Function(String path) onPop) {}

  @override
  Future<List<PickedFile>> pick({bool camera = false}) async => [];

  @override
  void bindDrop(void Function(bool hovering) hover, void Function(List<PickedFile> files) onFiles) {}

  @override
  void unbindDrop() {}

  @override
  void bindPaste(void Function(List<PickedFile> files) onFiles) {}

  @override
  void unbindPaste() {}

  @override
  void saveFile(String filename, Uint8List bytes, String mime) {}

  @override
  Future<Uint8List?> webpThumb(Uint8List bytes) async => null;
}

WebTools createWebTools() => StubWebTools();
