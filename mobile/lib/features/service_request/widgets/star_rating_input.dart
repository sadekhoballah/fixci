import 'package:flutter/material.dart';

// The only interactive rating control in the app — everywhere else
// (RatingPerformanceCard, craftsman_jobs_screen) only ever displays a
// read-only average. Same gold (0xFFFFC107) as those, for visual continuity.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= value;
        return IconButton(
          onPressed: () => onChanged(starValue),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? const Color(0xFFFFC107) : Colors.grey,
            size: 40,
          ),
        );
      }),
    );
  }
}
