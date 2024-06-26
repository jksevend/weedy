import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:weedy/actions/provider.dart';
import 'package:weedy/environments/model.dart';
import 'package:weedy/environments/provider.dart';
import 'package:weedy/environments/sheet.dart';
import 'package:weedy/plants/dialog.dart';
import 'package:weedy/plants/model.dart';
import 'package:weedy/plants/provider.dart';
import 'package:weedy/plants/transition/model.dart';
import 'package:weedy/plants/transition/provider.dart';
import 'package:weedy/plants/view.dart';

/// Shows a bottom sheet with detailed information about a [plant].
Future<void> showPlantDetailSheet(
  BuildContext context,
  Plant plant,
  PlantLifecycleTransition lifecycleTransition,
  List<Plant> plants,
  Environment? plantEnvironment,
  PlantsProvider plantsProvider,
  ActionsProvider actionsProvider,
  EnvironmentsProvider environmentsProvider,
  PlantLifecycleTransitionProvider transitionProvider,
  GlobalKey<State<BottomNavigationBar>> bottomNavigationBarKey,
) async {
  await showModalBottomSheet(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: Row(
                children: [
                  Text(plant.name),
                  const SizedBox(width: 8.0),
                  Text(plant.lifeCycleState.icon),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.medium.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(plant.description),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      onPressed: () async => _onDeletePlant(
                          context, plant, plantsProvider, actionsProvider, transitionProvider),
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
                    ),
                    IconButton(
                      onPressed: () async => _onUpdatePlant(
                        context,
                        plant,
                        plantsProvider,
                        environmentsProvider,
                        transitionProvider,
                        (updatedPlant) {
                          setState(
                            () {
                              if (updatedPlant != null) {
                                plant = updatedPlant;
                              }
                            },
                          );
                        },
                      ),
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
            ),
            const Divider(),
            // Information about the plants' environment
            plantEnvironment == null
                ? Text(tr('environments.none'))
                : ListTile(
                    leading: const Icon(Icons.lightbulb, color: Colors.yellow),
                    title: Text(tr('common.environment')),
                    subtitle: Text(plantEnvironment.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_right_alt),
                      onPressed: () async => _navigateToEnvironmentDetailSheet(
                        context,
                        bottomNavigationBarKey,
                        plant,
                        plantEnvironment,
                        plants,
                        plantsProvider,
                        environmentsProvider,
                        actionsProvider,
                      ),
                    ),
                  ),
            const Divider(),
              // Lifecycle transitions
              ListTile(
                leading: const Icon(Icons.change_circle_outlined),
                title: Text(tr('plants.transitions')),
                subtitle: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: lifecycleTransition.to == null
                            ? [
                                Text(lifecycleTransition.from.icon,
                                    style: const TextStyle(fontSize: 18)),
                                Text(lifecycleTransition.from.name,
                                    style: const TextStyle(fontSize: 18)),
                                Text(tr('plants.transitions_end'),
                                    style: const TextStyle(fontSize: 18)),
                              ]
                            : [
                                Text(lifecycleTransition.from.icon,
                                    style: const TextStyle(fontSize: 18)),
                                Text(lifecycleTransition.from.name,
                                    style: const TextStyle(fontSize: 18)),
                                const Icon(Icons.arrow_forward, size: 20),
                                Text(lifecycleTransition.to!.icon,
                                    style: const TextStyle(fontSize: 18)),
                                Text(lifecycleTransition.to!.name,
                                    style: const TextStyle(fontSize: 18)),
                              ],
                      ),
                      const SizedBox(height: 8),
                      if (lifecycleTransition.to != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_right_alt),
                          onPressed: () async => _onLifecycleTransition(
                            plant,
                            lifecycleTransition,
                            transitionProvider,
                            plantsProvider,
                            (updatedParams) {
                              final updatedPlant = updatedParams[0] as Plant;
                              final updatedTransition =
                                  updatedParams[1] as PlantLifecycleTransition;
                              setState(() {
                                plant = updatedPlant;
                                lifecycleTransition = updatedTransition;
                              });
                            },
                          ),
                          label:
                              Text(tr('plants.transition'), style: const TextStyle(fontSize: 14)),
                        )
                    ],
                  ),
                ),
              ),
              const Divider(),
            ],
          );
        },
      );
    },
  );
}

/// Transitions the plant to the next lifecycle state.
Future<void> _onLifecycleTransition(
  Plant plant,
  PlantLifecycleTransition lifecycleTransition,
  PlantLifecycleTransitionProvider transitionProvider,
  PlantsProvider plantsProvider,
  Function(List<dynamic>) stateSetter,
) async {
  // Advance the lifecycle state of the plant.
  final nextLifecycleState = LifeCycleState.values[(lifecycleTransition.from.index + 1)];
  LifeCycleState? nextNextLifecycleState;
  try {
    nextNextLifecycleState = LifeCycleState.values[(nextLifecycleState.index + 1)];
  } catch (e) {
    nextNextLifecycleState = null;
  }

  // Add the transition to the provider.
  final transition = PlantLifecycleTransition(
    from: nextLifecycleState,
    to: nextNextLifecycleState,
    plantId: plant.id,
    timestamp: DateTime.now(),
  );
  await transitionProvider.addTransition(transition);

  // Update the plant in the provider.
  plant.lifeCycleState = nextLifecycleState;
  final updatedPlant = await plantsProvider.updatePlant(plant);

  // Update the UI.
  stateSetter([updatedPlant, transition]);
}

/// Widget to display the current phase of the plant.

/// Delete the [plant] and all actions associated with it.
Future<void> _onDeletePlant(
  BuildContext context,
  Plant plant,
  PlantsProvider plantsProvider,
  ActionsProvider actionsProvider,
  PlantLifecycleTransitionProvider transitionProvider,
) async {
  final confirmed = await confirmDeletionOfPlantDialog(
      context, plant, plantsProvider, actionsProvider, transitionProvider);
  if (confirmed == true) {
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('common.deleted_args', namedArgs: {'name': plant.name})),
      ),
    );
  }
}

/// Update the [plant] in the provider.
Future<void> _onUpdatePlant(
  BuildContext context,
  Plant plant,
  PlantsProvider plantsProvider,
  EnvironmentsProvider environmentsProvider,
  PlantLifecycleTransitionProvider transitionProvider,
  Function(Plant?) stateSetter,
) async {
  final updatedPlant = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => EditPlantView(
          plant: plant,
          plantsProvider: plantsProvider,
          environmentsProvider: environmentsProvider,
          transitionsProvider: transitionProvider)));
  stateSetter(updatedPlant);
}

/// Navigates to the environment detail sheet.
Future<void> _navigateToEnvironmentDetailSheet(
  BuildContext context,
  GlobalKey<State<BottomNavigationBar>> bottomNavigationBarKey,
  Plant plant,
  Environment plantEnvironment,
  List<Plant> plants,
  PlantsProvider plantsProvider,
  EnvironmentsProvider environmentsProvider,
  ActionsProvider actionsProvider,
) async {
  var navigationBar = bottomNavigationBarKey.currentWidget as BottomNavigationBar;
  await Future.delayed(const Duration(milliseconds: 500));
  if (!context.mounted) {
    return;
  }
  Navigator.of(context).pop();
  navigationBar.onTap!(2);
  await showEnvironmentDetailSheet(
      context, plantEnvironment, plants, environmentsProvider, plantsProvider, actionsProvider);
}
