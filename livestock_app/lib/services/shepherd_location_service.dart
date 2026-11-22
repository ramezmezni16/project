
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';

import 'api_service.dart';

class ShepherdLocationService {
  final ApiService apiService;

  StreamSubscription<Position>? _subscription;
  bool _sending = false;

  ShepherdLocationService({required this.apiService});

  bool get isSharing => _subscription != null;

  Future<void> start({
    required void Function(String message) onError,
  }) async {
    if (_subscription != null) return;

    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Please enable location services.');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission was denied.');
    }

    // Get and send the first position immediately.
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _sendPosition(position, onError);
    } catch (e) {
      onError('Could not get or send initial GPS position: $e');
    }

    // Continue listening for location changes.
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) async {
        await _sendPosition(position, onError);
      },
      onError: (error) {
        onError('GPS stream error: $error');
        unawaited(stop());
      },
    );
  }

  Future<void> _sendPosition(
    Position position,
    void Function(String message) onError,
  ) async {
    if (_sending) return;

    _sending = true;

    try {
      await apiService.post(
        '/api/shepherd/location/',
        {
          'lat': position.latitude,
          'lon': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
        },
      );

      debugPrint(
        'SHEPHERD GPS SENT: '
        '${position.latitude}, ${position.longitude}',
    );
    } catch (e) {
      onError('Could not send location to Django: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
