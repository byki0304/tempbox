import 'dart:typed_data';

import '../../entities/models.dart';

abstract class WebTools {
  String? read(String key);
  void write(String key, String? value);
  bool get online;
  String currentPath();
  void setPath(String path);
  void listenPop(void Function(String path) onPop);
  Future<List<PickedFile>> pick({bool camera = false});
  void bindDrop(void Function(bool hovering) hover, void Function(List<PickedFile> files) onFiles);
  void unbindDrop();
  void bindPaste(void Function(List<PickedFile> files) onFiles);
  void unbindPaste();
  void saveFile(String filename, Uint8List bytes, String mime);
  Future<Uint8List?> webpThumb(Uint8List bytes);
}
