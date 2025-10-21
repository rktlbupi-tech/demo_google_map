import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/location_service.dart';
import '../services/map_style_service.dart';
import '../widgets/custom_fab.dart';
import '../widgets/distance_info.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _currentPosition;
  LatLng? _targetPoint;
  double? _calculatedDistance;
  MapType _currentMapType = MapType.normal;
  final Set<Marker> _markers = {};
  String _mapStyle = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _listenLocation();
  }

  void _listenLocation() {
    LocationService.locationStream().listen((pos) {
      _updateCurrentLocation(pos);
    });
  }

  // Reverse geocoding and show a dialog
  Future<void> _showAddressPopup(LatLng position) async {
    String address = '${position.latitude}, ${position.longitude}'; // fallback
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [
          p.name,
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }
    } catch (e) {
      // fallback to coordinates
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Address'),
        content: Text(address),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCurrentLocation() async {
    LatLng? pos = await LocationService.getCurrentLocation();
    if (pos != null) _updateCurrentLocation(pos);
  }

  void _updateCurrentLocation(LatLng pos) {
    setState(() {
      _currentPosition = pos;
      _markers.removeWhere((m) => m.markerId.value == 'current_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: pos,
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      _calculateDistance();
    });
  }

  void _calculateDistance() {
    if (_currentPosition != null && _targetPoint != null) {
      setState(() {
        _calculatedDistance = LocationService.calculateDistance(
          _currentPosition!,
          _targetPoint!,
        );
      });
    }
  }

  void _cycleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : _currentMapType == MapType.satellite
          ? MapType.hybrid
          : _currentMapType == MapType.hybrid
          ? MapType.terrain
          : MapType.normal;
    });
  }

  Future<void> _applyMapStyle({
    String? water,
    String? park,
    String? road,
  }) async {
    _mapStyle = MapStyleService.getStyle(water: water, park: park, road: road);
    final controller = await _controller.future;
    controller.setMapStyle(_mapStyle);
  }

  Future<void> _addMarkerAtTap(LatLng position) async {
    String address = '${position.latitude}, ${position.longitude}'; // fallback

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [
          p.name,
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }
    } catch (e) {
      // fallback to coordinates if geocoding fails
    }

    final marker = Marker(
      markerId: MarkerId(position.toString()),
      position: position,
      infoWindow: InfoWindow(title: address),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );

    setState(() {
      // remove previous tap marker if needed
      _markers.removeWhere((m) => m.markerId.value != 'current_location');
      _markers.add(marker);
      _targetPoint = position; // update distance calculation
      _calculateDistance();
    });
  }

  // Function to pick a color using the color picker dialog
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
                  onTap: (pos) async {
                    await _addMarkerAtTap(pos); // Add marker + show address
                  },
                  // onTap: (LatLng pos) async {
                  //   await _showAddressPopup(pos);
                  // },
                ),
          if (_calculatedDistance != null)
            DistanceInfo(distance: _calculatedDistance!),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CustomFAB(
            icon: Icons.add,
            onPressed: () async {
              final controller = await _controller.future;
              controller.animateCamera(CameraUpdate.zoomIn());
            },
          ),
          const SizedBox(height: 10),
          CustomFAB(
            icon: Icons.remove,
            onPressed: () async {
              final controller = await _controller.future;
              controller.animateCamera(CameraUpdate.zoomOut());
            },
          ),
          const SizedBox(height: 10),
          CustomFAB(
            icon: Icons.my_location,
            onPressed: () async {
              await _loadCurrentLocation();
              if (_currentPosition != null) {
                setState(() {
                  _targetPoint = _currentPosition;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          CustomFAB(icon: Icons.map, onPressed: _cycleMapType),
          const SizedBox(height: 10),
          // Color pickers
          CustomFAB(
            icon: Icons.water_drop,
            onPressed: () async {
              Color? color = await _pickColor(Colors.blue);
              if (color != null) {
                _applyMapStyle(
                  water: '#${color.value.toRadixString(16).substring(2)}',
                );
              }
            },
          ),
          const SizedBox(height: 10),
          CustomFAB(
            icon: Icons.park,
            onPressed: () async {
              Color? color = await _pickColor(Colors.green);
              if (color != null) {
                _applyMapStyle(
                  park: '#${color.value.toRadixString(16).substring(2)}',
                );
              }
            },
          ),
          const SizedBox(height: 10),
          CustomFAB(
            icon: Icons.route,
            onPressed: () async {
              Color? color = await _pickColor(Colors.orange);
              if (color != null) {
                _applyMapStyle(
                  road: '#${color.value.toRadixString(16).substring(2)}',
                );
              }
            },
          ),
          const SizedBox(height: 10),
          CustomFAB(
            icon: Icons.clear,
            onPressed: () {
              setState(() {
                _targetPoint = null;
                _calculatedDistance = null;
              });
            },
          ),
        ],
      ),
    );
  }
}
