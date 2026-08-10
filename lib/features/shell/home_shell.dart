import 'package:flutter/material.dart';
import '../../core/app_controller.dart';
import '../ai/ai_chat_page.dart';
import '../approvals/approvals_page.dart';
import '../commands/commands_page.dart';
import '../dashboard/dashboard_page.dart';
import '../groups/groups_page.dart';
import '../settings/settings_page.dart';
import '../statistics/statistics_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_rounded),
      label: 'الرئيسية',
    ),
    NavigationDestination(
      icon: Icon(Icons.quickreply_rounded),
      label: 'الردود',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_rounded),
      label: 'المجموعات',
    ),
    NavigationDestination(
      icon: Icon(Icons.approval_rounded),
      label: 'الموافقات',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_rounded),
      label: 'الإحصائيات',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_rounded),
      label: 'الذكاء',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_rounded),
      label: 'الإعدادات',
    ),
  ];

  List<Widget> _buildPages() => [
        DashboardPage(controller: widget.controller),
        CommandsPage(controller: widget.controller),
        GroupsPage(controller: widget.controller),
        ApprovalsPage(controller: widget.controller),
        StatisticsPage(controller: widget.controller),
        AiChatPage(controller: widget.controller),
        SettingsPage(controller: widget.controller),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pages = _buildPages();
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final body = IndexedStack(index: _index, children: pages);

            if (wide) {
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: (value) {
                          setState(() => _index = value);
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: _destinations
                            .map(
                              (d) => NavigationRailDestination(
                                icon: d.icon,
                                selectedIcon: d.selectedIcon,
                                label: Text(d.label),
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
                selectedIndex: _index,
                onDestinationSelected: (value) {
                  setState(() => _index = value);
                },
                destinations: _destinations,
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
