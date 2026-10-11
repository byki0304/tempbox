import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../entities/models.dart';
import '../../features/app_controller.dart';
import '../../shared/format.dart';

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
      textAlign: TextAlign.left,
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.app, required this.child});
  final AppController app;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide && (app.pairingCode ?? '').isNotEmpty) ...[
                PairingCodeLabel(
                  code: app.pairingCode,
                  label: app.l10n.tr('codeNumber'),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Text(
                    app.l10n.tr('app'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TempColors.seal,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => app.logout(),
                    child: Text(app.l10n.tr('logout')),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => app.go(Screen.me),
                    child: Text(app.l10n.tr('my')),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        ),
      ],
    );
    if (wide) {
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
                        PairingCodeLabel(
                          code: app.pairingCode,
                          label: app.l10n.tr('codeNumber'),
                        ),
                        if (app.profile != null && !app.profile!.isGuest) ...[
                          const SizedBox(height: 12),
                          CloudShelf(app: app),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              selectedIndex: _index(app.screen),
              onDestinationSelected: (index) =>
                  app.go([Screen.box, Screen.help, Screen.me][index]),
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(app.l10n.tr('box')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(app.l10n.tr('help')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.person_outline),
                  label: Text(app.l10n.tr('my')),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    final account = app.profile != null && !app.profile!.isGuest;
    return Scaffold(
      body: account
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: TempColors.surface,
                  child: SizedBox(
                    width: 188,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 8, 12),
                        child: CloudShelf(app: app),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _index(app.screen),
        onDestinationSelected: (index) =>
            app.go([Screen.box, Screen.help, Screen.me][index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            label: app.l10n.tr('box'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            label: app.l10n.tr('help'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: app.l10n.tr('my'),
          ),
        ],
      ),
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
  const CloudShelf({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final profile = app.profile;
    if (profile == null || profile.isGuest) return const SizedBox.shrink();
    final enabled = profile.storageBackend == 'google_cloud';
    final cap = cloudCaps.contains(profile.cloudMaxBytes) ? profile.cloudMaxBytes! : cloudCaps.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: enabled,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(app.l10n.tr('googleCloud'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          onChanged: app.offline ? null : (value) => app.setShelf(value == true ? 'google_cloud' : 'firebase', cap),
        ),
        Text(app.l10n.tr('cloudCap'), style: const TextStyle(fontSize: 13, color: TempColors.chatMeta)),
        DropdownButton<int>(
          isExpanded: true,
          value: cap,
          items: [
            for (final option in cloudCaps)
              DropdownMenuItem(value: option, child: Text(driveCapLabel(option))),
          ],
          onChanged: app.offline
              ? null
              : (value) {
                  if (value == null) return;
                  app.setShelf(enabled ? 'google_cloud' : 'firebase', value);
                },
        ),
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
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  margin: EdgeInsets.only(left: fromHere ? 6 : 28, right: fromHere ? 28 : 6),
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
