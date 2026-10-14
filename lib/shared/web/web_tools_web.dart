import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../entities/models.dart';
import 'web_tools_api.dart';

class BrowserWebTools implements WebTools {
  web.EventListener? _over;
  web.EventListener? _leave;
  web.EventListener? _drop;
  web.EventListener? _paste;
  web.EventListener? _pop;

  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String? value) {
    if (value == null) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, value);
    }
  }

  @override
  bool get online => web.window.navigator.onLine;

  @override
  String currentPath() {
    final path = web.window.location.pathname;
    return path.isEmpty ? '/' : path;
  }

  @override
  void setPath(String path) {
    if (currentPath() == path) return;
    web.window.history.pushState(null, '', path);
  }

  @override
  void listenPop(void Function(String path) onPop) {
    _pop = ((web.Event _) {
      onPop(currentPath());
    }).toJS;
    web.window.addEventListener('popstate', _pop);
  }

  Future<PickedFile?> _read(web.File file) async {
    final reader = web.FileReader();
    final done = Completer<void>();
    reader.onloadend = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    reader.readAsArrayBuffer(file);
    await done.future;
    final result = reader.result;
    if (result == null) return null;
    final bytes = (result as JSArrayBuffer).toDart.asUint8List();
    return PickedFile(name: file.name, mime: file.type, bytes: bytes);
  }

  Future<List<PickedFile>> _fromList(web.FileList? list) async {
    if (list == null) return [];
    final out = <PickedFile>[];
    for (var i = 0; i < list.length && out.length < 10; i++) {
      final file = list.item(i);
      if (file == null) continue;
      final picked = await _read(file);
      if (picked != null) out.add(picked);
    }
    return out;
  }

  @override
  Future<List<PickedFile>> pick({bool camera = false}) async {
    final input = web.HTMLInputElement()..type = 'file';
    if (camera) {
      input.accept = 'image/*';
      input.setAttribute('capture', 'environment');
    } else {
      input.multiple = true;
    }
    // Keep the input in the document. A detached input's dialog is cancelled
    // on the next DOM change, which is what closes the desktop file window
    // as soon as the attach menu finishes closing.
    input.style.position = 'fixed';
    input.style.left = '0';
    input.style.top = '0';
    input.style.width = '1px';
    input.style.height = '1px';
    input.style.opacity = '0';
    final body = web.document.body;
    if (body == null) return [];
    body.appendChild(input);
    final done = Completer<void>();
    void finish(web.Event _) {
      if (!done.isCompleted) done.complete();
    }
    input.onchange = finish.toJS;
    input.addEventListener('cancel', finish.toJS);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      input.click();
      await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
      return await _fromList(input.files);
    } finally {
      input.remove();
    }
  }

  @override
  void bindDrop(void Function(bool hovering) hover, void Function(List<PickedFile> files) onFiles) {
    _over = ((web.Event event) {
      event.preventDefault();
      hover(true);
    }).toJS;
    _leave = ((web.Event event) {
      event.preventDefault();
      hover(false);
    }).toJS;
    _drop = ((web.Event event) {
      event.preventDefault();
      hover(false);
      final drag = event as web.DragEvent;
      _fromList(drag.dataTransfer?.files).then(onFiles);
    }).toJS;
    web.window.addEventListener('dragover', _over);
    web.window.addEventListener('dragleave', _leave);
    web.window.addEventListener('drop', _drop);
  }

  @override
  void unbindDrop() {
    if (_over != null) web.window.removeEventListener('dragover', _over);
    if (_leave != null) web.window.removeEventListener('dragleave', _leave);
    if (_drop != null) web.window.removeEventListener('drop', _drop);
  }

  @override
  void bindPaste(void Function(List<PickedFile> files) onFiles) {
    _paste = ((web.Event event) {
      final clip = event as web.ClipboardEvent;
      final files = clip.clipboardData?.files;
      if (files != null && files.length > 0) {
        event.preventDefault();
        _fromList(files).then(onFiles);
      }
    }).toJS;
    web.window.addEventListener('paste', _paste);
  }

  @override
  void unbindPaste() {
    if (_paste != null) web.window.removeEventListener('paste', _paste);
  }

  @override
  void saveFile(String filename, Uint8List bytes, String mime) {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.window.setTimeout(
      (() {
        web.URL.revokeObjectURL(url);
      }).toJS,
      4000.toJS,
    );
  }

  @override
  Future<Uint8List?> webpThumb(Uint8List bytes) async {
    try {
      final blob = web.Blob([bytes.toJS].toJS);
      final bitmap = await web.window.createImageBitmap(blob).toDart;
      final longest = bitmap.width > bitmap.height ? bitmap.width : bitmap.height;
      final scale = longest > 256 ? 256 / longest : 1.0;
      final width = (bitmap.width * scale).round().clamp(1, 256);
      final height = (bitmap.height * scale).round().clamp(1, 256);
      final canvas = web.HTMLCanvasElement()
        ..width = width
        ..height = height;
      final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      context.drawImage(bitmap, 0, 0, width.toDouble(), height.toDouble());
      final dataUrl = canvas.toDataURL('image/webp', 0.8.toJS);
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return null;
      return Uint8List.fromList(base64Decode(dataUrl.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
}

WebTools createWebTools() => BrowserWebTools();
