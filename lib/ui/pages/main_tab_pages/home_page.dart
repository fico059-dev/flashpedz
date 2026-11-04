import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/progress/progress_repository.dart';
import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/domain/models/progress/card_progress.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:flashcards/ui/pages/main_tab_pages/main_tab_routes.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/home/card_garden.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/ui/dialogs/flashcard/daily_limits_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Words of encouragement, a different one each day.
const homeGreetings = [
  "Small steps every day add up to big results.",
  "Today's effort is tomorrow's confidence on the wards.",
  "You don't have to be perfect, just consistent.",
  "Every card you review is a patient you'll help one day.",
  "Learning medicine is a marathon. Keep a steady pace.",
  "Your future patients are lucky to have someone this dedicated.",
  "Progress, not perfection.",
  "One more card, one more step closer to your goal.",
  "Hard cards today become easy answers tomorrow.",
  "Showing up is half the work. You're already here!",
  "Knowledge compounds. Today's review makes tomorrow easier.",
  "Stay curious: every question is a chance to learn.",
  "Great doctors are made one day at a time.",
  "Breathe, focus, and give today your best.",
  "Your streak is your superpower. Keep it alive!",
  "The best time to study was yesterday. The next best is now.",
  "Mistakes on cards are lessons you won't repeat at the bedside.",
  "Trust the process: spaced repetition works.",
  "Be proud of how far you've come.",
  "Focus on today's cards; the exam will take care of itself.",
];

/// The greeting for [day]: the same all day, different the next day.
String greetingFor(DateTime day) {
  final dayOfYear = day.difference(DateTime(day.year)).inDays;
  return homeGreetings[(dayOfYear + day.year) % homeGreetings.length];
}

String timeOfDayGreeting(DateTime now) => switch (now.hour) {
  < 12 => 'Good morning',
  < 17 => 'Good afternoon',
  _ => 'Good evening',
};

/// Status of the goal's cards (all cards without a goal).
GardenCounts goalGardenCounts(CardProgressStats stats, StudyGoal goal) {
  var unseen = 0, learning = 0, reviewing = 0, mastered = 0;
  for (final pack in stats.packs) {
    if (!goal.includesPack(pack.packId)) continue;
    unseen += pack.unseen;
    learning += pack.learning;
    mastered += pack.mastered;
    reviewing += (pack.studied - pack.learning - pack.mastered).clamp(
      0,
      pack.total,
    );
  }
  return GardenCounts(
    unseen: unseen,
    learning: learning,
    reviewing: reviewing,
    mastered: mastered,
  );
}

class _HomeData {
  final CardProgressStats? stats;
  final StudyLog log;
  final DailyStatus? today;

  /// Each goal card's progress in pack order, for the garden.
  final List<int>? cardLevels;

  const _HomeData({
    required this.stats,
    required this.log,
    this.today,
    this.cardLevels,
  });
}

@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<_HomeData>? _data;
  int? _cardsPerSession;

  Future<_HomeData> _load({bool refresh = false}) async {
    final repo = context.read<ProgressRepository>();
    final daily = context.read<DailyTargetService>();
    final cardsPerSession = _cardsPerSession ?? 10;
    final statsResult = await repo.getCardStats(refresh: refresh);
    final log = await repo.getLog();
    DailyStatus? today;
    try {
      today = await daily.status(cardsPerSession);
    } catch (_) {
      today = null;
    }
    final stats = switch (statsResult) {
      Ok(:final value) => value,
      Error() => null,
    };
    return _HomeData(
      stats: stats,
      log: log,
      today: today,
      cardLevels: stats == null ? null : await repo.goalCardLevels(log.goal),
    );
  }

  /// Opens the daily plan, suggesting what the exam goal needs.
  Future<void> _editPlan() async {
    final data = await _data;
    if (!mounted) return;
    final changed = await showDailyPlanDialog(
      context,
      goalPerDay: data?.today?.goalPerDay,
    );
    if (changed && mounted) setState(() => _data = _load());
  }

  void _goToTab(MainTab tab) => AutoTabsRouter.of(
    context,
  ).setActiveIndex(MainTabRoutes.mainTabToIndex(tab));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileReaderCubit, ProfileReaderState>(
      builder: (context, profileState) {
        final profile = profileState is ProfileReaderIsLoaded
            ? profileState.profile
            : null;
        final cardsPerSession = profile?.profileSettings.cardsPerSession;
        if (cardsPerSession != null && cardsPerSession != _cardsPerSession) {
          _cardsPerSession = cardsPerSession;
          _data = _load();
        }
        _data ??= _load();
        final now = DateTime.now();

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                final next = _load(refresh: true);
                setState(() => _data = next);
                await next;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Text(
                    '${timeOfDayGreeting(now)}'
                    '${profile == null ? '' : ', ${profile.name}'}!',
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greetingFor(now),
                    style: context.text.bodyLarge?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<_HomeData>(
                    future: _data,
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      if (data == null) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TodayPlan(
                            data: data,
                            onStudy: () => _goToTab(MainTab.packs),
                            onOsce: () => _goToTab(MainTab.osce),
                            onEditPlan: _editPlan,
                          ),
                          const SizedBox(height: 16),
                          if (data.stats != null)
                            _GardenCard(
                              stats: data.stats!,
                              cardLevels: data.cardLevels,
                              goal: data.log.goal,
                              onSetGoal: () =>
                                  _goToTab(MainTab.learningProgress),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _QuickLinks(
                    onProgress: () => _goToTab(MainTab.learningProgress),
                    onDailyPlan: _editPlan,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TodayPlan extends StatelessWidget {
  final _HomeData data;
  final VoidCallback onStudy;
  final VoidCallback onOsce;
  final VoidCallback onEditPlan;

  const _TodayPlan({
    required this.data,
    required this.onStudy,
    required this.onOsce,
    required this.onEditPlan,
  });

  @override
  Widget build(BuildContext context) {
    final today = data.today;
    final due = data.stats?.dueNow;
    final exam = data.log.goal.examDate;
    final daysLeft = exam == null
        ? null
        : startOfDay(exam).difference(startOfDay(DateTime.now())).inDays;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: context.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Today's plan",
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateFormat('EEE d MMM').format(DateTime.now()),
                  style: context.text.labelMedium,
                ),
                IconButton(
                  tooltip: 'Daily plan',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEditPlan,
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ],
            ),
            if (daysLeft != null && daysLeft > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Exam in $daysLeft days · '
                  '${DateFormat('d MMM yyyy').format(exam!)}',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (today?.plan case final plan?)
              _PlanItem(
                icon: Icons.style_outlined,
                title: 'Study ${today!.target} cards today',
                subtitle:
                    '${plan.newCards} new · ${plan.reviews} reviews'
                    '${due == null || due == 0 ? '' : ' ($due due now)'}',
                progress: today.progress,
                done: today.done >= today.target,
                onTap: onStudy,
                details: [
                  _PlanPart(
                    label: 'New',
                    done: today.newDone,
                    target: plan.newCards,
                  ),
                  _PlanPart(
                    label: 'Reviews',
                    done: today.reviewDone,
                    target: plan.reviews,
                  ),
                ],
              )
            else ...[
              _PlanItem(
                icon: Icons.replay,
                title: due == null
                    ? 'Review due cards'
                    : due == 0
                    ? 'No reviews due, all caught up'
                    : 'Review $due due ${due == 1 ? 'card' : 'cards'}',
                done: due == 0,
                onTap: onStudy,
              ),
              _PlanItem(
                icon: Icons.style_outlined,
                title: today == null
                    ? 'Study your cards'
                    : 'Study ${today.target} cards'
                          '${today.fromGoal ? ' today' : ''}',
                subtitle: today == null
                    ? null
                    : '${today.done.clamp(0, today.target)} of ${today.target} '
                          'done today',
                progress: today?.progress,
                done: today != null && today.done >= today.target,
                onTap: onStudy,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onEditPlan,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Choose cards a day and how many are new'),
                ),
              ),
            ],
            _PlanItem(
              icon: Icons.medical_services_outlined,
              title: 'Practice one OSCE station',
              subtitle: 'Say the steps out loud as if in the exam',
              onTap: onOsce,
            ),
          ],
        ),
      ),
    );
  }
}

/// New cards or reviews in the daily plan: done of target.
class _PlanPart {
  final String label;
  final int done;
  final int target;

  const _PlanPart({
    required this.label,
    required this.done,
    required this.target,
  });
}

class _PlanItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double? progress;
  final bool done;
  final VoidCallback onTap;
  final List<_PlanPart> details;

  const _PlanItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.progress,
    this.done = false,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    final green = Colors.green.shade600;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : icon,
              color: done ? green : context.colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyLarge?.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? context.colors.onSurfaceVariant : null,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: context.text.bodySmall),
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: done ? green : null,
                      ),
                    ),
                  ],
                  for (final part in details)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              part.label,
                              style: context.text.labelMedium,
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: part.target <= 0
                                    ? 1
                                    : (part.done / part.target).clamp(0.0, 1.0),
                                minHeight: 4,
                                color: part.done >= part.target ? green : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${part.done.clamp(0, part.target)}/${part.target}',
                            style: context.text.labelMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _GardenCard extends StatefulWidget {
  final CardProgressStats stats;
  final List<int>? cardLevels;
  final StudyGoal goal;
  final VoidCallback onSetGoal;

  const _GardenCard({
    required this.stats,
    this.cardLevels,
    required this.goal,
    required this.onSetGoal,
  });

  @override
  State<_GardenCard> createState() => _GardenCardState();
}

class _GardenCardState extends State<_GardenCard> {
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    final levels = widget.cardLevels;
    // Laid out by the packs' card order when known, else by the counts.
    final counts = levels == null
        ? goalGardenCounts(widget.stats, widget.goal)
        : GardenCounts(
            unseen: levels.where((l) => l == 0).length,
            learning: levels.where((l) => l == 1).length,
            reviewing: levels.where((l) => l == 2).length,
            mastered: levels.where((l) => l == 3).length,
          );
    final plots = levels == null
        ? gardenPlots(counts)
        : gardenPlotsFromCards(levels);
    final names = [
      for (final p in widget.stats.packs)
        if (widget.goal.includesPack(p.packId)) p.name,
    ];
    final learned = counts.reviewing + counts.mastered;
    final percent = counts.total == 0 ? 0 : learned * 100 ~/ counts.total;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.local_florist, color: Colors.pink.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your knowledge garden',
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.local_florist, size: 18),
                      tooltip: 'Garden',
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.grid_view, size: 18),
                      tooltip: 'Grid',
                    ),
                  ],
                  selected: {_grid},
                  onSelectionChanged: (value) =>
                      setState(() => _grid = value.first),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.goal.hasPacks
                  ? 'Goal packs: ${names.take(3).join(', ')}'
                        '${names.length > 3 ? ' +${names.length - 3} more' : ''}'
                  : 'All your packs. Choose your exam packs in Progress to '
                        'grow only those.',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (plots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No cards in your goal packs yet.')),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _grid
                      ? context.colors.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        )
                      : const Color(0xFFE8F5E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CardGarden(plots: plots, asGrid: _grid),
              ),
            const SizedBox(height: 10),
            Text(
              '$percent% learned · ${counts.total} cards · '
              'each ${_grid ? 'square' : 'flower'} is $cardsPerPlot cards',
              style: context.text.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Legend(
                  color: _grid
                      ? gridColor(PlotStatus.unseen)
                      : const Color(0xFF6DB34F),
                  label: _grid ? 'New' : 'Sprout: new',
                  count: counts.unseen,
                ),
                _Legend(
                  color: _grid
                      ? gridColor(PlotStatus.learning)
                      : const Color(0xFFFFC107),
                  label: _grid ? 'Learning' : 'Bud: learning',
                  count: counts.learning,
                ),
                _Legend(
                  color: _grid
                      ? gridColor(PlotStatus.reviewing)
                      : const Color(0xFFF06292),
                  label: _grid ? 'Reviewing' : 'Pink rose: reviewing',
                  count: counts.reviewing,
                ),
                _Legend(
                  color: _grid
                      ? gridColor(PlotStatus.mastered)
                      : const Color(0xFFC62828),
                  label: _grid ? 'Memorized' : 'Red rose: memorized',
                  count: counts.mastered,
                ),
              ],
            ),
            if (!widget.goal.hasPacks)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.onSetGoal,
                  child: const Text('Choose exam packs'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _Legend({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label ($count)', style: context.text.bodySmall),
      ],
    );
  }
}

class _QuickLinks extends StatelessWidget {
  final VoidCallback onProgress;
  final VoidCallback onDailyPlan;

  const _QuickLinks({required this.onProgress, required this.onDailyPlan});

  @override
  Widget build(BuildContext context) {
    Widget link(IconData icon, String label, VoidCallback onTap) => ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        link(
          Icons.search,
          'Browse flashcards',
          () => context.router.push(const FlashcardsSearcherRoute()),
        ),
        link(
          Icons.history,
          'OSCE results',
          () => context.router.push(const OscePerformancesRoute()),
        ),
        // The daily plan replaces cards per session.
        link(Icons.tune, 'Daily plan', onDailyPlan),
        link(Icons.insights, 'Progress', onProgress),
      ],
    );
  }
}
