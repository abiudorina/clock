import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const layoutAnimationDuration = Duration(milliseconds: 2471), layoutAnimationCurve = Curves.elasticInOut;

class CompositedClock extends MultiChildRenderObjectWidget {
  final Animation<double> layoutAnimation;

  /// The [children] need to cover each component type in [ClockComponent], which can be specified in the [RenderObject.parentData] using [CompositedClockChildrenParentData].
  /// Every component can only exist exactly once.
  CompositedClock({
    Key key,
    List<Widget> children,
    @required this.layoutAnimation,
  })  : assert(layoutAnimation != null),
        super(key: key, children: children);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCompositedClock(
      layoutAnimation: layoutAnimation,
    );
  }
}

enum ClockComponent {
  analogTime,
  background,
  weather,
//  digitalTime,
//  temperature,
}

class CompositedClockChildrenParentData extends ContainerBoxParentData<RenderBox> {
  ClockComponent component;

  /// Used to mark children that do not set up their [RenderObject.parentData] themselves.
  /// If a child is passed to [CompositedClock] that does not update this to `true`, an error should be thrown.
  bool valid;

  Map<ClockComponent, Rect> _rects;

  Rect rectOf(ClockComponent component) {
    assert(this.component == ClockComponent.background, 'Only the background component can access sizes and offsets of the other children.');
    final rect = _rects[component];
    assert(rect != null, 'No $Rect was provided for $component. If the rect of this child should be accessible from ${this.component}, this needs to be changed in $RenderCompositedClock.');
    return rect;
  }
}

class RenderCompositedClock extends RenderBox with ContainerRenderObjectMixin<RenderBox, CompositedClockChildrenParentData>, RenderBoxContainerDefaultsMixin<RenderBox, CompositedClockChildrenParentData> {
  RenderCompositedClock({this.layoutAnimation});

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);

    layoutAnimation.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    super.detach();

    layoutAnimation.removeListener(markNeedsLayout);
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! CompositedClockChildrenParentData) {
      child.parentData = CompositedClockChildrenParentData()..valid = false;
    }
  }

  Animation<double> layoutAnimation;

  @override
  bool hitTestChildren(BoxHitTestResult result, {Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    final components = List.of(ClockComponent.values);

    CompositedClockChildrenParentData background;

    var child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as CompositedClockChildrenParentData;

      if (!childParentData.valid) throw ClockCompositionError(child: child);
      if (!components.contains(childParentData.component)) {
        throw ClockCompositionError(
            message: 'The children passed to CompositedClock contain the component type ${describeEnum(childParentData.component)} more than once. '
                'Every component can only be passed exactly once.');
      }

      components.remove(childParentData.component);

      if (childParentData.component == ClockComponent.background) {
        background = childParentData;
      }

      child = childParentData.nextSibling;
    }

    if (components.isNotEmpty) {
      throw ClockCompositionError(
          message: 'The children passed to CompositedClock do not cover every component of ${ClockComponent.values}. '
              'You need to pass every component exactly once and specify the component type correctly using CompositedClockChildrenParentData.\n'
              'Missing components are $components.');
    }

    background._rects = {};

    child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as CompositedClockChildrenParentData;

      // The reason this is not true for all is that parentUsesSize does not need to be true.
      var backgroundCanUseRect = false;

      switch (childParentData.component) {
        case ClockComponent.background:
          child.layout(BoxConstraints.tight(constraints.biggest));
          break;
        case ClockComponent.analogTime:
          child.layout(BoxConstraints.tight(Size.fromRadius(constraints.biggest.height / (3 - (1 - 2 * (layoutAnimation.value - 1 / 2).abs()) / 4))), parentUsesSize: backgroundCanUseRect = true);
          childParentData.offset = Offset(size.width / 2 - child.size.width / 2 + (layoutAnimation.value - 1 / 2) * child.size.width * 4 / 3, size.height / 2 - child.size.height / 2);
          break;
        case ClockComponent.weather:
          child.layout(BoxConstraints.tight(Size.fromRadius(constraints.biggest.height / 4)), parentUsesSize: backgroundCanUseRect = true);
          final clearanceFactor = 1 / 19;
          childParentData.offset =
              Offset(Tween(begin: size.width - child.size.width * (1 + clearanceFactor * 3), end: child.size.width * clearanceFactor * 3).transform(layoutAnimation.value), child.size.height * clearanceFactor);
          break;
      }

      if (backgroundCanUseRect) {
        background._rects[childParentData.component] = Rect.fromLTWH(childParentData.offset.dx, childParentData.offset.dy, child.size.width, child.size.height);
      }

      child = childParentData.nextSibling;
    }
    ;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Clip to the given size to not exceed to 5:3 area imposed by the challenge.
    context.pushClipRect(needsCompositing, offset, Rect.fromLTWH(0, 0, size.width, size.height), (context, offset) {
      // Draw components.
      var child = firstChild;
      while (child != null) {
        final childParentData = child.parentData as CompositedClockChildrenParentData;
        context.paintChild(child, childParentData.offset + offset);
        child = childParentData.nextSibling;
      }
    });
  }

  @override
  void debugPaint(PaintingContext context, Offset offset) {
    assert(() {
      if (debugPaintSizeEnabled) {
        final painter = TextPainter(
            text: const TextSpan(
                text: 'Please send me a sign :/ This is leading me nowhere and I do not mean this challenge - creativecreatorormaybenot.',
                style: TextStyle(fontSize: 42, color: Color(0xffff3456), backgroundColor: Color(0xffffffff))),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center);
        painter.layout(maxWidth: size.width);
        painter.paint(context.canvas, Offset(0, size.height / 2));
      }
      return true;
    }());
  }
}

class ClockCompositionError extends Error {
  /// A phrase indicating why the error is being thrown. The message is followed by the [stackTrace].
  /// This will not be used if [child] is supplied.
  final String message;

  /// Indicates that the child does not implement [CompositedClockChildrenParentData] correctly.
  final RenderBox child;

  ClockCompositionError({
    this.child,
    this.message,
  }) : assert(child != null || message != null);

  @override
  String toString() => '${message ?? 'A child was passed to CompositedClock which does not set up its RenderObject.parentData '
      'as CompositedClockChildrenParentData correctly (setting CompositedClockChildrenParentData.valid to `true`).'}\n$stackTrace.';
}

/// Takes care of validating [RenderObject]s passed to [CompositedClock] and assigning a [ClockComponent].
/// It also provides easy access to the [CompositedClockChildrenParentData] of this [RenderObject] via [compositedClockData].
abstract class RenderClockComponent extends RenderBox {
  final ClockComponent component;

  RenderClockComponent(
    this.component,
  ) : assert(component != null);

  CompositedClockChildrenParentData get compositedClockData => parentData as CompositedClockChildrenParentData;

  /// Takes care of validating the RenderObject for when it is passed to [CompositedClock]
  /// and sets [CompositedClockChildrenParentData.component] to the appropriate [ClockComponent].
  /// Thus, this is annotated with [mustCallSuper]. Alternatively, you could ignore this and
  /// implement the validation and setting the component in the sub class, but the whole point of
  /// [RenderClockComponent] is to take care of this step, so you should likely extend [RenderBox] instead.
  @override
  @mustCallSuper
  void attach(PipelineOwner owner) {
    super.attach(owner);

    compositedClockData.valid = true;
    compositedClockData.component = component;
  }
}
