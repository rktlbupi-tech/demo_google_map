import 'package:flutter/material.dart';

class DistanceInfo extends StatelessWidget {
  final double distance;
  const DistanceInfo({super.key, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      left: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        color: Colors.white,
        child: Text(
          'Distance: ${(distance / 1000).toStringAsFixed(2)} km',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
