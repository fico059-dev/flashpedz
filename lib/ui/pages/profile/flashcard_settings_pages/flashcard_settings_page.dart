import 'package:auto_route/auto_route.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/dialogs/flashcard/daily_limits_dialog.dart';
import 'package:flashcards/ui/widgets/profile/profile_menu_widget.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';

@RoutePage()
class FlashcardSettingsPage extends StatelessWidget {
  const FlashcardSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flashcard Settings"),
        leading: IconButton(
          onPressed: () => context.router.pop(),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: ReadableWidth(
        maxWidth: 820,
        child: Container(
          margin: EdgeInsets.only(top: 25),
          padding: EdgeInsets.symmetric(horizontal: horizontalScreenPadding),
          child: Column(
            children: [
              ProfileMenuWidget(
                title: "Progress",
                icon: Icons.insights,
                onPress: () => context.router.navigate(
                  const MainTabRoute(children: [LearningProgressRoute()]),
                ),
              ),
              ProfileMenuWidget(
                title: "Daily New Cards & Reviews",
                icon: Icons.tune,
                onPress: () => showDailyLimitsDialog(context),
              ),
              ProfileMenuWidget(
                title: "Manage Ignored Flashcards",
                icon: Icons.visibility_off,
                onPress: () =>
                    context.router.push(const ManageIgnoredFlashcardsRoute()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
