import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:weedy/actions/fertilizer/provider.dart';
import 'package:weedy/actions/provider.dart';
import 'package:weedy/actions/view.dart';
import 'package:weedy/common/date_utils.dart';
import 'package:weedy/common/dialog.dart';
import 'package:weedy/environments/model.dart';
import 'package:weedy/environments/provider.dart';
import 'package:weedy/plants/model.dart';
import 'package:weedy/plants/provider.dart';
import 'package:weedy/plants/sheet.dart';
import 'package:weedy/plants/transition/model.dart';
import 'package:weedy/plants/transition/provider.dart';

/// A widget that displays an overview of all plants.
class PlantOverview extends StatelessWidget {
  final PlantsProvider plantsProvider;
  final EnvironmentsProvider environmentsProvider;
  final ActionsProvider actionsProvider;
  final FertilizerProvider fertilizerProvider;
  final PlantLifecycleTransitionProvider transitionsProvider;
  final GlobalKey<State<BottomNavigationBar>> bottomNavigationKey;

  const PlantOverview({
    super.key,
    required this.plantsProvider,
    required this.environmentsProvider,
    required this.actionsProvider,
    required this.fertilizerProvider,
    required this.bottomNavigationKey,
    required this.transitionsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder(
        stream: CombineLatestStream.list([
          plantsProvider.plants,
          environmentsProvider.environments,
          transitionsProvider.transitions,
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final plants = snapshot.data![0] as Map<String, Plant>;
          final environments = snapshot.data![1] as Map<String, Environment>;
          final transitions = snapshot.data![2] as List<PlantLifecycleTransition>;
          if (plants.isEmpty) {
            return Center(
              child: Text(tr('plants.none')),
            );
          }

          return ListView(
            shrinkWrap: true,
            children: plants.values.map(
              (plant) {
                final environment = environments[plant.environmentId];
                final plantsInEnvironment =
                    plants.values.where((p) => p.environmentId == environment?.id).toList();
                final plantSpecificTransitions =
                    transitions.where((transition) => transition.plantId == plant.id).toList();
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Card(
                      child: Column(
                        children: [
                          plant.bannerImagePath == ''
                              ? Placeholder(
                                  fallbackHeight: constraints.maxWidth / 2,
                                  fallbackWidth: constraints.maxWidth,
                                )
                              : GestureDetector(
                                  child: Image.file(
                                    File(plant.bannerImagePath),
                                    width: constraints.maxWidth,
                                    height: constraints.maxWidth / 2,
                                    fit: BoxFit.cover,
                                  ),
                                  onTap: () async {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return Dialog(
                                          child: InteractiveViewer(
                                            panEnabled: false,
                                            // Set it to false
                                            boundaryMargin: const EdgeInsets.all(100),
                                            minScale: 1,
                                            maxScale: 2,
                                            child: Image.file(
                                              alignment: Alignment.center,
                                              File(plant.bannerImagePath),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                          ListTile(
                            leading: Hero(
                              tag: plant.id,
                              child: Text(
                                plant.lifeCycleState.icon,
                                style: const TextStyle(fontSize: 22.0),
                              ),
                            ),
                            title: Text(plant.name),
                            subtitle: Text(
                                '${daysSince(plant.createdAt)} days (W${weeksSince(plant.createdAt)})'),
                            onTap: () async {
                              debugPrint('Navigate to the plant detail view for ${plant.name}');
                              await showPlantDetailSheet(
                                  context,
                                  plant,
                                  plantSpecificTransitions.firstWhere(
                                      (transition) => transition.from == plant.lifeCycleState),
                                  plantsInEnvironment,
                                  environment,
                                  plantsProvider,
                                  actionsProvider,
                                  environmentsProvider,
                                  transitionsProvider,
                                  bottomNavigationKey);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.bolt_outlined),
                                  onPressed: () {
                                    debugPrint('Navigate to the plant edit view for ${plant.name}');
                                    Navigator.of(context).push(MaterialPageRoute(
                                        builder: (context) => CreatePlantActionView(
                                              plantsProvider: plantsProvider,
                                              actionsProvider: actionsProvider,
                                              fertilizerProvider: fertilizerProvider,
                                            )));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.timeline),
                                  onPressed: () {
                                    debugPrint(
                                        'Navigate to the plant timeline view for ${plant.name}');
                                    Navigator.of(context).push(MaterialPageRoute(
                                        builder: (context) => PlantActionOverview(
                                              plant: plant,
                                              plantsProvider: plantsProvider,
                                              actionsProvider: actionsProvider,
                                              fertilizerProvider: fertilizerProvider,
                                              plantLifecycleTransitionProvider: transitionsProvider,
                                            )));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ).toList(),
          );
        },
      ),
    );
  }
}

/// A widget to reuse the plant form for creating and editing plants.
class PlantForm extends StatefulWidget {
  final Plant? plant;
  final GlobalKey<FormState> formKey;
  final String title;
  final PlantsProvider plantsProvider;
  final EnvironmentsProvider environmentsProvider;
  final PlantLifecycleTransitionProvider transitionsProvider;
  final Function(bool, List<File>)? changeCallback;

  const PlantForm({
    super.key,
    required this.formKey,
    required this.title,
    required this.plant,
    required this.plantsProvider,
    required this.environmentsProvider,
    required this.transitionsProvider,
    required this.changeCallback,
  });

  @override
  State<PlantForm> createState() => _PlantFormState();
}

class _PlantFormState extends State<PlantForm> {
  final GlobalKey<PictureFormState> _pictureFormKey = GlobalKey<PictureFormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late List<bool> _selectedLifeCycleState;
  late Medium _selectedMedium;
  Environment? _currentEnvironment;

  late final Plant _initialPlant;

  @override
  void initState() {
    super.initState();

    if (widget.plant != null) {
      _initialPlant = widget.plant!;
      // Add postframe callback to set the initial values
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _currentEnvironment =
            (await widget.environmentsProvider.environments.first)[_initialPlant.environmentId];
      });
    }

    _nameController = TextEditingController(text: widget.plant?.name);
    _descriptionController = TextEditingController(text: widget.plant?.description);
    _selectedLifeCycleState = _selectedLifeCycleStateFromPlant(widget.plant);
    _selectedMedium = widget.plant?.medium ?? Medium.soil;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: bodyWidget(),
    );
  }

  Widget bodyWidget() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        child: Form(
          key: widget.formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const Text('Plant details'),
                      TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: tr('common.name'),
                            hintText: tr('plants.hint_name'),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return tr('common.name_mandatory');
                            }
                            return null;
                          },
                          onChanged: (value) {
                            if (widget.changeCallback != null) {
                              if (widget.plant != null) {
                                if (_initialPlant.name != value) {
                                  widget.changeCallback!(true, []);
                                } else {
                                  widget.changeCallback!(false, []);
                                }
                              }
                            }
                          }),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: null,
                        minLines: 5,
                        decoration: InputDecoration(
                            labelText: tr('common.description'),
                            hintText: tr('plants.hint_description'),
                          ),
                        onChanged: (value) {
                          if (widget.changeCallback != null) {
                            if (widget.plant != null) {
                              if (_descriptionController.text != _initialPlant.description) {
                                widget.changeCallback!(true, []);
                              } else {
                                widget.changeCallback!(false, []);
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.plant == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(tr('environments.select')),
                        StreamBuilder<Map<String, Environment>>(
                            stream: widget.environmentsProvider.environments,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return Center(child: Text('Error: ${snapshot.error}'));
                              }

                              final environments = snapshot.data!;
                              if (environments.isEmpty) {
                                return Center(
                                  child: Text(tr('environments.none')),
                                );
                              }
                              _currentEnvironment = environments[environments.keys.first]!;
                              return DropdownButton<Environment>(
                                icon: const Icon(Icons.arrow_downward_sharp),
                                isExpanded: true,
                                items: environments.values
                                    .map(
                                      (environment) => DropdownMenuItem<Environment>(
                                        value: environment,
                                        child: Text(environment.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (Environment? value) => _updateCurrentEnvironment(value),
                                value: _currentEnvironment,
                              );
                            }),
                      ],
                    ),
                  ),
                ),
              if (widget.plant == null)
                SizedBox(
                  width: double.infinity,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(tr('plants.current_lifecycle_state')),
                          const SizedBox(height: 8.0),
                          ToggleButtons(
                            isSelected: _selectedLifeCycleState,
                            onPressed: (index) => _onLifeCycleStateSelected(index),
                            children: LifeCycleState.values
                                .map(
                                  (state) => Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(state.icon, style: const TextStyle(fontSize: 18.0)),
                                  ),
                                )
                                .toList(),
                          ),
                          const Divider(),
                          Text(_lifeCycleState.name),
                        ],
                      ),
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButton<Medium>(
                    icon: const Icon(Icons.arrow_downward_sharp),
                    isExpanded: true,
                    items: Medium.values
                        .map(
                          (medium) => DropdownMenuItem<Medium>(
                            value: medium,
                            child: Text(medium.name),
                          ),
                        )
                        .toList(),
                    onChanged: (Medium? value) => _updateCurrentMedium(value),
                    value: _selectedMedium,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(tr('common.banner_image')),
                        PictureForm(
                            key: _pictureFormKey,
                            value: widget.plant,
                            allowMultiple: false,
                            images: widget.plant == null
                                ? []
                                : widget.plant!.bannerImagePath.isEmpty
                                    ? []
                                    : [File(widget.plant!.bannerImagePath)],
                            changeCallback: (changed, images) {
                              if (widget.changeCallback != null) {
                                if (images.isNotEmpty) {
                                  // Creation case - image was added but now user decided to leave the page
                                  if (widget.plant == null && images.isNotEmpty) {
                                    widget.changeCallback!(true, images);
                                    return;
                                  }

                                  // First case - environment was created without image, now editing with image.
                                  if (images.first.path != _initialPlant.bannerImagePath) {
                                    widget.changeCallback!(true, images);
                                  } else {
                                    widget.changeCallback!(false, []);
                                  }
                                } else {
                                  if (widget.plant == null) {
                                    widget.changeCallback!(false, []);
                                    return;
                                  }

                                  // Second case - environment was created with image, now editing without image.
                                  if (_initialPlant.bannerImagePath.isNotEmpty) {
                                    widget.changeCallback!(true, images);
                                  } else {
                                    widget.changeCallback!(false, []);
                                  }
                                }
                              }
                            }),
                      ],
                    ),
                  ),
                ),
              ),
              // Submit button
              const SizedBox(height: 16.0),
              OutlinedButton.icon(
                onPressed: () async => await _onPlantSaved(),
                label: Text(tr('common.save')),
                icon: const Icon(Icons.arrow_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Updates the current environment.
  void _updateCurrentEnvironment(Environment? environment) {
    setState(() {
      _currentEnvironment = environment;
      if (widget.changeCallback != null) {
        if (widget.plant != null) {
          if (_initialPlant.environmentId != environment!.id) {
            widget.changeCallback!(true, []);
          } else {
            widget.changeCallback!(false, []);
          }
        }
      }
    });
  }

  /// Updates the selected medium.
  void _updateCurrentMedium(Medium? medium) {
    setState(() {
      _selectedMedium = medium!;
      if (widget.changeCallback != null) {
        if (widget.plant != null) {
          if (_initialPlant.medium != medium) {
            widget.changeCallback!(true, []);
          } else {
            widget.changeCallback!(false, []);
          }
        }
      }
    });
  }

  /// Updates the selected life cycle states based on the selected index.
  void _onLifeCycleStateSelected(int index) {
    setState(() {
      for (var i = 0; i <= index; i++) {
        _selectedLifeCycleState[i] = true;
      }
      for (var i = index + 1; i < _selectedLifeCycleState.length; i++) {
        _selectedLifeCycleState[i] = false;
      }
    });
  }

  /// Handles the saving of a plant.
  Future<void> _onPlantSaved() async {
    if (widget.formKey.currentState!.validate()) {
      if (_currentEnvironment == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('environments.select_mandatory')),
          ),
        );
        return;
      } else {
        Plant plant;
        if (widget.plant != null) {
          plant = Plant(
            id: widget.plant!.id,
            name: _nameController.text,
            description: _descriptionController.text,
            environmentId: _currentEnvironment!.id,
            medium: _selectedMedium,
            lifeCycleState: _lifeCycleState,
            bannerImagePath: _pictureFormKey.currentState!.images.isEmpty
                ? ''
                : _pictureFormKey.currentState!.images.first,
            createdAt: widget.plant!.createdAt,
          );
          await widget.plantsProvider
              .updatePlant(plant)
              .whenComplete(() => Navigator.of(context).pop(plant));
        } else {
          plant = Plant(
            id: const Uuid().v4().toString(),
            name: _nameController.text,
            description: _descriptionController.text,
            environmentId: _currentEnvironment!.id,
            lifeCycleState: _lifeCycleState,
            medium: _selectedMedium,
            bannerImagePath: _pictureFormKey.currentState!.images.isEmpty
                ? ''
                : _pictureFormKey.currentState!.images.first,
            createdAt: DateTime.now(),
          );

          // Add an initial transition to the plant if it is new
          LifeCycleState? nextLifeCycleState;
          try {
            nextLifeCycleState = LifeCycleState.values[_lifeCycleState.index + 1];
          } catch (e) {
            nextLifeCycleState = null;
          }
          final transition = PlantLifecycleTransition(
            plantId: plant.id,
            from: plant.lifeCycleState,
            to: nextLifeCycleState,
            timestamp: DateTime.now(),
          );
          await widget.transitionsProvider.addTransition(transition);
          await widget.plantsProvider
              .addPlant(plant)
              .whenComplete(() => Navigator.of(context).pop());
        }
      }
    }
  }

  /// Returns the life cycle state based on the selected life cycle states.
  LifeCycleState get _lifeCycleState {
    final lastIndex = _selectedLifeCycleState.lastIndexOf(true);
    switch (lastIndex) {
      case 0:
        return LifeCycleState.germination;
      case 1:
        return LifeCycleState.seedling;
      case 2:
        return LifeCycleState.vegetative;
      case 3:
        return LifeCycleState.flowering;
      case 4:
        return LifeCycleState.drying;
      case 5:
        return LifeCycleState.curing;
      default:
        return LifeCycleState.germination;
    }
  }

  /// Returns a list of selected life cycle states based on the [plant].
  List<bool> _selectedLifeCycleStateFromPlant(Plant? plant) {
    if (plant == null) {
      return <bool>[true, false, false, false, false, false];
    }
    switch (plant.lifeCycleState) {
      case LifeCycleState.germination:
        return <bool>[true, false, false, false, false, false];
      case LifeCycleState.seedling:
        return <bool>[true, true, false, false, false, false];
      case LifeCycleState.vegetative:
        return <bool>[true, true, true, false, false, false];
      case LifeCycleState.flowering:
        return <bool>[true, true, true, true, false, false];
      case LifeCycleState.drying:
        return <bool>[true, true, true, true, true, false];
      case LifeCycleState.curing:
        return <bool>[true, true, true, true, true, true];
    }
  }
}

/// A view to create a plant.
class CreatePlantView extends StatefulWidget {
  final PlantsProvider plantsProvider;
  final EnvironmentsProvider environmentsProvider;
  final PlantLifecycleTransitionProvider transitionsProvider;

  const CreatePlantView({
    super.key,
    required this.plantsProvider,
    required this.environmentsProvider,
    required this.transitionsProvider,
  });

  @override
  State<CreatePlantView> createState() => _CreatePlantViewState();
}

class _CreatePlantViewState extends State<CreatePlantView> {
  final _formKey = GlobalKey<FormState>();

  bool _hasChanged = false;
  List<File> _images = [];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanged,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        if (_hasChanged) {
          final confirmed = await discardChangesDialog(context);
          if (confirmed && context.mounted) {
            // Delete all images that were added.
            for (var image in _images) {
              if (image.path.contains('app_flutter')) {
                image.delete();
              }
            }
            Navigator.of(context).pop();
          }
        }
      },
      child: PlantForm(
          formKey: _formKey,
          title: tr('plants.create'),
          plant: null,
          plantsProvider: widget.plantsProvider,
          environmentsProvider: widget.environmentsProvider,
          transitionsProvider: widget.transitionsProvider,
          changeCallback: (bool hasChanged, List<File> objects) {
            setState(() {
              _hasChanged = hasChanged;
              _images = objects;
            });
          }),
    );
  }
}

/// A view to edit a plant.
class EditPlantView extends StatefulWidget {
  final Plant plant;
  final PlantsProvider plantsProvider;
  final EnvironmentsProvider environmentsProvider;
  final PlantLifecycleTransitionProvider transitionsProvider;

  const EditPlantView({
    super.key,
    required this.plant,
    required this.plantsProvider,
    required this.environmentsProvider,
    required this.transitionsProvider,
  });

  @override
  State<EditPlantView> createState() => _EditPlantViewState();
}

class _EditPlantViewState extends State<EditPlantView> {
  final _formKey = GlobalKey<FormState>();

  bool _hasChanged = false;
  List<File> _images = [];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanged,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        if (_hasChanged) {
          final confirmed = await discardChangesDialog(context);
          if (confirmed && context.mounted) {
            // Delete all images that were added.
            for (var image in _images) {
              if (image.path.contains('app_flutter')) {
                image.delete();
              }
            }
            Navigator.of(context).pop();
          }
        }
      },
      child: PlantForm(
        formKey: _formKey,
        title: tr('plants.edit', namedArgs: {'name': widget.plant.name}),
        plant: widget.plant,
        plantsProvider: widget.plantsProvider,
        environmentsProvider: widget.environmentsProvider,
        transitionsProvider: widget.transitionsProvider,
        changeCallback: (bool hasChanged, List<File> objects) {
          setState(() {
            _hasChanged = hasChanged;
            _images = objects;
          });
        },
      ),
    );
  }
}
