import 'package:flutter/material.dart';
import '../start/start_page.dart';
import '../plans/plans_page.dart';
import '../exercises/exercises_page.dart';
import '../history/history_page.dart';
import '../settings/settings_page.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key, this.initialTab});
  final String? initialTab;

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  late int _index;

  static const Map<String, int> _slugToIndex = {
    'today': 0,
    'plans': 1,
    'exercises': 2,
    'history': 3,
  };

  @override
  void initState() {
    super.initState();
    _index = _slugToIndex[widget.initialTab ?? 'today'] ?? 0;
  }

  // Wichtig: Liste selbst 'const' UND Elemente 'const'
  static const List<Widget> _pages = <Widget>[
    StartPage(),
    PlansPage(),
    ExercisesPage(),
    HistoryPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Heute',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list),
            label: 'Pläne',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Übungen',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historie',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}
