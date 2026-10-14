import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../entities/models.dart';
import '../../features/app_controller.dart';
import '../../shared/format.dart';

class TempBoxMark extends StatelessWidget {
  const TempBoxMark({super.key, this.fontSize = 46, this.bar = true});
  final double fontSize;
  final bool bar;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      height: 1,
      fontWeight: FontWeight.w800,
      letterSpacing: fontSize > 32 ? -1.2 : -0.6,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: bar ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Temp', style: style.copyWith(color: TempColors.seal)),
              TextSpan(text: 'Box', style: style.copyWith(color: TempColors.accent)),
            ],
          ),
          textAlign: bar ? TextAlign.center : TextAlign.start,
        ),
        if (bar) ...[
          const SizedBox(height: 10),
          Container(
            width: fontSize * 1.9,
            height: 5,
            decoration: BoxDecoration(
              color: TempColors.seal,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

class LanguageChoices extends StatelessWidget {
  const LanguageChoices({super.key, required this.app, this.alignment = WrapAlignment.start});
  final AppController app;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 8,
      children: [
        TextButton(onPressed: () => app.setLocale('ko'), child: Text(app.l10n.tr('korean'))),
        TextButton(onPressed: () => app.setLocale('en'), child: Text(app.l10n.tr('english'))),
        TextButton(onPressed: () => app.setLocale('ja'), child: Text(app.l10n.tr('japanese'))),
      ],
    );
  }
}

class SealMark extends StatelessWidget {
  const SealMark({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'tempBox',
      child: Container(
        width: size,
        height: size * 0.78,
        decoration: BoxDecoration(
          color: TempColors.box,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: const BoxDecoration(
              color: TempColors.seal,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class BrandImage extends StatelessWidget {
  const BrandImage({
    super.key,
    required this.path,
    this.height = 180,
    this.fallback,
  });
  final String path;
  final double height;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      path,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => fallback ?? const SealMark(),
    );
  }
}

class LiveNote extends StatelessWidget {
  const LiveNote({super.key, required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: message == null
          ? const SizedBox(height: 8)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: TempColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TempColors.seal),
              ),
              child: Text(message!, style: const TextStyle(fontSize: 16)),
            ),
    );
  }
}

class PairingCodeLabel extends StatelessWidget {
  const PairingCodeLabel({super.key, required this.code, required this.label});
  final String? code;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (code == null || code!.isEmpty) return const SizedBox.shrink();
    const style = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: TempColors.seal,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label ', style: style),
          TextSpan(text: code, style: style.copyWith(letterSpacing: 1.1)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.left,
    );
  }
}

enum AppFrame { desk, portrait, landscape }

AppFrame appFrameOf(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final landscape = size.width > size.height;
  if (landscape && size.height < 520) return AppFrame.landscape;
  if (!landscape && size.width < 840) return AppFrame.portrait;
  return AppFrame.desk;
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.app, required this.child});
  final AppController app;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = appFrameOf(context);
    return switch (frame) {
      AppFrame.desk => _desk(context),
      AppFrame.portrait => _portrait(context),
      AppFrame.landscape => _landscape(context),
    };
  }

  Widget _stage({required bool limitWidth}) {
    return Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: limitWidth
            ? ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child)
            : child,
      ),
    );
  }

  Widget _titleRow({required bool showMyPage}) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: const TempBoxMark(fontSize: 28, bar: false),
          ),
        ),
        TextButton(onPressed: () => app.logout(), child: Text(app.l10n.tr('logout'))),
        if (showMyPage) ...[
          const SizedBox(width: 4),
          FilledButton(onPressed: () => app.go(Screen.me), child: Text(app.l10n.tr('my'))),
        ],
      ],
    );
  }

  Widget _desk(BuildContext context) {
    final wideHeader = MediaQuery.sizeOf(context).width >= 768;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            minWidth: 280,
            backgroundColor: TempColors.surface,
            leading: SizedBox(
              width: 248,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PairingCodeLabel(code: app.pairingCode, label: app.l10n.tr('codeNumber')),
                      if (app.profile != null) ...[
                        const SizedBox(height: 12),
                        CloudShelf(app: app),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            selectedIndex: _index(app.screen),
            onDestinationSelected: (index) => app.go([Screen.box, Screen.help, Screen.me][index]),
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(icon: const Icon(Icons.inventory_2_outlined), label: Text(app.l10n.tr('box'))),
              NavigationRailDestination(icon: const Icon(Icons.menu_book_outlined), label: Text(app.l10n.tr('help'))),
              NavigationRailDestination(icon: const Icon(Icons.person_outline), label: Text(app.l10n.tr('my'))),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!wideHeader && (app.pairingCode ?? '').isNotEmpty) ...[
                        PairingCodeLabel(code: app.pairingCode, label: app.l10n.tr('codeNumber')),
                        const SizedBox(height: 8),
                      ],
                      _titleRow(showMyPage: true),
                    ],
                  ),
                ),
                _stage(limitWidth: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _portrait(BuildContext context) {
    final showShelf = app.profile != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: _titleRow(showMyPage: false),
            ),
            if ((app.pairingCode ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: PairingCodeLabel(code: app.pairingCode, label: app.l10n.tr('codeNumber')),
              ),
            if (showShelf)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                child: CloudShelf(app: app, inline: true),
              ),
            _stage(limitWidth: false),
          ],
        ),
      ),
      bottomNavigationBar: _phoneNav(),
    );
  }

  Widget _landscape(BuildContext context) {
    final showShelf = app.profile != null;
    final code = app.pairingCode ?? '';
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: const TempBoxMark(fontSize: 26, bar: false),
                    ),
                  ),
                  if (code.isNotEmpty)
                    Flexible(
                      child: PairingCodeLabel(code: code, label: app.l10n.tr('codeNumber')),
                    ),
                  TextButton(onPressed: () => app.logout(), child: Text(app.l10n.tr('logout'))),
                ],
              ),
            ),
            if (showShelf)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                child: CloudShelf(app: app, inline: true),
              ),
            _stage(limitWidth: false),
          ],
        ),
      ),
      bottomNavigationBar: _phoneNav(height: 56),
    );
  }

  Widget _phoneNav({double height = 64}) {
    return NavigationBar(
      height: height,
      selectedIndex: _index(app.screen),
      onDestinationSelected: (index) => app.go([Screen.box, Screen.help, Screen.me][index]),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), label: app.l10n.tr('box')),
        NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: app.l10n.tr('help')),
        NavigationDestination(icon: const Icon(Icons.person_outline), label: app.l10n.tr('my')),
      ],
    );
  }

  int _index(Screen screen) {
    if (screen == Screen.help) return 1;
    if (screen == Screen.me) return 2;
    return 0;
  }
}

class SelectionActionButton extends StatelessWidget {
  const SelectionActionButton({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final deleting = app.hasSelection;
    return FilledButton(
      onPressed: app.busy
          ? null
          : (deleting ? app.deleteSelected : app.selectAllItems),
      style: FilledButton.styleFrom(
        backgroundColor: deleting ? TempColors.danger : TempColors.seal,
        minimumSize: const Size(96, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        deleting ? app.l10n.tr('delete') : app.l10n.tr('selectAll'),
      ),
    );
  }
}

class CloudShelf extends StatelessWidget {
  const CloudShelf({super.key, required this.app, this.inline = false});
  final AppController app;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final profile = app.profile;
    if (profile == null) return const SizedBox.shrink();
    final cap = cloudCaps.contains(profile.cloudMaxBytes) ? profile.cloudMaxBytes! : cloudCaps.first;
    final box = DropdownButton<int>(
      isExpanded: true,
      value: cap,
      items: [
        for (final option in cloudCaps) DropdownMenuItem(value: option, child: Text(driveCapLabel(option))),
      ],
      onChanged: app.offline
          ? null
          : (value) {
              if (value == null) return;
              app.setShelf('google_cloud', value);
            },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_done_outlined, color: TempColors.seal, size: 22),
            const SizedBox(width: 6),
            Text(app.l10n.tr('googleCloud'), style: TextStyle(fontSize: inline ? 15 : 16, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 2),
        Text(app.l10n.tr('cloudCap'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        SizedBox(width: double.infinity, child: box),
      ],
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.app, required this.item});
  final AppController app;
  final BoxItem item;

  @override
  Widget build(BuildContext context) {
    final locked =
        item.status == 'locked' &&
        (item.lockExpiresAt ?? 0) > DateTime.now().millisecondsSinceEpoch;
    final remain = remainingLabel(
      item.expiresAt,
      DateTime.now().millisecondsSinceEpoch,
      (d, h) => app.l10n.tr('remain', {'d': '$d', 'h': '$h'}),
      (m) => app.l10n.tr('mins', {'m': '$m'}),
    );
    final selected = app.selectedIds.contains(item.itemId);
    final fromHere = app.sentFromHere(item);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxWidth < 460;
        final side = tight ? 8.0 : 28.0;
        return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            semanticLabel: app.l10n.tr('select'),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: Colors.white, width: 1.8),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return Colors.transparent;
            }),
            checkColor: const Color(0xFF2AABEE),
            onChanged: app.busy
                ? null
                : (value) => app.toggleSelected(item.itemId, value == true),
          ),
          Expanded(
            child: Align(
              alignment: fromHere ? Alignment.centerLeft : Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tight ? constraints.maxWidth - 72 : 320),
                child: Container(
                  margin: EdgeInsets.only(left: fromHere ? 4 : side, right: fromHere ? side : 4),
                  padding: const EdgeInsets.fromLTRB(10, 7, 8, 4),
                  decoration: BoxDecoration(
                    color: fromHere ? TempColors.bubbleMine : TempColors.bubbleOther,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(fromHere ? 5 : 16),
                      bottomRight: Radius.circular(fromHere ? 16 : 5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.hasText)
                        Text(
                          item.text!,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.35,
                            color: TempColors.ink,
                          ),
                        ),
                      if (item.fileName != null) ...[
                        if (item.hasText) const SizedBox(height: 6),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFF2AABEE),
                              child: Icon(
                                Icons.insert_drive_file,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.fileName!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    formatBytes(item.bytes ?? 0),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: TempColors.chatMeta,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (item.thumbnailUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.thumbnailUrl!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SealMark(size: 64),
                            ),
                          ),
                        ),
                      if (locked) ...[
                        const SizedBox(height: 4),
                        Text(
                          app.l10n.tr('locked'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: TempColors.chatMeta,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (item.hasText)
                            IconButtonTheme(
                              data: IconButtonThemeData(
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(32, 32),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: TempColors.seal,
                                ),
                              ),
                              child: IconButton(
                                tooltip: app.l10n.tr('copy'),
                                onPressed: () => app.copyItem(item),
                                icon: const Icon(Icons.copy, size: 18),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            '$remain  ${seoulHm(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TempColors.chatMeta,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: app.l10n.tr('download'),
            onPressed: locked || app.offline || app.busy
                ? null
                : () => app.receive(item),
            icon: const Icon(Icons.download_outlined, color: Colors.white),
          ),
        ],
      ),
    );
      },
    );
  }
}

class StatChart extends StatelessWidget {
  const StatChart({
    super.key,
    required this.bars,
    required this.guestLabel,
    required this.signedLabel,
  });
  final List<StatBar> bars;
  final String guestLabel;
  final String signedLabel;

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.fold<int>(
      1,
      (max, bar) =>
          (bar.guest + bar.signed) > max ? bar.guest + bar.signed : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [Text('▤ $guestLabel'), Text('■ $signedLabel')],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bar in bars)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${bar.guest + bar.signed}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 110 * ((bar.guest + bar.signed) / maxValue),
                          child: Column(
                            children: [
                              Expanded(
                                flex: bar.guest == 0 ? 1 : bar.guest,
                                child: const ColoredBox(color: TempColors.box),
                              ),
                              Expanded(
                                flex: bar.signed == 0 ? 1 : bar.signed,
                                child: const ColoredBox(color: TempColors.seal),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          bar.date.substring(6),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
