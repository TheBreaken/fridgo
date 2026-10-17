import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fridgo/domain/product_photo.dart';
import 'package:fridgo/l10n/app_localizations.dart';
import 'package:fridgo/ui/core/app_theme.dart';
import 'package:fridgo/ui/core/emoji.dart';

sealed class PhotoAction {
  const new();
}

class PickPhoto extends PhotoAction {
  const new(this.source);

  final PhotoSource source;
}

class RemovePhoto extends PhotoAction {
  const new();
}

Future<PhotoAction?> showPhotoActionSheet(
  BuildContext context, {
  required bool hasPhoto,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<PhotoAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: Text(l10n.productPhotoTake),
            onTap: () =>
                Navigator.of(context).pop(const PickPhoto(PhotoSource.camera)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(l10n.productPhotoChoose),
            onTap: () =>
                Navigator.of(context).pop(const PickPhoto(PhotoSource.gallery)),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: Text(l10n.productPhotoRemove),
              onTap: () => Navigator.of(context).pop(const RemovePhoto()),
            ),
        ],
      ),
    ),
  );
}

class ProductPhotoField extends StatelessWidget {
  const new({required this.photoPath, required this.onTap, super.key});

  final String? photoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final photoPath = this.photoPath;
    return Semantics(
      button: true,
      label: photoPath == null ? l10n.productPhotoAdd : l10n.productPhotoChange,
      excludeSemantics: true,
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(Corners.large),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: Sizes.photo,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: Durations.medium2,
                child: photoPath == null
                    ? const _NoPhoto()
                    : _Photo(key: ValueKey(photoPath), path: photoPath),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: Spacing.s,
      children: [
        SvgPicture.asset(
          Emoji.camera,
          width: Sizes.icon,
          height: Sizes.icon,
          excludeFromSemantics: true,
        ),
        Text(
          AppLocalizations.of(context).productPhotoAdd,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const new({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _NoPhoto(),
        ),
        Positioned(
          right: Spacing.s,
          bottom: Spacing.s,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.s),
              child: Icon(
                Icons.edit_rounded,
                size: Sizes.inlineIcon,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
