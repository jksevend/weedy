import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:weedy/actions/provider.dart';
import 'package:weedy/plants/model.dart';
import 'package:weedy/plants/provider.dart';
import 'package:weedy/plants/transition/provider.dart';

/// Shows a dialog that asks the user to confirm the deletion of a plant.
Future<bool> confirmDeletionOfPlantDialog(
  BuildContext context,
  Plant plant,
  PlantsProvider plantsProvider,
  ActionsProvider actionsProvider,
  PlantLifecycleTransitionProvider transitionProvider,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(tr('plants.dialog.delete_title')),
        content: Text(tr('plants.dialog.delete_message')),
        actions: [
          TextButton(
            onPressed: () => _onClose(context, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () async => _onPlantDeleted(
                context, plantsProvider, actionsProvider, plant, transitionProvider),
            child: Text(tr('common.delete')),
          ),
        ],
      );
    },
  );
  return confirmed!;
}

/// Close the dialog and return a value.
void _onClose<T>(BuildContext context, T value) {
  Navigator.of(context).pop(value);
}

/// Deletes the [plant] and all actions associated with it.
Future<void> _onPlantDeleted(
  BuildContext context,
  PlantsProvider plantsProvider,
  ActionsProvider actionsProvider,
  Plant plant,
  PlantLifecycleTransitionProvider transitionProvider,
) async {
  await plantsProvider.removePlant(plant);
  await actionsProvider.removeActionsForPlant(plant.id);
  await transitionProvider.removeTransitionsForPlant(plant.id);
  final bannerImage = File(plant.bannerImagePath);
  if (await bannerImage.exists()) {
    await bannerImage.delete();
  }

  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pop(true);
}
