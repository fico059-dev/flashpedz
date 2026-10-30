import 'package:auto_route/auto_route.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';

class TutorialSlide {
  final IconData? icon;
  final String? assetPath;
  final String? assetPath2;
  final String title;
  final String description;

  const TutorialSlide({
    this.icon,
    required this.title,
    required this.description,
    this.assetPath,
    this.assetPath2,
  });
}

class TutorialPageTemplate extends StatefulWidget {
  final List<TutorialSlide> slides;
  final VoidCallback? onFinish;

  const TutorialPageTemplate({super.key, required this.slides, this.onFinish});

  @override
  State<TutorialPageTemplate> createState() => _TutorialPageTemplateState();
}

class _TutorialPageTemplateState extends State<TutorialPageTemplate> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  /// Closes the tutorial; it counts as seen, so it doesn't open again.
  void _finish() {
    widget.onFinish?.call();
    context.router.pop();
  }

  void _goToPage(int index) {
    if (index >= 0 && index < widget.slides.length) {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReadableWidth(
        maxWidth: 820,
        child: SafeArea(
          child: Column(
            children: [
              // Exit at any time, not only after the last slide.
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: TextButton.icon(
                    onPressed: _finish,
                    icon: const Icon(Icons.close),
                    label: const Text(
                      "Exit",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              // PageView with slides
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = widget.slides[index];
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (slide.icon != null)
                            Icon(
                              slide.icon!,
                              size: 120,
                              color: context.colors.primary,
                            ),
                          if (slide.icon != null) const SizedBox(height: 32),
                          if (slide.assetPath != null)
                            Image.asset(slide.assetPath!, width: 250),
                          if (slide.assetPath2 != null)
                            Image.asset(slide.assetPath2!, width: 250),

                          if (slide.assetPath != null) SizedBox(height: 10),

                          Text(
                            slide.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            slide.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Indicator (bullets)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.slides.length,
                  (index) => Container(
                    margin: const EdgeInsets.all(4),
                    width: _currentPage == index ? 12 : 8,
                    height: _currentPage == index ? 12 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? context.colors.primaryContainer
                          : context.colors.outlineVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous
                    TextButton(
                      onPressed: _currentPage > 0
                          ? () => _goToPage(_currentPage - 1)
                          : null,
                      child: const Text("Previous"),
                    ),
                    // A clear way out next to Next, not only the small
                    // button at the top.
                    if (_currentPage < widget.slides.length - 1)
                      OutlinedButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("Exit tutorial"),
                      ),
                    // Next
                    FilledButton(
                      onPressed: _currentPage < widget.slides.length - 1
                          ? () => _goToPage(_currentPage + 1)
                          : _finish,
                      child: Text(
                        _currentPage == widget.slides.length - 1
                            ? "Finish"
                            : "Next",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
