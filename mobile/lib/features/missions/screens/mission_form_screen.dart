import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/id_card_picker.dart';
import '../../../core/models/service_category.dart';
import '../../../l10n/app_localizations.dart';
import '../mission_form_controller.dart';
import '../mission_form_state.dart';
import '../mission_timing_format.dart';
import '../missions_models.dart';
import 'mission_detail_screen.dart';

// Create-mission form — calqué sur trade_detail_screen.dart's shape: plain
// TextEditingControllers, no Form/GlobalKey, ad-hoc validity check in
// build(), submit button in bottomNavigationBar. Location is a "use my
// position" GPS capture (see MissionFormController._resolvePosition) plus a
// plain text address field — no map picker anywhere in this app.
class MissionFormScreen extends ConsumerStatefulWidget {
  const MissionFormScreen({super.key});

  @override
  ConsumerState<MissionFormScreen> createState() => _MissionFormScreenState();
}

class _MissionFormScreenState extends ConsumerState<MissionFormScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  ServiceCategory? _category;
  // Non précisé by default — matches the entity's own column default, so a
  // poster who never touches this section gets exactly what the backend
  // would have assumed anyway.
  MissionTimingPreference _timingPreference = MissionTimingPreference.unspecified;
  int _scheduledDayOfWeek = DateTime.monday;
  int _scheduledHour = 8;

  @override
  void initState() {
    super.initState();
    // Rebuilds so the submit button's enabled state tracks every field as
    // the user types.
    for (final controller in [
      _titleController,
      _descriptionController,
      _addressController,
      _priceController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _showPhotoSourceSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(missionFormControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (idCardCameraSupported)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.takePhotoLabel),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.addPhotoFromCamera();
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGalleryLabel),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.addPhotoFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(missionFormControllerProvider, (previous, next) {
      if (next.status == MissionFormStatus.success &&
          next.createdMissionId != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                MissionDetailScreen(missionId: next.createdMissionId!),
          ),
        );
      }
      if (next.status == MissionFormStatus.error &&
          next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });
    final state = ref.watch(missionFormControllerProvider);
    final controller = ref.read(missionFormControllerProvider.notifier);
    final isBusy =
        state.status == MissionFormStatus.locating ||
        state.status == MissionFormStatus.submitting;
    final canSubmit =
        !isBusy &&
        _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.missionFormTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _titleController,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: l10n.missionTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.missionDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ServiceCategory?>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.missionCategoryLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<ServiceCategory?>(
                  value: null,
                  child: Text(l10n.missionCategoryNoneLabel),
                ),
                ...ServiceCategory.values.map(
                  (category) => DropdownMenuItem<ServiceCategory?>(
                    value: category,
                    child: Text(category.localizedLabel(l10n)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l10n.missionAddressLabel,
                hintText: l10n.missionAddressHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.missionLocationHelpMessage,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.missionWhenLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.missionTimingUnspecifiedLabel),
                  selected:
                      _timingPreference == MissionTimingPreference.unspecified,
                  onSelected: (_) => setState(
                    () => _timingPreference =
                        MissionTimingPreference.unspecified,
                  ),
                ),
                ChoiceChip(
                  label: Text(l10n.missionTimingImmediateLabel),
                  selected:
                      _timingPreference == MissionTimingPreference.immediate,
                  onSelected: (_) => setState(
                    () => _timingPreference =
                        MissionTimingPreference.immediate,
                  ),
                ),
                ChoiceChip(
                  label: Text(l10n.missionTimingScheduledLabel),
                  selected:
                      _timingPreference == MissionTimingPreference.scheduled,
                  onSelected: (_) => setState(
                    () => _timingPreference =
                        MissionTimingPreference.scheduled,
                  ),
                ),
              ],
            ),
            if (_timingPreference == MissionTimingPreference.scheduled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _scheduledDayOfWeek,
                      decoration: InputDecoration(
                        labelText: l10n.missionDayOfWeekLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (var day = DateTime.monday;
                            day <= DateTime.sunday;
                            day++)
                          DropdownMenuItem(
                            value: day,
                            child: Text(
                              missionWeekdayLabel(
                                day,
                                Localizations.localeOf(context).languageCode,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _scheduledDayOfWeek =
                            value ?? _scheduledDayOfWeek,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _scheduledHour,
                      decoration: InputDecoration(
                        labelText: l10n.missionScheduledHourLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (var hour = 0; hour < 24; hour++)
                          DropdownMenuItem(
                            value: hour,
                            child: Text(missionHourLabel(hour)),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _scheduledHour = value ?? _scheduledHour,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.missionStartingPriceLabel,
                hintText: l10n.missionStartingPriceHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.missionPhotosLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _PhotoPickerRow(
              photos: state.photos,
              isUploading: state.isUploadingPhoto,
              onAdd: _showPhotoSourceSheet,
              onRemove: controller.removePhoto,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: !canSubmit
                ? null
                : () => controller.submit(
                    title: _titleController.text.trim(),
                    description: _descriptionController.text.trim(),
                    locationAddress: _addressController.text.trim(),
                    category: _category,
                    timingPreference: _timingPreference,
                    scheduledDayOfWeek:
                        _timingPreference == MissionTimingPreference.scheduled
                        ? _scheduledDayOfWeek
                        : null,
                    scheduledHour:
                        _timingPreference == MissionTimingPreference.scheduled
                        ? _scheduledHour
                        : null,
                    startingPrice: double.tryParse(
                      _priceController.text.trim().replaceAll(',', '.'),
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    l10n.publishMissionButton,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerRow extends StatelessWidget {
  const _PhotoPickerRow({
    required this.photos,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<MissionPhotoDraft> photos;
  final bool isUploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canAddMore = photos.length < maxMissionPhotos && !isUploading;

    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      photos[i].bytes,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black54,
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (canAddMore)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onAdd,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isUploading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Icon(
                        Icons.add_a_photo_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
