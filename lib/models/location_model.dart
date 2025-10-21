import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationModel {
  LatLng? currentPosition;
  LatLng? targetPosition;
  double? distance;

  LocationModel({this.currentPosition, this.targetPosition, this.distance});
}
