import 'package:flutter/material.dart';

class CustomFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const CustomFAB({super.key, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
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
