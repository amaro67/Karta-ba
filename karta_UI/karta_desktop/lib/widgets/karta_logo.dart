import 'package:flutter/material.dart';
import '../config/theme.dart';
class KartaLogo extends StatelessWidget {
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final bool showIcon;
  const KartaLogo({
    super.key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.showIcon = false,
  });
  @override
  Widget build(BuildContext context) {
    final logoColor = color ?? AppTheme.primaryColor;
    final logoFontSize = fontSize ?? 24.0;
    final logoFontWeight = fontWeight ?? FontWeight.bold;
    if (showIcon) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: logoColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.confirmation_number,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'karta.ba',
            style: TextStyle(
              fontSize: logoFontSize,
              fontWeight: logoFontWeight,
              color: logoColor,
            ),
          ),
        ],
      );
    }
    return Text(
      'karta.ba',
      style: TextStyle(
        fontSize: logoFontSize,
        fontWeight: logoFontWeight,
        color: logoColor,
      ),
    );
  }
}