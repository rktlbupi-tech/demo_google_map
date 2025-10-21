import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/location_service.dart';
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

  LatLng? _firstPoint;
  LatLng? _secondPoint;

  double? _calculatedDistance;
  MapType _currentMapType = MapType.normal;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Color _routeColor = Colors.blue;

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
    });
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

  Future<Map<String, dynamic>?> getRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _updateRoute() async {
    if (_firstPoint != null && _secondPoint != null) {
      final routeData = await getRoute(_firstPoint!, _secondPoint!);
      if (routeData != null && routeData['routes'].isNotEmpty) {
        final points = decodePolyline(
          routeData['routes'][0]['overview_polyline']['points'],
        );
        final distanceMeters =
            routeData['routes'][0]['legs'][0]['distance']['value'];
        setState(() {
          _calculatedDistance = distanceMeters / 1000;
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: _routeColor,
              width: 5,
            ),
          );
        });
      }
    }
  }

  void _handleTap(LatLng position) {
    if (_firstPoint == null || (_firstPoint != null && _secondPoint != null)) {
      _firstPoint = position;
      _secondPoint = null;
      _calculatedDistance = null;
      _polylines.clear();
      _markers.removeWhere(
        (m) =>
            m.markerId.value == 'first_point' ||
            m.markerId.value == 'second_point',
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('first_point'),
          position: _firstPoint!,
          infoWindow: const InfoWindow(title: 'Point 1'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          draggable: true,
          onDragEnd: (newPos) {
            _firstPoint = newPos;
            _updateRoute();
          },
        ),
      );
    } else if (_firstPoint != null && _secondPoint == null) {
      _secondPoint = position;

      _markers.add(
        Marker(
          markerId: const MarkerId('second_point'),
          position: _secondPoint!,
          infoWindow: const InfoWindow(title: 'Point 2'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          draggable: true,
          onDragEnd: (newPos) {
            _secondPoint = newPos;
            _updateRoute();
          },
        ),
      );

      _updateRoute();
    }

    setState(() {});
  }

  Future<void> _pickRouteColor() async {
    Color selectedColor = _routeColor;
    Color? picked = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick route color'),
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

    if (picked != null) {
      setState(() {
        _routeColor = picked;
        if (_polylines.isNotEmpty) {
          final polyline = _polylines.first;
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: polyline.polylineId,
              points: polyline.points,
              color: _routeColor,
              width: 5,
            ),
          );
        }
      });
    }
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
                  polylines: _polylines,
                  onMapCreated: (controller) =>
                      _controller.complete(controller),
                  myLocationEnabled: true,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  onTap: _handleTap,
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
            },
          ),
          const SizedBox(height: 10),
          CustomFAB(icon: Icons.map, onPressed: _cycleMapType),
          const SizedBox(height: 10),
          CustomFAB(icon: Icons.color_lens, onPressed: _pickRouteColor),
          const SizedBox(height: 10),
          CustomFAB(
            icon: Icons.clear,
            onPressed: () {
              setState(() {
                _firstPoint = null;
                _secondPoint = null;
                _calculatedDistance = null;
                _polylines.clear();
                _markers.removeWhere(
                  (m) =>
                      m.markerId.value == 'first_point' ||
                      m.markerId.value == 'second_point',
                );
              });
            },
          ),
        ],
      ),
    );
  }
}
