import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Screen-size bands used across the app so the same experience works on
/// phones, tablets, desktops and TV screens.
enum ScreenBand {
  /// < 600 logical px — phones (and phones in landscape stay compact by height).
  compact,

  /// 600–1024 — tablets, foldables, small windows.
  medium,

  /// 1024–1600 — large tablets, desktop windows.
  expanded,

  /// >= 1600 — TV and very large displays, viewed from a distance.
  television,
}

extension ScreenBandInfo on ScreenBand {
  bool get isCompact => this == ScreenBand.compact;
  bool get isMedium => this == ScreenBand.medium;
  bool get isExpanded => this == ScreenBand.expanded;
  bool get isTelevision => this == ScreenBand.television;

  /// True for tablet-and-above layouts.
  bool get isWide => this != ScreenBand.compact;

  /// Fields per form row inside a step.
  int get formColumns => switch (this) {
        ScreenBand.compact => 1,
        ScreenBand.medium => 2,
        ScreenBand.expanded => 2,
        ScreenBand.television => 2,
      };

  /// Multiplier applied to type and control sizes. TVs are viewed from a
  /// distance, so everything grows; phones stay at the design baseline.
  double get scale => switch (this) {
        ScreenBand.compact => 1.0,
        ScreenBand.medium => 1.06,
        ScreenBand.expanded => 1.12,
        ScreenBand.television => 1.32,
      };

  /// Horizontal page gutter.
  double get gutter => switch (this) {
        ScreenBand.compact => 20,
        ScreenBand.medium => 32,
        ScreenBand.expanded => 40,
        ScreenBand.television => 64,
      };

  /// Maximum readable content width for forms and panels.
  double get contentWidth => switch (this) {
        ScreenBand.compact => double.infinity,
        ScreenBand.medium => 760,
        ScreenBand.expanded => 920,
        ScreenBand.television => 1180,
      };

  /// Maximum width of the persistent header rail.
  double get headerWidth => switch (this) {
        ScreenBand.compact => double.infinity,
        ScreenBand.medium => 900,
        ScreenBand.expanded => 1160,
        ScreenBand.television => 1480,
      };
}

/// Helper for reading the current [ScreenBand] in a build context.
abstract final class Adaptive {
  static ScreenBand bandOf(BuildContext context) =>
      bandForWidth(MediaQuery.sizeOf(context).width);

  static ScreenBand bandForWidth(double width) {
    if (width < 600) return ScreenBand.compact;
    if (width < 1024) return ScreenBand.medium;
    if (width < 1600) return ScreenBand.expanded;
    return ScreenBand.television;
  }

  /// True when vertical space is tight (phone landscape, split view, or a
  /// phone with the keyboard open) and chrome should shrink.
  static bool isShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 620;

  /// Scales [value] for the current band, clamped so it never runs away.
  static double scaled(BuildContext context, double value, {double? max}) {
    final scaled = value * bandOf(context).scale;
    return max == null ? scaled : math.min(scaled, max);
  }
}

/// Wraps content with a centered, device-aware column width.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? band.headerWidth),
        child: Padding(
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: band.gutter),
          child: child,
        ),
      ),
    );
  }
}

/// Responsive form grid: one column on phones, two from tablet up. Rows keep
/// their fields top-aligned so a field that grows (error text, extra input)
/// never drags its neighbour out of place.
class FormGrid extends StatelessWidget {
  const FormGrid({super.key, required this.children, this.spacing = 16});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final band = Adaptive.bandOf(context);
    final columns = band.formColumns;
    final gap = spacing * (band.isTelevision ? 1.4 : 1.0);

    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) SizedBox(height: gap),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    var pending = <Widget>[];

    void flush() {
      if (pending.isEmpty) return;
      final row = pending;
      pending = <Widget>[];
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < columns; j++) ...[
              // Pad the last row with empty cells so a lone field keeps its
              // column width instead of stretching across the grid.
              Expanded(child: j < row.length ? row[j] : const SizedBox()),
              if (j != columns - 1) SizedBox(width: gap),
            ],
          ],
        ),
      );
    }

    for (final child in children) {
      // A span always claims its own full-width row.
      if (child is FormGridSpan) {
        flush();
        rows.add(child);
        continue;
      }
      pending.add(child);
      if (pending.length == columns) flush();
    }
    flush();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1) SizedBox(height: gap),
        ],
      ],
    );
  }
}

/// A widget that spans the full width of a [FormGrid] row.
class FormGridSpan extends StatelessWidget {
  const FormGridSpan({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
