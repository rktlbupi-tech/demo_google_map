import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // <-- For reverse geocoding
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GoogleMapScreen(),
    );
  }
}

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  MapType _currentMapType = MapType.normal;
  final Set<Marker> _markers = {};
  Marker? _selectedMarker;

  // Map style JSON templates
  String _mapStyle = '';

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _listenLocationUpdates();
  }

  /// Get current location
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    _updateLocation(LatLng(position.latitude, position.longitude));
  }

  /// Listen location changes
  void _listenLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _updateLocation(LatLng(position.latitude, position.longitude));
    });
  }

  /// Update marker & camera
  // Only update markers if distance > threshold
  void _updateLocation(LatLng position) {
    if (_currentPosition == null ||
        _distance(_currentPosition!, position) > 10) {
      setState(() {
        _currentPosition = position;
        _markers.removeWhere((m) => m.markerId.value == 'current_location');
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: position,
            infoWindow: const InfoWindow(title: 'You are here'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      });
    }
  }

  double _distance(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Add marker on tap
  void _addMarker(LatLng position) async {
    String address = await _getAddress(position);
    late final Marker marker;
    marker = Marker(
      markerId: MarkerId(position.toString()),
      position: position,
      infoWindow: InfoWindow(title: address),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      onTap: () {
        setState(() {
          _selectedMarker = marker;
        });
      },
    );
    setState(() {
      _markers.add(marker);
    });
  }

  /// Reverse geocoding
  Future<String> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return "${p.name}, ${p.locality}, ${p.administrativeArea}, ${p.country}";
      }
    } catch (e) {
      return "Unknown location";
    }
    return "Unknown location";
  }

  /// Apply map style with dynamic color

  Future<void> _applyMapStyle({
    String? waterColor,
    String? roadColor,
    String? parkColor,
  }) async {
    List<Map<String, dynamic>> styles = [];

    if (waterColor != null) {
      styles.add({
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {"color": waterColor},
        ],
      });
    }

    if (roadColor != null) {
      styles.add({
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {"color": roadColor},
        ],
      });
    }

    if (parkColor != null) {
      styles.add({
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {"color": parkColor},
        ],
      });
    }

    _mapStyle = styles.isEmpty
        ? ''
        : jsonEncode(styles); // <- IMPORTANT: use jsonEncode
    final controller = await _controller.future;
    controller.setMapStyle(_mapStyle);
  }

  /// Cycle map type
  void _cycleMapType() {
    setState(() {
      if (_currentMapType == MapType.normal) {
        _currentMapType = MapType.satellite;
      } else if (_currentMapType == MapType.satellite) {
        _currentMapType = MapType.hybrid;
      } else if (_currentMapType == MapType.hybrid) {
        _currentMapType = MapType.terrain;
      } else {
        _currentMapType = MapType.normal;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  mapType: _currentMapType,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 15,
                  ),
                  markers: _markers,
                  onMapCreated: (controller) =>
                      _controller.complete(controller),
                  myLocationEnabled: true,
                  onTap: _addMarker,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                ),
          // Floating Buttons
          Positioned(
            top: 50,
            left: 20,
            child: Column(
              children: [
                _floatingButton(Icons.layers, _cycleMapType),
                const SizedBox(height: 10),
                _floatingButton(
                  Icons.water_drop,
                  () => _applyMapStyle(waterColor: "#4da6ff"),
                ),
                const SizedBox(height: 10),
                _floatingButton(
                  Icons.park,
                  () => _applyMapStyle(parkColor: "#00cc66"),
                ),
                const SizedBox(height: 10),
                _floatingButton(
                  Icons.abc,
                  () => _applyMapStyle(roadColor: "#ff9900"),
                ),
              ],
            ),
          ),
          // Draggable bottom sheet
          if (_selectedMarker != null)
            DraggableScrollableSheet(
              initialChildSize: 0.2,
              minChildSize: 0.1,
              maxChildSize: 0.4,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedMarker!.infoWindow.title ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _selectedMarker = null),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      // Zoom & location buttons
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _floatingButton(Icons.add, () async {
            final controller = await _controller.future;
            controller.animateCamera(CameraUpdate.zoomIn());
          }),
          const SizedBox(height: 10),
          _floatingButton(Icons.remove, () async {
            final controller = await _controller.future;
            controller.animateCamera(CameraUpdate.zoomOut());
          }),
          const SizedBox(height: 10),
          _floatingButton(Icons.my_location, _determinePosition),
        ],
      ),
    );
  }

  FloatingActionButton _floatingButton(IconData icon, VoidCallback onPressed) {
    return FloatingActionButton(
      heroTag: icon.codePoint.toString(),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      mini: true,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
