import 'package:auto_route/auto_route.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flutter/material.dart';

@RoutePage()
class PacksTabPage extends StatefulWidget {
  const PacksTabPage({super.key});

  @override
  State<PacksTabPage> createState() => _PacksTabPageState();
}

class _PacksTabPageState extends State<PacksTabPage> {
  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter.tabBar(
      routes: const [PacksRoute(), PreviousSessionsRoute(), NotebookRoute()],
      builder: (context, child, controller) {
        return Column(
          children: [
            TabBar(
              controller: controller,
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'All Packs'),
                Tab(text: 'Examine Yourself'),
                Tab(text: 'Notebook'),
              ],
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
