import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../broadcasts/broadcast_page.dart';
import '../commands/commands_page.dart';
import '../commands/read_only_commands_page.dart';
import '../dashboard/dashboard_page.dart';
import '../more/more_page.dart';
import '../scheduled/scheduled_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final entries = <({NavigationDestination destination, Widget page})>[
          (
            destination: const NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            page: DashboardPage(controller: widget.controller),
          ),
          if (widget.controller.can('commands.read'))
            (
              destination: const NavigationDestination(
                icon: Icon(Icons.quickreply_rounded),
                label: 'الردود',
              ),
              page: widget.controller.can('commands.write')
                  ? CommandsPage(controller: widget.controller)
                  : ReadOnlyCommandsPage(controller: widget.controller),
            ),
          if (widget.controller.can('scheduled.write'))
            (
              destination: const NavigationDestination(
                icon: Icon(Icons.schedule_send_rounded),
                label: 'المجدولة',
              ),
              page: ScheduledPage(controller: widget.controller),
            ),
          if (widget.controller.can('broadcasts.write'))
            (
              destination: const NavigationDestination(
                icon: Icon(Icons.campaign_rounded),
                label: 'إرسال',
              ),
              page: BroadcastPage(controller: widget.controller),
            ),
          (
            destination: const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'المزيد',
            ),
            page: MorePage(controller: widget.controller),
          ),
        ];

        final selected = _index.clamp(0, entries.length - 1);
        final destinations = entries.map((entry) => entry.destination).toList();
        final pages = entries.map((entry) => entry.page).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final body = IndexedStack(index: selected, children: pages);

            if (wide) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: selected,
                        onDestinationSelected: (value) =>
                            setState(() => _index = value),
                        labelType: NavigationRailLabelType.all,
                        destinations: destinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: item.icon,
                                selectedIcon: item.selectedIcon,
                                label: Text(item.label),
                              ),
                            )
                            .toList(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              body: SafeArea(child: body),
              bottomNavigationBar: NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: destinations,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
              ),
            );
          },
        );
      },
    );
  }
}
