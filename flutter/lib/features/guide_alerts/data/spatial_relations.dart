import '../domain/guide_models.dart';

/// Rough layout: “on the table”, “next to the chair”. From boxes, not magic.
class SpatialRelations {
  SpatialRelations._();

  static const surfaces = {
    'table',
    'desk',
    'chair',
    'couch',
    'bed',
    'bench',
    'counter',
    'shelf',
  };

  static const items = {
    'headphones',
    'phone',
    'bottle',
    'cup',
    'book',
    'laptop',
    'keyboard',
    'mouse',
    'purse',
    'bag',
    'keys',
    'remote',
  };

  static String? phrase(GuideObjectSnapshot item, List<GuideObjectSnapshot> all) {
    final label = item.label.toLowerCase();
    if (!items.contains(label) && item.boundingBox == null) {
      // Label-only detections: still guess if a surface is in the frame.
      final surface = _bestSurface(all);
      if (surface != null && items.contains(label)) {
        return 'on the ${surface.label}';
      }
      return null;
    }
    final box = item.boundingBox;
    if (box == null) {
      final surface = _bestSurface(all);
      if (surface != null && items.contains(label)) {
        return 'on the ${surface.label}';
      }
      return null;
    }

    GuideObjectSnapshot? best;
    var bestScore = 0.0;
    for (final other in all) {
      if (identical(other, item)) {
        continue;
      }
      if (!surfaces.contains(other.label.toLowerCase())) {
        continue;
      }
      final otherBox = other.boundingBox;
      if (otherBox == null) {
        continue;
      }
      final overlapX = _overlap(box.left, box.right, otherBox.left, otherBox.right);
      final itemMidY = (box.top + box.bottom) / 2;
      final surfaceTop = otherBox.top;
      final sitsOn = itemMidY <= surfaceTop + 0.12 && overlapX >= 0.18;
      final score = overlapX + (sitsOn ? 0.5 : 0);
      if (sitsOn && score > bestScore) {
        bestScore = score;
        best = other;
      }
    }
    if (best != null) {
      return 'on the ${best.label}';
    }
    return null;
  }

  static GuideObjectSnapshot? _bestSurface(List<GuideObjectSnapshot> all) {
    GuideObjectSnapshot? best;
    var area = 0.0;
    for (final o in all) {
      if (!surfaces.contains(o.label.toLowerCase())) {
        continue;
      }
      final b = o.boundingBox;
      final a = b == null
          ? o.boxProximity
          : (b.right - b.left) * (b.bottom - b.top);
      if (a >= area) {
        area = a;
        best = o;
      }
    }
    return best;
  }

  static double _overlap(double a0, double a1, double b0, double b1) {
    final left = a0 > b0 ? a0 : b0;
    final right = a1 < b1 ? a1 : b1;
    final w = right - left;
    if (w <= 0) {
      return 0;
    }
    final span = a1 - a0;
    if (span <= 0) {
      return 0;
    }
    return w / span;
  }
}
