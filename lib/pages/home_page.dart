import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../features/app_controller.dart';
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
    _scroll();
  }

  void _scroll() {
    if (!scroll.hasClients) return;
    scroll.jumpTo(scroll.position.maxScrollExtent);
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
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              LiveNote(message: app.live),
              if (app.offline) Text(app.l10n.tr('offline')),
              if (app.profile?.disabled == true) Text(app.l10n.tr('disabled')),
              if (app.profile?.isGuest == true && app.pairingCode != null)
                Text('${app.l10n.tr('guestHint')}\n${app.pairingCode}', textAlign: TextAlign.center)
              else if (app.profile?.isGuest != true)
                Text(app.l10n.tr('accountHint'), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Expanded(
                child: app.items.isEmpty && app.pending.isEmpty
                    ? ListView(
                        children: [
                          const BrandImage(path: '/brand/states/empty/empty.png', height: 180),
                          const SizedBox(height: 12),
                          Text(app.l10n.tr('empty'), textAlign: TextAlign.center),
                        ],
                      )
                    : ListView(
                        controller: scroll,
                        children: [
                          for (final item in app.items) ItemCard(app: app, item: item),
                          for (final card in app.pending)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: card.error == null ? TempColors.surface : TempColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: card.error == null ? TempColors.seal : TempColors.danger),
                                ),
                                child: Text(card.error ?? '${card.label} · ${app.l10n.tr('putting')}', style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                        ],
                      ),
              ),
              if (app.files.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < app.files.length; i++)
                      InputChip(label: Text(app.files[i].name), onDeleted: () => app.removeFile(i)),
                  ],
                ),
              Row(
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
                    child: const SizedBox(width: 48, height: 48, child: Icon(Icons.attach_file)),
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
                        maxLines: 6,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(errorText: app.fieldError),
                        onChanged: app.setDraft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: app.offline ? null : () {
                      app.send();
                      input.clear();
                    },
                    child: Text(app.l10n.tr('send')),
                  ),
                ],
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
