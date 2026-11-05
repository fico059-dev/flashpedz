import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'dart:ui';
import 'package:flashcards/bloc/flashcards/fc_review_getter/fc_review_getter_cubit.dart';
import 'package:flashcards/bloc/flashcards/fc_review_getter/fc_review_getter_state.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_state.dart';
import 'package:flashcards/data/mappers/fsrs_mapper.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/domain/models/profile/profile.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/error_screen.dart';
import 'package:flashcards/ui/widgets/core/images/image_preview.dart';
import 'package:flashcards/ui/widgets/core/tag_chip.dart';
import 'package:flashcards/ui/widgets/fc_review_bottom_sheet/fc_review_sheet_admin_floating_button.dart';
import 'package:flashcards/ui/widgets/fc_review_bottom_sheet/fc_review_sheet_header.dart';
import 'package:flashcards/ui/widgets/fc_review_bottom_sheet/fc_review_sheet_user_floating_button.dart';
import 'package:flashcards/ui/widgets/flashcard/fsrs_card_items/card_meta_chip_enhanced.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flashcards/config/features.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<bool?> showFcReviewBottomSheet({
  required BuildContext context,
  required String flashcardId,
  required String question,
  required String answer,
  required bool isPaid,
  required bool hasCards,
  String? packId,
}) async {
  return await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scrollController) {
          return BlocProvider(
            create: (context) => FcReviewGetterCubit(
              fcRepo: context.read<FlashcardRepository>(),
              fcpRepo: context.read<FcpRepository>(),
            ),
            child: _FlashcardBottomSheet(
              hasCards: hasCards,
              isPaid: isPaid,
              answer: answer,
              question: question,
              flashcardId: flashcardId,
              packId: packId,
              scrollController: scrollController,
            ),
          );
        },
      );
    },
  );
}

class _FlashcardBottomSheet extends StatefulWidget {
  final String flashcardId;
  final String question;
  final String answer;
  final bool isPaid;
  final bool hasCards;
  final String? packId;
  final ScrollController scrollController;

  const _FlashcardBottomSheet({
    super.key,
    this.packId,
    required this.scrollController,
    required this.flashcardId,
    required this.question,
    required this.answer,
    required this.isPaid,
    required this.hasCards,
  });

  @override
  State<_FlashcardBottomSheet> createState() => _FlashcardBottomSheetState();
}

class _FlashcardBottomSheetState extends State<_FlashcardBottomSheet> {
  late final bool isAdmin;

  void _fetchReview() {
    context.read<FcReviewGetterCubit>().getFlashcardReview(
      isPaid: widget.isPaid,
      hasCards: widget.hasCards,
      answer: widget.answer,
      question: widget.question,
      flashcardId: widget.flashcardId,
      packId: widget.packId,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchReview();

    final state = context.read<ProfileReaderCubit>().state;
    if (state is! ProfileReaderIsLoaded) {
      throw Exception(
        "Profile reader state is not loaded. Make sure to put "
        "'profileLoadedGuard' route guard on this page",
      );
    }

    isAdmin = state.profile.isAdmin;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FcReviewSheetHeader(),
        Expanded(
          child: BlocBuilder<FcReviewGetterCubit, FcReviewGetterState>(
            builder: (context, state) {
              switch (state) {
                case FcReviewGetterInitial():
                case FcReviewGetterLoading():
                  // The question and answer are known already: shown
                  // straight away while the rest loads.
                  return Padding(
                    padding: bottomSheetHorizontalPadding,
                    child: ListView(
                      controller: widget.scrollController,
                      children: [
                        _buildFlashcardItem(
                          icon: Icons.help_outline,
                          iconColor: context.colors.primary,
                          label: widget.question,
                          context: context,
                        ),
                        _buildFlashcardItem(
                          icon: Icons.lightbulb_outline,
                          iconColor: context.colors.tertiary,
                          label: widget.answer,
                          context: context,
                        ),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                    ),
                  );
                case FcReviewGetterError(:final error):
                  return ErrorScreen(
                    errorMessage: extractErrorMessage(error),
                    onReload: _fetchReview,
                  );
                case FcReviewGetterLoaded():
                  return _LoadedContent(
                    state: state,
                    scrollController: widget.scrollController,
                    isAdmin: isAdmin,
                  );
                case FcReviewGetterForbidden():
                  return BlockedFlashcardPreview(
                    onUnlock: () async {
                      await ensureCardsAccess(context);
                    },
                  );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _LoadedContent extends StatelessWidget {
  final FcReviewGetterLoaded state;
  final ScrollController scrollController;
  final bool isAdmin;

  const _LoadedContent({
    super.key,
    required this.state,
    required this.isAdmin,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          context.theme.bottomSheetTheme.backgroundColor ??
          context.colors.surfaceContainerLow,
      body: Padding(
        padding: bottomSheetHorizontalPadding,
        child: ListView(
          controller: scrollController,
          children: [_FlashcardInfoContent(state: state)],
        ),
      ),
      floatingActionButton: isAdmin
          ? FcReviewSheetAdminFloatingButton(state: state)
          : FcReviewSheetUserFloatingButton(state: state),
    );
  }
}

class _FlashcardInfoContent extends StatelessWidget {
  final FcReviewGetterLoaded state;

  const _FlashcardInfoContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final review = state.fcReview;
    final flashcard = review.record.flashcard!;
    final fsrsCard = review.record.card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFlashcardItem(
          icon: Icons.help_outline,
          iconColor: context.colors.primary,
          label: flashcard.question,
          imageUrl: flashcard.questionImageUrl,
          context: context,
        ),
        _buildFlashcardItem(
          icon: Icons.lightbulb_outline,
          iconColor: context.colors.tertiary,
          label: flashcard.answer,
          imageUrl: flashcard.answerImageUrl,
          context: context,
        ),

        // Tags
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: flashcard.tags
              .map(
                (tag) => TagChip(
                  label: tag.name,
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 15),

        _InfoItem(
          icon: Icons.folder_open,
          text:
              '${review.packName} with ${review.packFlashcardsCount} flashcards',
        ),
        const SizedBox(height: 15),

        // Pack & FSRS Info
        Wrap(
          runSpacing: 8,
          spacing: 8,
          children: fsrsCard
              .buildCardInfoItems()
              .map((item) => CardMetaChipEnhanced(item: item))
              .toList(),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Widget _buildFlashcardItem({
  required IconData icon,
  required Color iconColor,
  required String label,
  String? imageUrl,
  required BuildContext context,
}) {
  return Card(
    color: context.colors.surfaceContainerHighest,
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardContent(
                  label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ImagePreview(
                      downloadUrl: imageUrl,
                      height: 120,
                      showTextWhenEmpty: false,
                      onTap: () => onUrlTap(context, imageUrl),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class BlockedFlashcardPreview extends StatelessWidget {
  final VoidCallback onUnlock;

  const BlockedFlashcardPreview({super.key, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Original content (dummy, jer je zaključan)
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildPlaceholderCard(
                context,
                Icons.help_outline,
                "Question preview...",
              ),
              _buildPlaceholderCard(
                context,
                Icons.lightbulb_outline,
                "Answer preview...",
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  3,
                  (i) => TagChip(label: "Premium Tag"),
                ),
              ),
              const SizedBox(height: 15),
              _InfoItem(icon: Icons.folder_open, text: "Premium pack"),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  3,
                  (i) => Chip(
                    label: const Text("Meta info"),
                    backgroundColor: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),

          // Blur + overlay
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: context.colors.surfaceContainerHigh.withValues(
                    alpha: 0.4,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: context.colors.surface,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "This flashcard is premium",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: context.colors.surface),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: onUnlock,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          Features.subscriptions
                              ? "Unlock with Premium"
                              : "Coming soon",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: context.colors.onSurfaceVariant, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
