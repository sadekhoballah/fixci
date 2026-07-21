import 'package:flutter/material.dart';

class RadarWaitingWidget extends StatefulWidget {
  const RadarWaitingWidget({super.key});

  @override
  State<RadarWaitingWidget> createState() => _RadarWaitingWidgetState();
}

class _RadarWaitingWidgetState extends State<RadarWaitingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _ringCount = 3;
  static const _maxDiameter = 160.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: _maxDiameter,
          height: _maxDiameter,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < _ringCount; i++)
                    _buildRing(colorScheme.primary, i / _ringCount),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Recherche de clients à proximité...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRing(Color color, double phaseOffset) {
    final progress = (_controller.value + phaseOffset) % 1.0;
    final diameter = _maxDiameter * progress;
    final opacity = 1.0 - progress;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      ),
    );
  }
}
