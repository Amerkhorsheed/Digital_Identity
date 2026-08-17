import 'package:flutter/material.dart';

import '../../../shared/widgets/adaptive_layout.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/brand_widgets.dart';

/// Scrollable, responsive wrapper shared by every registration step.
class StepLayout extends StatelessWidget {
  const StepLayout({super.key, required this.hero, required this.children});

  final Widget hero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);

    final padding = EdgeInsets.fromLTRB(
      band.gutter,
      band.isCompact ? 22 : 28,
      band.gutter,
      40,
    );

    return Scrollbar(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            primary: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: ConstrainedBox(
              // Short forms sit centred on tall tablet and TV screens instead
              // of clinging to the top with a sea of empty space below.
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - padding.vertical,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: band.contentWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Entrance(child: hero),
                      SizedBox(height: band.isCompact ? 20 : 26),
                      Entrance(
                        delay: const Duration(milliseconds: 90),
                        child: SectionCard(
                          child: EntranceList(children: children),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
