import 'dart:convert';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distanceMetres,
    required this.maneuver,
    required this.endLat,
    required this.endLng,
  });

  final String instruction;
  final double distanceMetres;
  final String maneuver;
  final double endLat;
  final double endLng;
}

class OutdoorRoute {
  const OutdoorRoute({
    required this.destination,
    required this.steps,
    required this.totalMetres,
    required this.polylineHint,
  });

  final String destination;
  final List<RouteStep> steps;
  final double totalMetres;
  final String polylineHint;
}

/// Geoapify geocoding + walking routing. Needs GEOAPIFY_API_KEY in .env.
class OutdoorDirectionsService {
  OutdoorDirectionsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static bool get isConfigured {
    final key = AppConfig.geoapifyApiKey;
    return key.isNotEmpty && !key.contains('YOUR_');
  }

  Future<OutdoorRoute> planWalkingRoute({
    required String destinationQuery,
    Position? origin,
    bool hindi = false,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Add GEOAPIFY_API_KEY to flutter/.env for outdoor navigation.',
      );
    }
    final start = origin ?? await _currentPosition();
    final dest = await _geocode(
      destinationQuery,
      biasLat: start.latitude,
      biasLng: start.longitude,
    );
    final lang = hindi ? 'hi' : 'en';
    final waypoints =
        '${start.latitude},${start.longitude}|${dest.$1},${dest.$2}';
    final url = Uri.https('api.geoapify.com', '/v1/routing', {
      'waypoints': waypoints,
      'mode': 'walk',
      'units': 'metric',
      'lang': lang,
      'details': 'instruction_details',
      'apiKey': AppConfig.geoapifyApiKey,
    });
    final res = await _client.get(url).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw StateError('Directions failed (${res.statusCode}).');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['statusCode'] is num && (data['statusCode'] as num) >= 400) {
      throw StateError(
        'Directions: ${data['message'] ?? data['statusCode']}',
      );
    }
    final features = data['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) {
      throw StateError('No walking route found.');
    }
    final feature = features.first as Map<String, dynamic>;
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final legs = props['legs'] as List<dynamic>? ?? const [];
    if (legs.isEmpty) {
      throw StateError('No route legs.');
    }
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final multi = geometry?['coordinates'] as List<dynamic>? ?? const [];

    final steps = <RouteStep>[];
    for (var legIndex = 0; legIndex < legs.length; legIndex++) {
      final leg = legs[legIndex] as Map<String, dynamic>;
      final stepsRaw = leg['steps'] as List<dynamic>? ?? const [];
      final line = legIndex < multi.length
          ? (multi[legIndex] as List<dynamic>? ?? const [])
          : const <dynamic>[];
      for (final raw in stepsRaw) {
        final s = raw as Map<String, dynamic>;
        final instruction = s['instruction'];
        String text = '';
        String maneuver = '';
        if (instruction is Map) {
          text = (instruction['text'] as String?) ?? '';
          maneuver = (instruction['type'] as String?) ?? '';
        }
        final dist = (s['distance'] as num?)?.toDouble() ?? 0;
        final end = _stepEnd(s, line);
        if (text.trim().isEmpty && maneuver.isEmpty && dist < 5) {
          continue;
        }
        steps.add(
          RouteStep(
            instruction: text.trim(),
            distanceMetres: dist,
            maneuver: maneuver,
            endLat: end.$1,
            endLng: end.$2,
          ),
        );
      }
    }
    if (steps.isEmpty) {
      throw StateError('Route had no turn instructions.');
    }
    final total = (props['distance'] as num?)?.toDouble() ??
        steps.fold<double>(0, (a, b) => a + b.distanceMetres);
    return OutdoorRoute(
      destination: destinationQuery,
      steps: steps,
      totalMetres: total,
      polylineHint: destinationQuery,
    );
  }

  (double, double) _stepEnd(Map<String, dynamic> step, List<dynamic> line) {
    final toIndex = step['to_index'];
    if (toIndex is num && line.isNotEmpty) {
      final i = toIndex.toInt().clamp(0, line.length - 1);
      final pt = line[i];
      if (pt is List && pt.length >= 2) {
        return ((pt[1] as num).toDouble(), (pt[0] as num).toDouble());
      }
    }
    if (line.isNotEmpty) {
      final pt = line.last;
      if (pt is List && pt.length >= 2) {
        return ((pt[1] as num).toDouble(), (pt[0] as num).toDouble());
      }
    }
    return (0, 0);
  }

  String speakStep(RouteStep step, {required bool hindi}) {
    final dist = _distancePhrase(step.distanceMetres, hindi: hindi);
    final turn = _maneuverPhrase(step.maneuver, step.instruction, hindi: hindi);
    if (hindi) {
      return dist.isEmpty ? turn : '$dist में, $turn';
    }
    return dist.isEmpty ? turn : 'In $dist, $turn';
  }

  String _maneuverPhrase(
    String maneuver,
    String fallback, {
    required bool hindi,
  }) {
    final m = maneuver.toLowerCase();
    if (m.contains('right') && !m.contains('left')) {
      return hindi
          ? 'दाएँ मुड़ें. सावधान, किनारा देखें.'
          : 'turn right. Watch for curbs.';
    }
    if (m.contains('left')) {
      return hindi
          ? 'बाएँ मुड़ें. सावधान, किनारा देखें.'
          : 'turn left. Watch for curbs.';
    }
    if (m.contains('roundabout')) {
      return hindi ? 'गोल चक्कर लें.' : 'enter the roundabout.';
    }
    if (m.contains('turnaround') || m.contains('uturn')) {
      return hindi ? 'यू-टर्न लें.' : 'make a U-turn.';
    }
    if (m.contains('destination')) {
      return hindi ? 'गंतव्य पास है.' : 'you are near the destination.';
    }
    final clean = fallback.trim();
    if (clean.isNotEmpty) {
      return clean.endsWith('.') ? clean : '$clean.';
    }
    return hindi ? 'सीधे चलते रहें.' : 'continue straight.';
  }

  String _distancePhrase(double metres, {required bool hindi}) {
    if (metres >= 1000) {
      final km = (metres / 1000).toStringAsFixed(1);
      return hindi ? '$km किलोमीटर' : '$km kilometres';
    }
    final m = metres.round();
    if (m < 15) {
      return '';
    }
    return hindi ? '$m मीटर' : '$m metres';
  }

  Future<(double, double)> _geocode(
    String query, {
    required double biasLat,
    required double biasLng,
  }) async {
    final url = Uri.https('api.geoapify.com', '/v1/geocode/search', {
      'text': query,
      'format': 'json',
      'limit': '1',
      'bias': 'proximity:$biasLng,$biasLat',
      'apiKey': AppConfig.geoapifyApiKey,
    });
    final res = await _client.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw StateError('Could not find "$query" on the map.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? const [];
    if (results.isEmpty) {
      throw StateError('Could not find "$query" on the map.');
    }
    final first = results.first as Map<String, dynamic>;
    final lat = (first['lat'] as num?)?.toDouble();
    final lon = (first['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) {
      throw StateError('Could not find "$query" on the map.');
    }
    return (lat, lon);
  }

  Future<Position> _currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Turn on location services.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is required for outdoor navigation.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  static double metresBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  static double bearingDegrees(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dLambda = (lng2 - lng1) * math.pi / 180;
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
