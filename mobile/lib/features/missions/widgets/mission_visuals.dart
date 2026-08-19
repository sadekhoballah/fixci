import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/location/reverse_geocoding_service.dart';
import '../../../core/models/service_category.dart';
import '../../../core/network/api_client.dart';

// A mission's first photo, or a gradient-and-icon placeholder when it has
// none — the "default image" every mission card/detail needs. No actual
// placeholder bitmap asset: a drawn gradient + the mission's own category
// icon looks intentional at any size and needs no image file to ship.
// FutureBuilder re-issues the fetch on every rebuild (mirrors
// mission_detail_screen.dart's existing _MissionPhoto) — harmless here
// since ApiClient/browser-level caching aside, this is a short-lived list
// tile, not a hot rebuild loop.
class MissionPhotoOrPlaceholder extends ConsumerWidget {
  const MissionPhotoOrPlaceholder({
    super.key,
    required this.storageKey,
    required this.category,
    this.borderRadius,
  });

  final String? storageKey;
  final ServiceCategory? category;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final key = storageKey;
    if (key == null) {
      return ClipRRect(
        borderRadius: radius,
        child: _Placeholder(category: category),
      );
    }
    // The endpoint takes a bare filename, not the "mission-photos/…" prefix
    // stored on the entity — see uploads.controller.ts's getMissionPhoto.
    final filename = key.split('/').last;
    return ClipRRect(
      borderRadius: radius,
      child: FutureBuilder<Uint8List>(
        future: ref
            .read(apiClientProvider)
            .getBytes('/uploads/mission-photo/$filename'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _Placeholder(category: category, loading: true);
          }
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.category, this.loading = false});

  final ServiceCategory? category;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primary.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            : Icon(
                category?.icon ?? Icons.handyman_rounded,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
      ),
    );
  }
}

// A mission's location line: shows the raw stored address immediately, then
// swaps in a reverse-geocoded human address (e.g. "Zone industrielle,
// Koumassi") once the phone's native geocoder resolves the GPS point — see
// ReverseGeocodingService. Silent, permanent fallback to the raw address on
// any failure (offline, no geocoder backend, timeout): never a spinner,
// never an error text, since the raw address is already a perfectly usable
// address on its own.
class MissionResolvedAddress extends ConsumerWidget {
  const MissionResolvedAddress({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.fallback,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final double latitude;
  final double longitude;
  final String fallback;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref
          .read(reverseGeocodingServiceProvider)
          .lookup(latitude, longitude),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? fallback,
          style: style,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
