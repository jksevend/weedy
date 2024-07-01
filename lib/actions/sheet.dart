import 'package:flutter/material.dart';
import 'package:weedy/actions/fertilizer/provider.dart';
import 'package:weedy/actions/model.dart';
import 'package:weedy/actions/provider.dart';
import 'package:weedy/actions/widget.dart';
import 'package:weedy/environments/model.dart';
import 'package:weedy/environments/provider.dart';
import 'package:weedy/plants/model.dart';
import 'package:weedy/plants/provider.dart';

/// Show a bottom sheet with the details of the [plantAction].
Future<void> showPlantActionDetailSheet(
  BuildContext context,
  PlantAction plantAction,
  Plant plant,
  ActionsProvider actionsProvider,
  FertilizerProvider fertilizerProvider,
  PlantsProvider plantsProvider,
) async {
  await showModalBottomSheet(
    context: context,
    builder: (context) {
      if (plantAction is PlantWateringAction) {
        return PlantWateringActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction is PlantFertilizingAction) {
        return PlantFertilizingActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          fertilizerProvider: fertilizerProvider,
          plantsProvider: plantsProvider,
        );
      }

      if (plantAction is PlantHarvestingAction) {
        return PlantHarvestingActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction is PlantPruningAction) {
        return PlantPruningActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction is PlantTrainingAction) {
        return PlantTrainingActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction is PlantReplantingAction) {
        return PlantReplantingActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction.type == PlantActionType.other) {
        return PlantOtherActionSheetWidget(
          action: plantAction as PlantOtherAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction is PlantPictureAction) {
        return PlantPictureActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction is PlantDeathAction) {
        return PlantDeathActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      if (plantAction is PlantMeasurementAction) {
        return PlantMeasurementActionSheetWidget(
          action: plantAction,
          plant: plant,
          actionsProvider: actionsProvider,
          plantsProvider: plantsProvider,
          fertilizerProvider: fertilizerProvider,
        );
      }

      throw UnimplementedError('Unknown plant action type: ${plantAction.toJson()}');
    },
  );
}

/// Show a bottom sheet with the details of the [environmentAction].
Future<void> showEnvironmentActionDetailSheet(
  BuildContext context,
  EnvironmentAction environmentAction,
  Environment environment,
  ActionsProvider actionsProvider,
  EnvironmentsProvider environmentsProvider,
) async {
  await showModalBottomSheet(
    context: context,
    builder: (context) {
      if (environmentAction is EnvironmentMeasurementAction) {
        return EnvironmentMeasurementActionSheetWidget(
          action: environmentAction,
          environment: environment,
          actionsProvider: actionsProvider,
          environmentsProvider: environmentsProvider,
        );
      }

      if (environmentAction is EnvironmentOtherAction) {
        return EnvironmentOtherActionSheetWidget(
          action: environmentAction,
          environment: environment,
          actionsProvider: actionsProvider,
          environmentsProvider: environmentsProvider,
        );
      }

      if (environmentAction is EnvironmentPictureAction) {
        return EnvironmentPictureActionSheetWidget(
          action: environmentAction,
          environment: environment,
          actionsProvider: actionsProvider,
          environmentsProvider: environmentsProvider,
        );
      }

      throw UnimplementedError('Unknown environment action type: ${environmentAction.toJson()}');
    },
  );
}
