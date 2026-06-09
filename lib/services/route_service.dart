import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteInfo {
  final List<LatLng> polyline;
  final double distanceKm;
  final int durationMinutes;
  final String distanceText;
  final String durationText;

  RouteInfo({
    required this.polyline,
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceText,
    required this.durationText,
  });
}

class RouteService {
  // TODO: Add your Google API key here or in environment
  // Get it from: https://console.cloud.google.com/apis/credentials
  // Enable: Directions API, Maps SDK for Android/iOS
  static const String _googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE';

  /// Fetches route using Google Directions API (preferred) or OSRM (fallback)
  static Future<RouteInfo?> fetchRoute(LatLng from, LatLng to) async {
    // Try Google Directions API first (if API key is configured)
    if (_googleApiKey.isNotEmpty && _googleApiKey != 'YOUR_GOOGLE_API_KEY_HERE') {
      try {
        return await _fetchGoogleRoute(from, to);
      } catch (e) {
        print('⚠️ Google Directions failed: $e, falling back to OSRM');
      }
    }

    // Fallback to OSRM (free, no API key required)
    return await _fetchOSRMRoute(from, to);
  }

  /// Google Directions API - Premium quality routing
  static Future<RouteInfo?> _fetchGoogleRoute(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${from.latitude},${from.longitude}'
      '&destination=${to.latitude},${to.longitude}'
      '&mode=driving'
      '&key=$_googleApiKey',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Google API returned ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (data['status'] != 'OK') {
      throw Exception('Google API status: ${data['status']}');
    }

    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw Exception('No routes found');
    }

    final route = routes[0] as Map<String, dynamic>;
    final leg = (route['legs'] as List<dynamic>)[0] as Map<String, dynamic>;

    // Extract distance and duration
    final distanceMeters = leg['distance']['value'] as int;
    final durationSeconds = leg['duration']['value'] as int;
    final distanceText = leg['distance']['text'] as String;
    final durationText = leg['duration']['text'] as String;

    // Decode polyline
    final encodedPolyline = route['overview_polyline']['points'] as String;
    final points = _decodeGooglePolyline(encodedPolyline);

    return RouteInfo(
      polyline: points,
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: (durationSeconds / 60).round(),
      distanceText: distanceText,
      durationText: durationText,
    );
  }

  /// OSRM (OpenStreetMap Routing) - Free fallback
  static Future<RouteInfo?> _fetchOSRMRoute(LatLng from, LatLng to) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?geometries=geojson&overview=full',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('OSRM returned ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>;

    if (routes.isEmpty) {
      throw Exception('No routes found');
    }

    final route = routes[0] as Map<String, dynamic>;

    // Extract distance (meters) and duration (seconds)
    final distanceMeters = (route['distance'] as num).toDouble();
    final durationSeconds = (route['duration'] as num).toDouble();

    // Extract geometry coordinates
    final coords = (route['geometry']['coordinates'] as List<dynamic>)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final distanceKm = distanceMeters / 1000.0;
    final durationMinutes = (durationSeconds / 60).round();

    return RouteInfo(
      polyline: coords,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      distanceText: distanceKm < 1
          ? '${(distanceKm * 1000).round()} m'
          : '${distanceKm.toStringAsFixed(1)} km',
      durationText: durationMinutes < 60
          ? '$durationMinutes min'
          : '${(durationMinutes / 60).floor()}h ${durationMinutes % 60}m',
    );
  }

  /// Decode Google's encoded polyline format
  static List<LatLng> _decodeGooglePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}
