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
        decoration: BoxDecoration(color: TempColors.box, borderRadius: BorderRadius.circular(10)),
        child: Center(
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: const BoxDecoration(color: TempColors.seal, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class BrandImage extends StatelessWidget {
  const BrandImage({super.key, required this.path, this.height = 180, this.fallback});
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
              decoration: BoxDecoration(color: TempColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: TempColors.seal)),
              child: Text(message!, style: const TextStyle(fontSize: 16)),
            ),
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
          child: Row(
            children: [
              Text(app.l10n.tr('app'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: TempColors.seal)),
              const Spacer(),
              TextButton(onPressed: () => app.logout(), child: Text(app.l10n.tr('logout'))),
              const SizedBox(width: 4),
              FilledButton(onPressed: () => app.go(Screen.me), child: Text(app.l10n.tr('my'))),
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
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: _index(app.screen),
        onDestinationSelected: (index) => app.go([Screen.box, Screen.help, Screen.me][index]),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), label: app.l10n.tr('box')),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), label: app.l10n.tr('help')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: app.l10n.tr('my')),
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

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.app, required this.item});
  final AppController app;
  final BoxItem item;

  @override
  Widget build(BuildContext context) {
    final locked = item.status == 'locked' && (item.lockExpiresAt ?? 0) > DateTime.now().millisecondsSinceEpoch;
    final remain = remainingLabel(
      item.expiresAt,
      DateTime.now().millisecondsSinceEpoch,
      (d, h) => app.l10n.tr('remain', {'d': '$d', 'h': '$h'}),
      (m) => app.l10n.tr('mins', {'m': '$m'}),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: TempColors.box, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.hasText) Text(item.text!, style: const TextStyle(fontSize: 16, color: TempColors.ink)),
              if (item.fileName != null) ...[
                const SizedBox(height: 6),
                Text('${item.fileName} · ${formatBytes(item.bytes ?? 0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
              if (item.thumbnailUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Image.network(item.thumbnailUrl!, height: 96, errorBuilder: (_, _, _) => const SealMark(size: 64)),
                ),
              const SizedBox(height: 6),
              Text(remain, style: const TextStyle(fontSize: 13, color: TempColors.seal)),
              if (locked) Text(app.l10n.tr('locked'), style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.hasText)
                    OutlinedButton(onPressed: () => app.copyItem(item), child: Text(app.l10n.tr('copy'))),
                  FilledButton(
                    onPressed: locked || app.offline ? null : () => app.receive(item),
                    child: Text(item.kind == 'message' ? app.l10n.tr('receiveText') : app.l10n.tr('receive')),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: TempColors.danger, side: const BorderSide(color: TempColors.danger)),
                    onPressed: () => app.deleteItem(item),
                    child: Text(app.armedDelete == item.itemId ? app.l10n.tr('deleteConfirm') : app.l10n.tr('delete')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatChart extends StatelessWidget {
  const StatChart({super.key, required this.bars, required this.guestLabel, required this.signedLabel});
  final List<StatBar> bars;
  final String guestLabel;
  final String signedLabel;

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.fold<int>(1, (max, bar) => (bar.guest + bar.signed) > max ? bar.guest + bar.signed : max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            Text('▤ $guestLabel'),
            Text('■ $signedLabel'),
          ],
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
                        Text('${bar.guest + bar.signed}', style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 110 * ((bar.guest + bar.signed) / maxValue),
                          child: Column(
                            children: [
                              Expanded(flex: bar.guest == 0 ? 1 : bar.guest, child: const ColoredBox(color: TempColors.box)),
                              Expanded(flex: bar.signed == 0 ? 1 : bar.signed, child: const ColoredBox(color: TempColors.seal)),
                            ],
                          ),
                        ),
                        Text(bar.date.substring(6), style: const TextStyle(fontSize: 12)),
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
