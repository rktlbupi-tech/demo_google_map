import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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

  // Distance calculation
  LatLng? _targetPoint;
  double? _calculatedDistance;

  // Map style JSON
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
  void _updateLocation(LatLng position) {
    setState(() {
      _currentPosition = position;
      _markers.removeWhere((m) => m.markerId.value == 'current_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: position,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      _calculateDistance(); // Update distance if target is set
    });
  }

  void _calculateDistance() {
    if (_currentPosition != null && _targetPoint != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _targetPoint!.latitude,
        _targetPoint!.longitude,
      );
      setState(() {
        _calculatedDistance = distance;
      });
    }
  }

  /// Reverse geocoding with fallback
  Future<String> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String address = [
          p.name,
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        return address.isNotEmpty
            ? address
            : '${position.latitude}, ${position.longitude}';
      }
    } catch (e) {
      return '${position.latitude}, ${position.longitude}';
    }
    return '${position.latitude}, ${position.longitude}';
  }

  /// Map style customization
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

    _mapStyle = styles.isEmpty ? '' : jsonEncode(styles);
    final controller = await _controller.future;
    controller.setMapStyle(_mapStyle);
  }

  Future<Color?> _pickColor(Color currentColor) async {
    Color selectedColor = currentColor;
    return showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (color) => selectedColor = color,
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(selectedColor),
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

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
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                ),
          // Show distance
          if (_calculatedDistance != null)
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: Text(
                  'Distance: ${(_calculatedDistance! / 1000).toStringAsFixed(2)} km',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          // Floating Buttons for map style
          Positioned(
            bottom: 50,
            left: 20,
            child: Column(
              children: [
                _floatingButton(Icons.water_drop, () async {
                  Color? color = await _pickColor(Colors.blue);
                  if (color != null) {
                    _applyMapStyle(
                      waterColor:
                          '#${color.value.toRadixString(16).substring(2)}',
                    );
                  }
                }),
                _floatingButton(Icons.park, () async {
                  Color? color = await _pickColor(Colors.green);
                  if (color != null) {
                    _applyMapStyle(
                      parkColor:
                          '#${color.value.toRadixString(16).substring(2)}',
                    );
                  }
                }),
                _floatingButton(Icons.route, () async {
                  Color? color = await _pickColor(Colors.orange);
                  if (color != null) {
                    _applyMapStyle(
                      roadColor:
                          '#${color.value.toRadixString(16).substring(2)}',
                    );
                  }
                }),
              ],
            ),
          ),
        ],
      ),
      // Zoom, location, cycle map type, and distance reset buttons
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
          _floatingButton(Icons.my_location, () async {
            await _determinePosition();
            // Set target point on current location click
            if (_currentPosition != null) {
              setState(() {
                _targetPoint = _currentPosition;
              });
            }
          }),
          const SizedBox(height: 10),
          _floatingButton(Icons.map, _cycleMapType),
          const SizedBox(height: 10),
          _floatingButton(Icons.clear, () {
            setState(() {
              _targetPoint = null;
              _calculatedDistance = null;
            });
          }),
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
