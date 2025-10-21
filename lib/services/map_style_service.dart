import 'dart:convert';

class MapStyleService {
  static String getStyle({String? water, String? road, String? park}) {
    List<Map<String, dynamic>> styles = [];
    if (water != null) {
      styles.add({
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {"color": water},
        ],
      });
    }
    if (road != null) {
      styles.add({
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {"color": road},
        ],
      });
    }
    if (park != null) {
      styles.add({
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {"color": park},
        ],
      });
    }
    return styles.isEmpty ? '' : jsonEncode(styles);
  }
}
