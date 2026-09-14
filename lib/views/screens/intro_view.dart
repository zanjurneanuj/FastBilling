import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/IntroService.dart';
import '../../utils/app_colors.dart';

class _Slide {
  const _Slide({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    icon: Icons.bolt_rounded,
    title: 'Create invoices in seconds',
    body: 'Add line items, tax, and discounts on the go — invoice numbers '
        'and totals are handled for you.',
  ),
  _Slide(
    icon: Icons.people_alt_rounded,
    title: 'Keep clients & catalog organized',
    body: 'Save clients and products once, then reuse them on every '
        'invoice with a couple of taps.',
  ),
  _Slide(
    icon: Icons.insights_rounded,
    title: 'See revenue at a glance',
    body: 'Track what\'s paid, pending, and overdue with reports that '
        'update as you send invoices.',
  ),
  _Slide(
    icon: Icons.print_rounded,
    title: 'Print or share instantly',
    body: 'Export polished PDFs, share them anywhere, or print straight '
        'to a Bluetooth, USB, or WiFi receipt printer.',
  ),
  _Slide(
    icon: Icons.card_giftcard_rounded,
    title: 'Your first 10 invoices are free',
    body: 'No credit card needed to get started. Upgrade any time you '
        'need more.',
  ),
];

/// First-launch walkthrough — shown once per install, before login, via
/// the redirect gate in app.dart driven by [IntroService.hasSeenIntro].
class IntroView extends StatefulWidget {
  const IntroView({super.key});

  @override
  State<IntroView> createState() => _IntroViewState();
}

class _IntroViewState extends State<IntroView> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await IntroService.markSeen();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 20, 0),
                child: TextButton(
                  onPressed: isLast ? null : _finish,
                  child: Text(
                    isLast ? '' : 'Skip',
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.primary
                        : AppColors.border(context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(isLast ? 'Get started' : 'Next',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(slide.icon, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 40),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.3)),
          const SizedBox(height: 12),
          Text(slide.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 15,
                  height: 1.5)),
        ],
      ),
    );
  }
}
