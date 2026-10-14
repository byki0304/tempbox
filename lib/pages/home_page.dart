import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../features/app_controller.dart';
import '../shared/format.dart';
import '../shared/widgets/common.dart';
import 'debug_tools.dart' if (dart.vm.product) 'debug_tools_stub.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.app});
  final AppController app;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final input = TextEditingController();
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    input.text = widget.app.draft;
    widget.app.tools.bindDrop((hover) {
      widget.app.dragging = hover;
      widget.app.notifyListeners();
    }, (files) => widget.app.addFiles(files));
    widget.app.tools.bindPaste((files) => widget.app.addFiles(files));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scroll());
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollSoon();
  }

  void _scroll() {
    if (!scroll.hasClients) return;
    scroll.jumpTo(scroll.position.maxScrollExtent);
  }

  void _scrollSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scroll());
  }

  @override
  void dispose() {
    widget.app.tools.unbindDrop();
    widget.app.tools.unbindPaste();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final frame = appFrameOf(context);
    final portrait = frame == AppFrame.portrait;
    final hint = app.profile?.isGuest == true ? app.l10n.tr('guestHint') : app.l10n.tr('accountHint');
    final hintText = Text(hint, textAlign: portrait ? TextAlign.start : TextAlign.center, softWrap: true);
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(portrait ? 12 : 10, frame == AppFrame.landscape ? 2 : 8, portrait ? 12 : 10, frame == AppFrame.landscape ? 6 : 12),
          child: Column(
            children: [
              LiveNote(message: app.live),
              if (app.offline) Text(app.l10n.tr('offline')),
              if (app.profile?.disabled == true) Text(app.l10n.tr('disabled')),
              if (portrait)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (app.items.isNotEmpty) ...[
                      Align(alignment: Alignment.centerLeft, child: SelectionActionButton(app: app)),
                      const SizedBox(height: 6),
                    ],
                    hintText,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (app.items.isNotEmpty) ...[
                      SelectionActionButton(app: app),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: hintText),
                  ],
                ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: TempColors.chatCanvas),
                  child: Column(
                    children: [
                      Expanded(child: _thread(app)),
                      if (app.files.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (var i = 0; i < app.files.length; i++)
                                InputChip(label: Text(app.files[i].name), onDeleted: () => app.removeFile(i)),
                            ],
                          ),
                        ),
                      _composer(app),
                    ],
                  ),
                ),
              ),
              debugBar(app),
            ],
          ),
        ),
        if (app.dragging)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xCCF6F1E8),
              child: Center(child: Text(app.l10n.tr('drop'), style: const TextStyle(fontSize: 22, color: TempColors.seal))),
            ),
          ),
      ],
    );
  }

  Widget _thread(AppController app) {
    final items = [...app.items]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (items.isEmpty && app.pending.isEmpty) {
      final frame = appFrameOf(context);
      final art = frame == AppFrame.landscape ? 72.0 : frame == AppFrame.portrait ? 120.0 : 180.0;
      return ListView(
        padding: EdgeInsets.all(frame == AppFrame.landscape ? 12 : 24),
        children: [
          BrandImage(path: '/brand/states/empty/empty.png', height: art),
          const SizedBox(height: 12),
          Text(app.l10n.tr('empty'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        ],
      );
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final children = <Widget>[];
    String? day;
    for (final item in items) {
      final key = seoulDayKey(item.createdAt);
      if (key != day) {
        day = key;
        children.add(_dayChip(chatDayLabel(item.createdAt, nowMs, locale: app.locale)));
      }
      children.add(ItemCard(app: app, item: item));
    }
    for (final card in app.pending) {
      children.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6, left: 46, right: 88),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: card.error == null ? TempColors.bubbleMine : TempColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(card.error ?? '${card.label} · ${app.l10n.tr('putting')}', style: const TextStyle(fontSize: 15)),
          ),
        ),
      );
    }
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      children: children,
    );
  }

  Widget _dayChip(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0x66323B45), borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _composer(AppController app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PopupMenuButton<String>(
              tooltip: app.l10n.tr('attach'),
              onSelected: (value) async {
                if (value == 'camera') {
                  await app.addFiles(const [], camera: true);
                } else {
                  await app.addFiles(await app.tools.pick());
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'file', child: Text(app.l10n.tr('chooseFile'))),
                PopupMenuItem(value: 'camera', child: Text(app.l10n.tr('camera'))),
              ],
              child: const SizedBox(width: 44, height: 44, child: Icon(Icons.attach_file, color: TempColors.chatMeta)),
            ),
            Expanded(
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                    app.send();
                    input.clear();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: input,
                  minLines: 1,
                  maxLines: appFrameOf(context) == AppFrame.landscape ? 3 : 6,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    errorText: app.fieldError,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  ),
                  onChanged: app.setDraft,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: app.offline ? TempColors.chatMeta : const Color(0xFF2AABEE),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: app.offline
                      ? null
                      : () {
                          app.send();
                          input.clear();
                        },
                  child: const SizedBox(width: 40, height: 40, child: Icon(Icons.send, color: Colors.white, size: 18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key, required this.app, this.inShell = false});
  final AppController app;
  final bool inShell;

  @override
  Widget build(BuildContext context) {
    final sections = [
      [app.l10n.tr('helpPut'), app.l10n.tr('helpPutBody')],
      [app.l10n.tr('helpOpen'), app.l10n.tr('helpOpenBody')],
      [app.l10n.tr('helpOnce'), app.l10n.tr('helpOnceBody')],
      [app.l10n.tr('helpHours'), app.l10n.tr('helpHoursBody')],
    ];
    final page = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(app.l10n.tr('help'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const BrandImage(path: '/brand/thumbnails/still/thumbnail.png', height: 180),
        for (final section in sections) ...[
          const SizedBox(height: 16),
          Text(section[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(section[1]),
        ],
        if (!inShell) ...[
          const SizedBox(height: 20),
          OutlinedButton(onPressed: () => app.go(Screen.welcome), child: Text(app.l10n.tr('cancel'))),
        ],
      ],
    );
    if (inShell) return page;
    return Scaffold(body: page);
  }
}
