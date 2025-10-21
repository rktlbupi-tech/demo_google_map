import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  static Future<String> getAddress(LatLng position) async {
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
}
