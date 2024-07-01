import 'dart:io';

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/streams.dart';
import 'package:uuid/uuid.dart';
import 'package:weedy/actions/fertilizer/dialog.dart';
import 'package:weedy/actions/fertilizer/model.dart';
import 'package:weedy/actions/fertilizer/provider.dart';
import 'package:weedy/actions/fertilizer/sheet.dart';
import 'package:weedy/actions/model.dart';
import 'package:weedy/actions/provider.dart';
import 'package:weedy/actions/widget.dart';
import 'package:weedy/common/dialog.dart';
import 'package:weedy/common/measurement.dart';
import 'package:weedy/common/temperature.dart';
import 'package:weedy/common/validators.dart';
import 'package:weedy/environments/model.dart';
import 'package:weedy/environments/provider.dart';
import 'package:weedy/plants/model.dart';
import 'package:weedy/plants/provider.dart';
import 'package:weedy/plants/transition/model.dart';
import 'package:weedy/plants/transition/provider.dart';

/// An over view of all environment actions.
class EnvironmentActionOverview extends StatelessWidget {
  final Environment environment;
  final ActionsProvider actionsProvider;
  final EnvironmentsProvider environmentsProvider;

  const EnvironmentActionOverview({
    super.key,
    required this.environment,
    required this.actionsProvider,
    required this.environmentsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(environment.name),
        centerTitle: true,
      ),
      body: StreamBuilder<List<EnvironmentAction>>(
        stream: actionsProvider.environmentActions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final environmentActions = snapshot.data!;
          if (environmentActions.isEmpty) {
            return Center(
              child: Text(tr('actions.environments.none')),
            );
          }

          final specificEnvironmentActions =
              environmentActions.where((action) => action.environmentId == environment.id).toList();

          if (specificEnvironmentActions.isEmpty) {
            return Center(
              child: Text(tr('actions.environments.none_for_this')),
            );
          }

          final groupedByDate = specificEnvironmentActions
              .fold<Map<DateTime, List<EnvironmentAction>>>({}, (map, action) {
            final dateKey =
                DateTime(action.createdAt.year, action.createdAt.month, action.createdAt.day);
            map[dateKey] = map[dateKey] ?? [];
            map[dateKey]!.add(action);
            return map;
          });

          groupedByDate.forEach((date, actions) {
            actions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          });
          return Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                child: VerticalDivider(
                  thickness: 2.0,
                  color: Colors.grey,
                ),
              ),
              ListView(
                children: groupedByDate.entries.map((entry) {
                  var date = entry.key;
                  var actions = entry.value;
                  final formattedDate = DateFormat.yMMMd().format(date);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formattedDate,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          return EnvironmentActionLogItem(
                            environmentsProvider: environmentsProvider,
                            actionsProvider: actionsProvider,
                            environment: environment,
                            action: action,
                            isFirst: index == 0,
                            isLast: index == actions.length - 1,
                          );
                        },
                        separatorBuilder: (BuildContext context, int index) {
                          return Column(
                            children: [
                              const SizedBox(height: 10),
                              Container(
                                width: 35,
                                height: 35,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// An over view of all plant actions.
class PlantActionOverview extends StatefulWidget {
  final Plant plant;
  final PlantsProvider plantsProvider;
  final ActionsProvider actionsProvider;
  final FertilizerProvider fertilizerProvider;
  final PlantLifecycleTransitionProvider plantLifecycleTransitionProvider;

  const PlantActionOverview({
    super.key,
    required this.plant,
    required this.plantsProvider,
    required this.actionsProvider,
    required this.fertilizerProvider,
    required this.plantLifecycleTransitionProvider,
  });

  @override
  State<PlantActionOverview> createState() => _PlantActionOverviewState();
}

class _PlantActionOverviewState extends State<PlantActionOverview> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: widget.plant.id,
              child: Text(widget.plant.lifeCycleState.icon),
            ),
            const SizedBox(width: 10),
            Text(widget.plant.name),
          ],
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: CombineLatestStream.list([
          widget.actionsProvider.plantActions,
          widget.plantLifecycleTransitionProvider.transitions,
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Prepare data
          final plantActions = snapshot.data![0] as List<PlantAction>;
          final specificPlantActions =
              plantActions.where((action) => action.plantId == widget.plant.id).toList();
          final specificPlantLifecycleTransitions =
              (snapshot.data![1] as List<PlantLifecycleTransition>)
                  .where((transition) => transition.plantId == widget.plant.id);
          final combinedActions = [...specificPlantActions, ...specificPlantLifecycleTransitions];

          // Latest actions appear first
          combinedActions.sort((a, b) {
            var aDate = a is PlantAction ? a.createdAt : (a as PlantLifecycleTransition).timestamp;
            var bDate = b is PlantAction ? b.createdAt : (b as PlantLifecycleTransition).timestamp;
            return bDate.compareTo(aDate);
          });

          // Group actions by date
          final groupedByDate =
              combinedActions.fold<Map<DateTime, List<dynamic>>>({}, (map, action) {
            final date = action is PlantAction
                ? action.createdAt
                : (action as PlantLifecycleTransition).timestamp;
            final dateKey = DateTime(date.year, date.month, date.day);
            map[dateKey] = map[dateKey] ?? [];
            map[dateKey]!.add(action);
            return map;
          });

          // Per latest action the actions are sorted by date descending
          groupedByDate.forEach((date, actions) {
            actions.sort((a, b) {
              var aTime =
                  a is PlantAction ? a.createdAt : (a as PlantLifecycleTransition).timestamp;
              var bTime =
                  b is PlantAction ? b.createdAt : (b as PlantLifecycleTransition).timestamp;
              return bTime.compareTo(aTime);
            });
          });
          return Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                child: VerticalDivider(
                  thickness: 2.0,
                  color: Colors.grey,
                ),
              ),
              ListView(
                children: groupedByDate.entries.map((entry) {
                  var date = entry.key;
                  var actions = entry.value;
                  final formattedDate = DateFormat.yMMMd().format(date);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formattedDate,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          final action = actions[index];
                          if (action is PlantAction) {
                            return PlantActionLogItem(
                              plantsProvider: widget.plantsProvider,
                              actionsProvider: widget.actionsProvider,
                              fertilizerProvider: widget.fertilizerProvider,
                              plant: widget.plant,
                              action: action,
                              isFirst: index == 0,
                              isLast: index == actions.length - 1,
                            );
                          } else {
                            final transition = action as PlantLifecycleTransition;
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: transition.from.color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(transition.from.icon,
                                          style: const TextStyle(fontSize: 20)),
                                      Flexible(
                                        flex: 1,
                                        child: Text(
                                          _lifecycleMessage(widget.plant.name, transition.from),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.info_outline),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: Text(tr('common.lifecycle')),
                                                content: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('${tr('common.next_lifecycle')}: '),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          transition.to!.icon,
                                                          style: const TextStyle(fontSize: 20),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Text(
                                                          transition.to!.name,
                                                          style: const TextStyle(fontSize: 20),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    child: Text(tr('common.ok')),
                                                    onPressed: () => Navigator.of(context).pop(),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        separatorBuilder: (BuildContext context, int index) {
                          return Column(
                            children: [
                              const SizedBox(height: 10),
                              Container(
                                width: 35,
                                height: 35,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  String _lifecycleMessage(String name, LifeCycleState lifeCycleState) {
    switch (lifeCycleState) {
      case LifeCycleState.germination:
        return tr('common.germination_message', namedArgs: {'name': name});
      case LifeCycleState.seedling:
        return tr('common.seedling_message', namedArgs: {'name': name});
      case LifeCycleState.vegetative:
        return tr('common.vegetative_message', namedArgs: {'name': name});
      case LifeCycleState.flowering:
        return tr('common.flowering_message', namedArgs: {'name': name});
      case LifeCycleState.drying:
        return tr('common.lifecycle.drying', namedArgs: {'name': name});
      case LifeCycleState.curing:
        return tr('common.lifecycle.curing', namedArgs: {'name': name});
    }
  }
}

/// A view to chose between creating a [PlantAction] or an [EnvironmentAction].
class ChooseActionView extends StatefulWidget {
  final PlantsProvider plantsProvider;
  final EnvironmentsProvider environmentsProvider;
  final ActionsProvider actionsProvider;
  final FertilizerProvider fertilizerProvider;

  const ChooseActionView({
    super.key,
    required this.plantsProvider,
    required this.environmentsProvider,
    required this.actionsProvider,
    required this.fertilizerProvider,
  });

  @override
  State<ChooseActionView> createState() => _ChooseActionViewState();
}

class _ChooseActionViewState extends State<ChooseActionView> {
  /// The choices to choose between a plant or an environment action.
  /// Index 0 is for plant actions, and index 1 is for environment actions.
  final List<bool> _choices = [true, false];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(tr('actions.choose')),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(tr('actions.choose_hint')),
                      const SizedBox(height: 10),
                      ToggleButtons(
                        constraints: const BoxConstraints(minWidth: 100),
                        isSelected: _choices,
                        onPressed: (int index) => _onToggleButtonsPressed(index),
                        children: [
                          Column(
                            children: [
                              Icon(
                                Icons.eco,
                                size: 50,
                                color: Colors.green[900],
                              ),
                              Text(tr('common.plant')),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                size: 50,
                                color: Colors.yellow[900],
                              ),
                              Text(tr('common.environment')),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            OutlinedButton(
                onPressed: () {
                  if (_choices[0]) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CreatePlantActionView(
                          plantsProvider: widget.plantsProvider,
                          actionsProvider: widget.actionsProvider,
                          fertilizerProvider: widget.fertilizerProvider,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => CreateEnvironmentActionView(
                        environmentsProvider: widget.environmentsProvider,
                        actionsProvider: widget.actionsProvider,
                      ),
                    ));
                  }
                },
                child: Text('Next'))
          ],
        ),
      ),
    );
  }

  /// The callback for the toggle buttons.
  void _onToggleButtonsPressed(int index) {
    setState(() {
      // The button that is tapped is set to true, and the others to false.
      for (int i = 0; i < _choices.length; i++) {
        _choices[i] = i == index;
      }
    });
  }
}

/// A form to display the CO2 measurement in the environment.
class EnvironmentCO2Form extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final EnvironmentMeasurementAction? action;
  final Function(bool, double) changeCallback;

  const EnvironmentCO2Form({
    super.key,
    required this.formKey,
    required this.action,
    required this.changeCallback,
  });

  @override
  State<EnvironmentCO2Form> createState() => EnvironmentCO2MeasurementFormState();
}

class EnvironmentCO2MeasurementFormState extends State<EnvironmentCO2Form> {
  late TextEditingController _co2Controller;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final co2 = widget.action!.measurement.measurement['co2'] as double;
      _co2Controller = TextEditingController(text: co2.toString());
    } else {
      _co2Controller = TextEditingController();
    }
  }

  @override
  void dispose() {
    _co2Controller.dispose();
    super.dispose();
  }

  /// The CO2 value.
  double get co2 {
    return double.parse(_co2Controller.text);
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: TextFormField(
        controller: _co2Controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.co2),
          labelText: 'CO2',
          hintText: '50',
        ),
        validator: (value) => validateInput(value, isDouble: true),
        onChanged: (value) {
          if (double.tryParse(value) == null) {
            return;
          }

          if (widget.action == null || widget.action!.measurement.measurement['co2'] != co2) {
            widget.changeCallback(true, co2);
          } else {
            widget.changeCallback(false, co2);
          }
        },
      ),
    );
  }
}

/// A form to display the distance of the light in the environment.
class EnvironmentLightDistanceForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final EnvironmentMeasurementAction? action;
  final Function(bool, MeasurementAmount) changeCallback;

  const EnvironmentLightDistanceForm({
    super.key,
    required this.formKey,
    required this.action,
    required this.changeCallback,
  });

  @override
  State<EnvironmentLightDistanceForm> createState() =>
      EnvironmentLightDistanceMeasurementFormState();
}

class EnvironmentLightDistanceMeasurementFormState extends State<EnvironmentLightDistanceForm> {
  late TextEditingController _distanceController;
  late MeasurementUnit _distanceUnit;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final distance = MeasurementAmount.fromJson(widget.action!.measurement.measurement);
      _distanceController = TextEditingController(text: distance.value.toString());
      _distanceUnit = distance.measurementUnit;
    } else {
      _distanceController = TextEditingController();
      _distanceUnit = MeasurementUnit.cm;
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  /// The distance value.
  MeasurementAmount get distance {
    return MeasurementAmount(
      value: double.parse(_distanceController.text),
      measurementUnit: _distanceUnit,
    );
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SizedBox(
        height: 75,
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _distanceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.highlight_rounded),
                  labelText: tr('common.distance'),
                  hintText: '50',
                ),
                validator: (value) => validateInput(value, isDouble: true),
                onChanged: (value) {
                  if (double.tryParse(value) == null) {
                    return;
                  }

                  if (widget.action == null || widget.action!.measurement.measurement != distance) {
                    widget.changeCallback(true, distance);
                  } else {
                    widget.changeCallback(false, distance);
                  }
                },
              ),
            ),
            const SizedBox(width: 50),
            const VerticalDivider(),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Unit:'),
                DropdownButton<MeasurementUnit>(
                  value: _distanceUnit,
                  icon: const Icon(Icons.arrow_downward_sharp),
                  items: MeasurementUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.symbol),
                        ),
                      )
                      .toList(),
                  onChanged: (MeasurementUnit? value) => _updateMeasurementUnit(value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Update the distance unit.
  void _updateMeasurementUnit(MeasurementUnit? value) {
    setState(() {
      _distanceUnit = value!;
      if (widget.action != null) {
        final distance = MeasurementAmount.fromJson(widget.action!.measurement.measurement);
        if (distance.measurementUnit != _distanceUnit) {
          widget.changeCallback(true, distance);
        } else {
          widget.changeCallback(false, distance);
        }
      }
    });
  }
}

/// A form to display the humidity measurement in the environment.
class EnvironmentHumidityForm extends StatefulWidget {
  final EnvironmentMeasurementAction? action;
  final GlobalKey<FormState> formKey;
  final Function(bool, double) changeCallback;

  const EnvironmentHumidityForm({
    super.key,
    required this.formKey,
    required this.action,
    required this.changeCallback,
  });

  @override
  State<EnvironmentHumidityForm> createState() => EnvironmentHumidityMeasurementFormState();
}

class EnvironmentHumidityMeasurementFormState extends State<EnvironmentHumidityForm> {
  late TextEditingController _humidityController;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final humidity = widget.action!.measurement.measurement['humidity'] as double;
      _humidityController = TextEditingController(text: humidity.toString());
    } else {
      _humidityController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _humidityController.dispose();
    super.dispose();
  }

  /// The humidity value.
  double get humidity {
    return double.parse(_humidityController.text);
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextFormField(
          controller: _humidityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.water_damage),
            labelText: tr('common.humidity'),
            hintText: '50',
          ),
          validator: (value) => validateInput(value, isDouble: true),
          onChanged: (value) {
            if (double.tryParse(value) == null) {
              return;
            }

            if (widget.action == null ||
                widget.action!.measurement.measurement['humidity'] != humidity) {
              widget.changeCallback(true, humidity);
            } else {
              widget.changeCallback(false, humidity);
            }
          },
        ),
      ),
    );
  }
}

/// A form to display the temperature measurement in the environment.
class EnvironmentTemperatureForm extends StatefulWidget {
  final EnvironmentMeasurementAction? action;
  final GlobalKey<FormState> formKey;
  final Function(bool, Temperature) changeCallback;

  const EnvironmentTemperatureForm({
    super.key,
    required this.formKey,
    required this.action,
    required this.changeCallback,
  });

  @override
  State<EnvironmentTemperatureForm> createState() => EnvironmentTemperatureMeasurementFormState();
}

class EnvironmentTemperatureMeasurementFormState extends State<EnvironmentTemperatureForm> {
  late TextEditingController _temperatureController;
  late TemperatureUnit _temperatureUnit;

  late final Temperature _initialTemperature;

  final FocusNode _temperatureValueFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _temperatureValueFocusNode.addListener(() {
      if (!_temperatureValueFocusNode.hasFocus) {
        _checkTemperature();
      }
    });
    if (widget.action != null) {
      final temperature = Temperature.fromJson(widget.action!.measurement.measurement);
      _initialTemperature = temperature;
      _temperatureController = TextEditingController(text: temperature.value.toString());
      _temperatureUnit = temperature.temperatureUnit;
    } else {
      _temperatureController = TextEditingController();
      _temperatureUnit = TemperatureUnit.celsius;
    }
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    super.dispose();
  }

  /// The temperature value.
  Temperature get temperature {
    return Temperature(
      value: double.parse(_temperatureController.text),
      temperatureUnit: _temperatureUnit,
    );
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SizedBox(
        width: double.infinity,
        height: 75,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextFormField(
                focusNode: _temperatureValueFocusNode,
                controller: _temperatureController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.thermostat),
                  labelText: tr('common.temperature'),
                  hintText: '25',
                ),
                validator: (value) => validateInput(value, isDouble: true),
                onFieldSubmitted: widget.action == null
                    ? null
                    : (value) {
                        _checkTemperature();
                      },
                onTapOutside: widget.action == null
                    ? null
                    : (focusNode) {
                        _checkTemperature();
                      },
                onEditingComplete: widget.action == null
                    ? null
                    : () {
                        _checkTemperature();
                      },
              ),
            ),
            const SizedBox(width: 50),
            const VerticalDivider(),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Unit:'),
                DropdownButton<TemperatureUnit>(
                  value: _temperatureUnit,
                  icon: const Icon(Icons.arrow_downward_sharp),
                  items: TemperatureUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.symbol),
                        ),
                      )
                      .toList(),
                  onChanged: (TemperatureUnit? value) => _updateTemperatureUnit(value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _checkTemperature() {
    if (double.tryParse(_temperatureController.text) == null) {
      return;
    }

    if (widget.action != null) {
      if (_initialTemperature.value != double.parse(_temperatureController.text)) {
        widget.changeCallback(true, temperature);
      } else {
        widget.changeCallback(false, temperature);
      }
    }
  }

  /// Update the temperature unit.
  void _updateTemperatureUnit(TemperatureUnit? value) {
    setState(() {
      _temperatureUnit = value!;
      if (widget.action != null) {
        if (_initialTemperature.temperatureUnit != _temperatureUnit) {
          widget.changeCallback(true, temperature);
        } else {
          widget.changeCallback(false, temperature);
        }
      }
    });
  }
}

/// A form to display the amount of water used for watering the plant.
class PlantWateringForm extends StatefulWidget {
  final PlantWateringAction? action;
  final GlobalKey<FormState> formKey;

  const PlantWateringForm({
    super.key,
    required this.action,
    required this.formKey,
  });

  @override
  State<PlantWateringForm> createState() => _PlantWateringFormState();
}

class _PlantWateringFormState extends State<PlantWateringForm> {
  late TextEditingController _waterAmountController;
  late LiquidUnit _waterAmountUnit;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final watering = widget.action!.amount;
      _waterAmountController = TextEditingController(text: watering.amount.toString());
      _waterAmountUnit = watering.unit;
    } else {
      // Set default values
      _waterAmountController = TextEditingController();
      _waterAmountUnit = LiquidUnit.ml;
    }
  }

  @override
  void dispose() {
    _waterAmountController.dispose();
    super.dispose();
  }

  /// The watering amount.
  LiquidAmount get watering {
    return LiquidAmount(
      unit: _waterAmountUnit,
      amount: double.parse(_waterAmountController.text),
    );
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SizedBox(
        width: double.infinity,
        height: 75,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: TextFormField(
                  controller: _waterAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixIcon: const Icon(Icons.water_drop_outlined),
                    labelText: tr('common.amount'),
                    hintText: '50',
                  ),
                  validator: (value) => validateInput(value, isDouble: true)),
            ),
            const SizedBox(width: 50),
            const VerticalDivider(),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Unit:'),
                DropdownButton<LiquidUnit>(
                  value: _waterAmountUnit,
                  icon: const Icon(Icons.arrow_downward_sharp),
                  items: LiquidUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.name),
                        ),
                      )
                      .toList(),
                  onChanged: (LiquidUnit? value) => _updateWaterAmountUnit(value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateWaterAmountUnit(LiquidUnit? value) {
    setState(() {
      _waterAmountUnit = value!;
    });
  }
}

/// A form to display the amount of fertilizer used for fertilizing the plant.
class PlantFertilizingForm extends StatefulWidget {
  final PlantFertilizingAction? action;
  final GlobalKey<FormState> formKey;
  final FertilizerProvider fertilizerProvider;

  const PlantFertilizingForm({
    super.key,
    required this.action,
    required this.formKey,
    required this.fertilizerProvider,
  });

  @override
  State<PlantFertilizingForm> createState() => _PlantFertilizingFormState();
}

class _PlantFertilizingFormState extends State<PlantFertilizingForm> {
  late TextEditingController _fertilizerAmountController;
  late LiquidUnit _liquidUnit;
  Fertilizer? _currentFertilizer;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final amount = widget.action!.fertilization;
      _fertilizerAmountController = TextEditingController(text: amount.amount.amount.toString());
      _liquidUnit = amount.amount.unit;
    } else {
      _fertilizerAmountController = TextEditingController();
      _liquidUnit = LiquidUnit.ml;
    }
  }

  @override
  void dispose() {
    _fertilizerAmountController.dispose();
    super.dispose();
  }

  /// The fertilization amount.
  PlantFertilization get fertilization {
    if (_currentFertilizer == null) {
      throw Exception('No fertilizer selected');
    }
    return PlantFertilization(
      fertilizerId: _currentFertilizer!.id,
      amount: LiquidAmount(
        unit: _liquidUnit,
        amount: double.parse(_fertilizerAmountController.text),
      ),
    );
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  /// Check if the form has fertilizers.
  bool get hasFertilizers {
    return _currentFertilizer != null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            StreamBuilder<Map<String, Fertilizer>>(
              stream: widget.fertilizerProvider.fertilizers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final fertilizers = snapshot.data!;
                if (fertilizers.isEmpty) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(tr('fertilizers.none')),
                      _addFertilizerButton(),
                    ],
                  );
                }

                _currentFertilizer = widget.action == null
                    ? fertilizers.entries.first.value
                    : fertilizers[widget.action!.fertilization.fertilizerId];
                return SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      DropdownButton<Fertilizer>(
                        icon: const Icon(Icons.arrow_downward_sharp),
                        items: fertilizers.entries
                            .map(
                              (fertilizer) => DropdownMenuItem<Fertilizer>(
                                value: fertilizer.value,
                                child: Text(fertilizer.value.name),
                              ),
                            )
                            .toList(),
                        onChanged: (Fertilizer? value) => _updateCurrentFertilizer(value),
                        value: _currentFertilizer,
                      ),
                      const VerticalDivider(),
                      Row(
                        children: [
                          _addFertilizerButton(),
                          const SizedBox(width: 10),
                          IconButton(
                              onPressed: () async {
                                await showFertilizerDetailSheet(
                                    context, widget.fertilizerProvider, fertilizers);
                              },
                              icon: const Icon(Icons.list)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            SizedBox(
              height: 75,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(
                    child: TextFormField(
                        controller: _fertilizerAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          suffixIcon: const Icon(Icons.eco),
                          labelText: tr('common.amount'),
                          hintText: '50',
                        ),
                        validator: (value) => validateInput(value, isDouble: true)),
                  ),
                  const SizedBox(width: 50),
                  const VerticalDivider(),
                  const SizedBox(width: 20),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Unit:'),
                      DropdownButton<LiquidUnit>(
                        value: _liquidUnit,
                        icon: const Icon(Icons.arrow_downward_sharp),
                        items: LiquidUnit.values
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit.name),
                              ),
                            )
                            .toList(),
                        onChanged: (LiquidUnit? value) => _updateLiquidUnit(value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Update the liquid unit.
  void _updateLiquidUnit(LiquidUnit? value) {
    setState(() {
      _liquidUnit = value!;
    });
  }

  /// Update the current fertilizer.
  void _updateCurrentFertilizer(Fertilizer? value) {
    setState(() {
      _currentFertilizer = value;
    });
  }

  /// The button to add a new fertilizer.
  Widget _addFertilizerButton() {
    return OutlinedButton.icon(
      onPressed: () async {
        await showFertilizerForm(context, widget.fertilizerProvider, null);
      },
      icon: const Icon(Icons.add),
      label: const Text('Add'),
    );
  }
}

/// A form to display the type of pruning done on the plant.
class PlantPruningForm extends StatefulWidget {
  final PlantPruningAction? action;

  const PlantPruningForm({super.key, required this.action});

  @override
  State<PlantPruningForm> createState() => _PlantPruningFormState();
}

class _PlantPruningFormState extends State<PlantPruningForm> {
  late PruningType _pruningType;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      _pruningType = widget.action!.pruningType;
    } else {
      _pruningType = PruningType.topping;
    }
  }

  /// The pruning type.
  PruningType get pruningType {
    return _pruningType;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<PruningType>(
      isExpanded: true,
      value: _pruningType,
      icon: const Icon(Icons.arrow_downward_sharp),
      items: PruningType.values
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(type.name),
            ),
          )
          .toList(),
      onChanged: (PruningType? value) => _updatePruningType(value),
    );
  }

  /// Update the pruning type.
  void _updatePruningType(PruningType? value) {
    setState(() {
      _pruningType = value!;
    });
  }
}

/// A form to display the amount of the plant harvested.
class PlantHarvestingForm extends StatefulWidget {
  final PlantHarvestingAction? action;
  final GlobalKey<FormState> formKey;

  const PlantHarvestingForm({super.key, required this.action, required this.formKey});

  @override
  State<PlantHarvestingForm> createState() => _PlantHarvestingFormState();
}

class _PlantHarvestingFormState extends State<PlantHarvestingForm> {
  late TextEditingController _harvestAmountController;
  late WeightUnit _weightUnit;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final harvest = widget.action!.amount;
      _harvestAmountController = TextEditingController(text: harvest.amount.toString());
      _weightUnit = harvest.unit;
    } else {
      _harvestAmountController = TextEditingController();
      _weightUnit = WeightUnit.g;
    }
  }

  @override
  void dispose() {
    _harvestAmountController.dispose();
    super.dispose();
  }

  /// The harvest amount.
  WeightAmount get harvest {
    return WeightAmount(
      unit: _weightUnit,
      amount: double.parse(_harvestAmountController.text),
    );
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SizedBox(
        height: 75,
        width: double.infinity,
        child: Row(
          children: [
            Flexible(
              child: TextFormField(
                  controller: _harvestAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixIcon: const Icon(Icons.eco),
                    labelText: tr('common.amount'),
                    hintText: '50',
                  ),
                  validator: (value) => validateInput(value, isDouble: true)),
            ),
            const SizedBox(width: 50),
            const VerticalDivider(),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Unit:'),
                DropdownButton<WeightUnit>(
                  value: _weightUnit,
                  icon: const Icon(Icons.arrow_downward_sharp),
                  items: WeightUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.name),
                        ),
                      )
                      .toList(),
                  onChanged: (WeightUnit? value) => _updateWeightUnit(value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Update the weight unit.
  void _updateWeightUnit(WeightUnit? value) {
    setState(() {
      _weightUnit = value!;
    });
  }
}

/// A form to display the type of training done on the plant.
class PlantTrainingForm extends StatefulWidget {
  final PlantTrainingAction? action;

  const PlantTrainingForm({super.key, required this.action});

  @override
  State<PlantTrainingForm> createState() => _PlantTrainingFormState();
}

class _PlantTrainingFormState extends State<PlantTrainingForm> {
  late TrainingType _trainingType;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      _trainingType = widget.action!.trainingType;
    } else {
      _trainingType = TrainingType.lst;
    }
  }

  /// The training type.
  TrainingType get trainingType {
    return _trainingType;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<TrainingType>(
      isExpanded: true,
      value: _trainingType,
      icon: const Icon(Icons.arrow_downward_sharp),
      items: TrainingType.values
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(type.name),
            ),
          )
          .toList(),
      onChanged: (TrainingType? value) => _updateTrainingType(value),
    );
  }

  void _updateTrainingType(TrainingType? value) {
    setState(() {
      _trainingType = value!;
    });
  }
}

/// A form to display different types of plant measurements.
class PlantMeasurementForm extends StatefulWidget {
  final PlantMeasurementAction? action;
  final GlobalKey<PlantHeightMeasurementFormState> plantMeasurementWidgetKey;
  final GlobalKey<PlantECMeasurementFormState> plantECMeasurementFormKey;
  final GlobalKey<PlantPHMeasurementFormState> plantPHMeasurementFormKey;
  final GlobalKey<PlantPPMMeasurementFormState> plantPPMMeasurementFormKey;

  const PlantMeasurementForm({
    super.key,
    required this.action,
    required this.plantMeasurementWidgetKey,
    required this.plantECMeasurementFormKey,
    required this.plantPHMeasurementFormKey,
    required this.plantPPMMeasurementFormKey,
  });

  @override
  State<PlantMeasurementForm> createState() => _PlantMeasurementFormState();
}

class _PlantMeasurementFormState extends State<PlantMeasurementForm> {
  late PlantMeasurementType _measurementType;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      _measurementType = widget.action!.measurement.type;
    } else {
      _measurementType = PlantMeasurementType.height;
    }
  }

  /// The current measurement type.
  PlantMeasurementType get measurementType {
    return _measurementType;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton<PlantMeasurementType>(
          isExpanded: true,
          value: _measurementType,
          icon: const Icon(Icons.arrow_downward_sharp),
          items: PlantMeasurementType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Text(
                        type.icon,
                      ),
                      const SizedBox(width: 10),
                      Text(type.name),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (PlantMeasurementType? value) => _updateMeasurementType(value),
        ),
        const Divider(),
        _measurementForm(),
      ],
    );
  }

  void _updateMeasurementType(PlantMeasurementType? value) {
    setState(() {
      _measurementType = value!;
    });
  }

  /// The specific plant measurement form.
  Widget _measurementForm() {
    switch (_measurementType) {
      case PlantMeasurementType.height:
        return PlantHeightMeasurementForm(
          key: widget.plantMeasurementWidgetKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
        );
      case PlantMeasurementType.pH:
        return PlantPHMeasurementForm(
          key: widget.plantPHMeasurementFormKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
        );
      case PlantMeasurementType.ec:
        return PlantECMeasurementForm(
          key: widget.plantECMeasurementFormKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
        );
      case PlantMeasurementType.ppm:
        return PlantPPMMeasurementForm(
          key: widget.plantPPMMeasurementFormKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
        );
    }
  }
}

/// A form to display the height measurement of the plant.
class PlantHeightMeasurementForm extends StatefulWidget {
  final PlantMeasurementAction? action;
  final GlobalKey<FormState> formKey;

  const PlantHeightMeasurementForm({super.key, required this.action, required this.formKey});

  @override
  State<PlantHeightMeasurementForm> createState() => PlantHeightMeasurementFormState();
}

class PlantHeightMeasurementFormState extends State<PlantHeightMeasurementForm> {
  late TextEditingController _heightController;
  late MeasurementUnit _heightUnit;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final height = MeasurementAmount.fromJson(widget.action!.measurement.measurement);
      _heightController = TextEditingController(text: height.value.toString());
      _heightUnit = height.measurementUnit;
    } else {
      _heightController = TextEditingController();
      _heightUnit = MeasurementUnit.cm;
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  /// The height value.
  MeasurementAmount get height {
    return MeasurementAmount(
      value: double.parse(_heightController.text),
      measurementUnit: _heightUnit,
    );
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: SizedBox(
        height: 75,
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('common.height'),
                    hintText: '50',
                  ),
                  validator: (value) => validateInput(value, isDouble: true)),
            ),
            const SizedBox(width: 50),
            const VerticalDivider(),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Unit:'),
                DropdownButton<MeasurementUnit>(
                  value: MeasurementUnit.cm,
                  icon: const Icon(Icons.arrow_downward_sharp),
                  items: MeasurementUnit.values
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.symbol),
                        ),
                      )
                      .toList(),
                  onChanged: (MeasurementUnit? value) => _updateHeightUnit(value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Update the height unit.
  void _updateHeightUnit(MeasurementUnit? value) {
    setState(() {
      _heightUnit = value!;
    });
  }
}

/// A form to display the pH measurement of the plant.
class PlantPHMeasurementForm extends StatefulWidget {
  final PlantMeasurementAction? action;
  final GlobalKey<FormState> formKey;

  const PlantPHMeasurementForm({super.key, required this.action, required this.formKey});

  @override
  State<PlantPHMeasurementForm> createState() => PlantPHMeasurementFormState();
}

class PlantPHMeasurementFormState extends State<PlantPHMeasurementForm> {
  late TextEditingController _phController;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final ph = widget.action!.measurement.measurement['ph'] as double;
      _phController = TextEditingController(text: ph.toString());
    } else {
      _phController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _phController.dispose();
    super.dispose();
  }

  /// The pH value.
  double get ph {
    return double.parse(_phController.text);
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: TextFormField(
        controller: _phController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'pH',
          hintText: '7.0',
        ),
        validator: (value) => validateInput(value, isDouble: true),
      ),
    );
  }
}

/// A form to display the EC measurement of the plant.
class PlantECMeasurementForm extends StatefulWidget {
  final PlantMeasurementAction? action;
  final GlobalKey<FormState> formKey;

  const PlantECMeasurementForm({super.key, required this.action, required this.formKey});

  @override
  State<PlantECMeasurementForm> createState() => PlantECMeasurementFormState();
}

class PlantECMeasurementFormState extends State<PlantECMeasurementForm> {
  late TextEditingController _ecController;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final ec = widget.action!.measurement.measurement['ec'] as double;
      _ecController = TextEditingController(text: ec.toString());
    } else {
      _ecController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _ecController.dispose();
    super.dispose();
  }

  /// The EC value.
  double get ec {
    return double.parse(_ecController.text);
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: TextFormField(
        controller: _ecController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'EC',
          hintText: '1.5',
        ),
        validator: (value) => validateInput(value, isDouble: true),
      ),
    );
  }
}

/// A form to display the PPM measurement of the plant.
class PlantPPMMeasurementForm extends StatefulWidget {
  final PlantMeasurementAction? action;
  final GlobalKey<FormState> formKey;

  const PlantPPMMeasurementForm({super.key, required this.action, required this.formKey});

  @override
  State<PlantPPMMeasurementForm> createState() => PlantPPMMeasurementFormState();
}

class PlantPPMMeasurementFormState extends State<PlantPPMMeasurementForm> {
  late TextEditingController _ppmController;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final ppm = widget.action!.measurement.measurement['ppm'] as double;
      _ppmController = TextEditingController(text: ppm.toString());
    } else {
      _ppmController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _ppmController.dispose();
    super.dispose();
  }

  /// The PPM value.
  double get ppm {
    return double.parse(_ppmController.text);
  }

  /// Check if the form is valid.
  bool get isValid {
    return widget.formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: TextFormField(
        controller: _ppmController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'PPM',
          hintText: '500',
        ),
        validator: (value) => validateInput(value, isDouble: true),
      ),
    );
  }
}

/// A form to take pictures.
class PictureForm<T> extends StatefulWidget {
  final T? value;
  final bool allowMultiple;
  final List<File> images;
  final Function(bool, List<File>) changeCallback;

  const PictureForm({
    super.key,
    required this.value,
    required this.allowMultiple,
    required this.images,
    required this.changeCallback,
  });

  @override
  State<PictureForm> createState() => PictureFormState();
}

class PictureFormState extends State<PictureForm> {
  final ImagePicker _picker = ImagePicker();
  late List<File> _images;

  @override
  void initState() {
    super.initState();
    _images = [...widget.images];
  }

  /// The images taken.
  List<String> get images {
    return _images.isEmpty ? [] : _images.map((image) => image.path).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _images.isEmpty
            ? SizedBox(
                child: Row(
                  children: [
                    widget.allowMultiple
                        ? Text(tr('common.no_images'))
                        : Text(tr('common.no_image')),
                    _addImageButton(),
                  ],
                ),
              )
            : SizedBox(
                height: 125,
                child: Row(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (context, index) => const VerticalDivider(),
                      itemBuilder: (context, index) {
                        final image = _images[index];
                        return Column(
                          children: [
                            IconButton(
                              onPressed: () => _removeImage(index, image),
                              icon: const Icon(Icons.clear, color: Colors.red),
                            ),
                            Image.file(
                              image,
                              width: 75,
                              height: 75,
                            ),
                          ],
                        );
                      },
                    ),
                    if (widget.allowMultiple) _addImageButton(),
                  ],
                ),
              ),
      ],
    );
  }

  /// Remove an image.
  void _removeImage(int index, File image) {
    setState(() {
      if (widget.value == null) {
        for (final tempImage in _images) {
          // We only save app images
          if (tempImage.path.contains('app_flutter')) {
            if (image.path == tempImage.path) {
              tempImage.delete();
            }
          }
        }
      }
      _images.removeAt(index);
      if (widget.allowMultiple) {
        widget.changeCallback(true, _images);
      } else {
        widget.changeCallback(false, _images);
      }
    });
  }

  /// The button to add an image.
  Widget _addImageButton() {
    return IconButton(
      onPressed: () async {
        final File? image = await showModalBottomSheet(
          context: context,
          builder: (context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(tr('common.take_image_camera')),
                  onTap: () async {
                    final file = await _getImage(ImageSource.camera);
                    if (!context.mounted) return;
                    Navigator.of(context).pop(file);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo),
                  title: Text(tr('common.select_image_gallery')),
                  onTap: () async {
                    final file = await _getImage(ImageSource.gallery);
                    if (!context.mounted) return;
                    Navigator.of(context).pop(file);
                  },
                ),
              ],
            );
          },
        );

        if (image == null) return;

        setState(() {
          _images.add(image);
          widget.changeCallback(true, _images);
        });
      },
      icon: const Icon(Icons.add_a_photo),
    );
  }

  /// Get an image from the camera or gallery.
  Future<File> _getImage(final ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) throw Exception('No image picked');
    if (source == ImageSource.camera) {
      // images taken from the camera are stored in the app directory for now
      // TODO: Store images in platform specific gallery directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final fullPath = '${appDir.path}/images/$fileName';

      // Create the images directory if it does not exist
      final imagesDirectory = Directory('${appDir.path}/images');
      if (!imagesDirectory.existsSync()) {
        imagesDirectory.createSync();
      }

      // Save the image to the app directory
      await pickedFile.saveTo(fullPath);

      // Delete the image from the temporary directory
      final cachedFile = File(pickedFile.path);
      await cachedFile.delete();

      final file = File(fullPath);
      return file;
    }
    return File(pickedFile.path);
  }
}

/// A form to display the type of the environment measurement.
class EnvironmentMeasurementForm extends StatefulWidget {
  final EnvironmentMeasurementAction? action;
  final GlobalKey<EnvironmentCO2MeasurementFormState> environmentCO2FormKey;
  final GlobalKey<EnvironmentHumidityMeasurementFormState> environmentHumidityFormKey;
  final GlobalKey<EnvironmentLightDistanceMeasurementFormState> environmentLightDistanceFormKey;
  final GlobalKey<EnvironmentTemperatureMeasurementFormState> environmentTemperatureFormKey;
  final Function(bool, dynamic) changeCallback;

  const EnvironmentMeasurementForm({
    super.key,
    required this.action,
    required this.environmentCO2FormKey,
    required this.environmentHumidityFormKey,
    required this.environmentLightDistanceFormKey,
    required this.environmentTemperatureFormKey,
    required this.changeCallback,
  });

  @override
  State<EnvironmentMeasurementForm> createState() => _EnvironmentMeasurementFormState();
}

class _EnvironmentMeasurementFormState extends State<EnvironmentMeasurementForm> {
  late EnvironmentMeasurementType _measurementType;
  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final measurement = widget.action!.measurement;
      if (measurement.measurement.containsKey('temperatureUnit')) {
        _measurementType = EnvironmentMeasurementType.temperature;
      } else if (measurement.measurement.containsKey('humidity')) {
        _measurementType = EnvironmentMeasurementType.humidity;
      } else if (measurement.measurement.containsKey('co2')) {
        _measurementType = EnvironmentMeasurementType.co2;
      } else if (measurement.measurement.containsKey('measurementUnit    ')) {
        _measurementType = EnvironmentMeasurementType.lightDistance;
      } else {
        throw Exception('Unknown measurement type');
      }
    } else {
      _measurementType = EnvironmentMeasurementType.temperature;
    }
  }

  /// The current measurement type.
  EnvironmentMeasurementType get measurementType {
    return _measurementType;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButton<EnvironmentMeasurementType>(
          icon: const Icon(Icons.arrow_downward_sharp),
          value: _measurementType,
          isExpanded: true,
          items: EnvironmentMeasurementType.values
              .map(
                (type) => DropdownMenuItem<EnvironmentMeasurementType>(
                  value: type,
                  child: Row(
                    children: [
                      Text(type.icon),
                      const SizedBox(width: 10),
                      Text(type.name),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: widget.action != null
              ? null
              : (EnvironmentMeasurementType? value) => _updateMeasurementType(value),
        ),
        _environmentActionMeasurementForm(),
      ],
    );
  }

  /// Update the measurement type.
  void _updateMeasurementType(EnvironmentMeasurementType? value) {
    setState(() {
      _measurementType = value!;
    });
  }

  /// The specific environment measurement form.
  Widget _environmentActionMeasurementForm() {
    switch (_measurementType) {
      case EnvironmentMeasurementType.temperature:
        return EnvironmentTemperatureForm(
          key: widget.environmentTemperatureFormKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
          changeCallback: widget.changeCallback,
        );
      case EnvironmentMeasurementType.humidity:
        return EnvironmentHumidityForm(
          key: widget.environmentHumidityFormKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
          changeCallback: widget.changeCallback,
        );
      case EnvironmentMeasurementType.co2:
        return EnvironmentCO2Form(
          key: widget.environmentCO2FormKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
          changeCallback: widget.changeCallback,
        );
      case EnvironmentMeasurementType.lightDistance:
        return EnvironmentLightDistanceForm(
          key: widget.environmentLightDistanceFormKey,
          action: widget.action,
          formKey: GlobalKey<FormState>(),
          changeCallback: widget.changeCallback,
        );
    }
  }
}

/// A view to create a plant action.
class CreatePlantActionView extends StatefulWidget {
  final PlantsProvider plantsProvider;
  final ActionsProvider actionsProvider;
  final FertilizerProvider fertilizerProvider;

  const CreatePlantActionView({
    super.key,
    required this.plantsProvider,
    required this.actionsProvider,
    required this.fertilizerProvider,
  });

  @override
  State<CreatePlantActionView> createState() => _CreatePlantActionViewState();
}

class _CreatePlantActionViewState extends State<CreatePlantActionView> {
  @override
  Widget build(BuildContext context) {
    return PlantActionForm(
      title: tr('actions.plants.create'),
        action: null,
        actionsProvider: widget.actionsProvider,
        plantsProvider: widget.plantsProvider,
        fertilizerProvider: widget.fertilizerProvider,
    );
  }
}

class EditPlantActionView extends StatefulWidget {
  final PlantAction action;
  final PlantsProvider plantsProvider;
  final ActionsProvider actionsProvider;
  final FertilizerProvider fertilizerProvider;

  const EditPlantActionView({
    super.key,
    required this.action,
    required this.plantsProvider,
    required this.actionsProvider,
    required this.fertilizerProvider,
  });

  @override
  State<EditPlantActionView> createState() => _EditPlantActionViewState();
}

class _EditPlantActionViewState extends State<EditPlantActionView> {
  @override
  Widget build(BuildContext context) {
    return PlantActionForm(
      title: tr('actions.plants.edit'),
      action: widget.action,
      actionsProvider: widget.actionsProvider,
      plantsProvider: widget.plantsProvider,
      fertilizerProvider: widget.fertilizerProvider,
    );
  }
}
/// A view to create an environment action.
class CreateEnvironmentActionView extends StatefulWidget {
  final ActionsProvider actionsProvider;
  final EnvironmentsProvider environmentsProvider;

  const CreateEnvironmentActionView({
    super.key,
    required this.actionsProvider,
    required this.environmentsProvider,
  });

  @override
  State<CreateEnvironmentActionView> createState() => _CreateEnvironmentActionViewState();
}

class _CreateEnvironmentActionViewState extends State<CreateEnvironmentActionView> {
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
            int count = 0;
            Navigator.of(context).popUntil((route) {
              return count++ == 2;
            });
          }
        }
      },
      child: EnvironmentActionForm(
        title: tr('actions.environments.create'),
        action: null,
        actionsProvider: widget.actionsProvider,
        environmentsProvider: widget.environmentsProvider,
        changeCallback: (changed, images) {
          setState(() {
            _hasChanged = changed;
            _images = images;
          });
        },
      ),
    );
  }
}

/// A view to edit an environment action.
class EditEnvironmentActionView extends StatefulWidget {
  final EnvironmentAction action;
  final ActionsProvider actionsProvider;
  final EnvironmentsProvider environmentsProvider;

  const EditEnvironmentActionView({
    super.key,
    required this.action,
    required this.actionsProvider,
    required this.environmentsProvider,
  });

  @override
  State<EditEnvironmentActionView> createState() => _EditEnvironmentActionViewState();
}

class _EditEnvironmentActionViewState extends State<EditEnvironmentActionView> {
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
      child: EnvironmentActionForm(
        title: tr('actions.environments.edit'),
        action: widget.action,
        actionsProvider: widget.actionsProvider,
        environmentsProvider: widget.environmentsProvider,
        changeCallback: (changed, images) async {
          setState(() {
            _hasChanged = changed;
            _images = images;
          });
        },
      ),
    );
  }
}

class PlantActionForm extends StatefulWidget {
  final String title;
  final PlantAction? action;
  final ActionsProvider actionsProvider;
  final PlantsProvider plantsProvider;
  final FertilizerProvider fertilizerProvider;

  const PlantActionForm({
    super.key,
    required this.title,
    required this.action,
    required this.actionsProvider,
    required this.plantsProvider,
    required this.fertilizerProvider,
  });

  @override
  State<PlantActionForm> createState() => _PlantActionFormState();
}

class _PlantActionFormState extends State<PlantActionForm> {
  /// Plant actions widget keys

  final GlobalKey<_PlantMeasurementFormState> _plantMeasuringFormKey = GlobalKey();
  final GlobalKey<_PlantWateringFormState> _plantWateringWidgetKey = GlobalKey();
  final GlobalKey<_PlantFertilizingFormState> _plantFertilizingFormKey = GlobalKey();
  final GlobalKey<_PlantPruningFormState> _plantPruningFormKey = GlobalKey();
  final GlobalKey<_PlantHarvestingFormState> _plantHarvestingFormKey = GlobalKey();
  final GlobalKey<_PlantTrainingFormState> _plantTrainingFormKey = GlobalKey();
  final GlobalKey<PictureFormState> _plantPictureFormState = GlobalKey();

  final GlobalKey<PlantHeightMeasurementFormState> _plantHeightMeasurementWidgetKey = GlobalKey();
  final GlobalKey<PlantPHMeasurementFormState> _plantPHMeasurementWidgetKey = GlobalKey();
  final GlobalKey<PlantECMeasurementFormState> _plantECMeasurementWidgetKey = GlobalKey();
  final GlobalKey<PlantPPMMeasurementFormState> _plantPPMMeasurementWidgetKey = GlobalKey();

  /// Plant form information

  Plant? _currentPlant;
  late PlantActionType _currentPlantActionType = PlantActionType.watering;
  late final TextEditingController _plantActionDescriptionTextController = TextEditingController();
  DateTime _plantActionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      final action = widget.action!;
      _currentPlantActionType = action.type;
      _plantActionDate = action.createdAt;
      _plantActionDescriptionTextController.text = action.description;
    }
  }

  @override
  void dispose() {
    _plantActionDescriptionTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(tr('actions.plants.choose')),
                      StreamBuilder<Map<String, Plant>>(
                          stream: widget.plantsProvider.plants,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(child: Text('Error: ${snapshot.error}'));
                            }

                            final plants = snapshot.data!;
                            if (plants.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(tr('plants.none')),
                                ),
                              );
                            }
                            if (widget.action != null) {
                              _currentPlant = plants[widget.action!.plantId];
                              return DropdownButton<Plant>(
                                icon: const Icon(Icons.arrow_downward_sharp),
                                isExpanded: true,
                                items: plants.values
                                    .map(
                                      (plant) => DropdownMenuItem<Plant>(
                                        value: plant,
                                        child: Text(plant.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (Plant? value) => _updateCurrentPlant(value),
                                hint: Text(tr('plants.mandatory')),
                                value: _currentPlant,
                              );
                            }
                            return DropdownButton<Plant>(
                              icon: const Icon(Icons.arrow_downward_sharp),
                              isExpanded: true,
                              items: plants.values
                                  .map(
                                    (plant) => DropdownMenuItem<Plant>(
                                      value: plant,
                                      child: Text(plant.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (Plant? value) => _updateCurrentPlant(value),
                              hint: Text(tr('plants.mandatory')),
                              value: _currentPlant,
                            );
                          }),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          const Icon(Icons.calendar_month),
                          Text('${tr('common.select_date')}: '),
                          TextButton(
                            onPressed: () => _selectDate(
                              context,
                              (date) {
                                setState(() {
                                  _plantActionDate = date;
                                });
                              },
                            ),
                            child: Text(
                              '${_plantActionDate.toLocal()}'.split(' ')[0],
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      TextField(
                        controller: _plantActionDescriptionTextController,
                        maxLines: null,
                        minLines: 5,
                        decoration: InputDecoration(
                          labelText: tr('common.description'),
                          hintText: tr('actions.plants.description_hint'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Column(
                        children: [
                          DropdownButton<PlantActionType>(
                            icon: const Icon(Icons.arrow_downward_sharp),
                            value: _currentPlantActionType,
                            isExpanded: true,
                            items: PlantActionType.values
                                .map(
                                  (action) => DropdownMenuItem<PlantActionType>(
                                    value: action,
                                    child: Row(
                                      children: [
                                        Text(action.icon),
                                        const SizedBox(width: 10),
                                        Text(action.name),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (PlantActionType? value) =>
                                _updateCurrentPlantActionType(value),
                          ),
                        ],
                      ),
                      _plantActionForm(),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () async => await _onPlantActionCreated(),
                  label: Text(tr('common.save')),
                  icon: const Icon(Icons.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Update the current plant.
  void _updateCurrentPlant(Plant? plant) {
    setState(() {
      _currentPlant = plant!;
    });
  }

  /// Update the current plant action type.
  void _updateCurrentPlantActionType(PlantActionType? actionType) {
    setState(() {
      _currentPlantActionType = actionType!;
    });
  }

  /// Show a snackbar if no images are selected.
  void _showImageSelectionMandatorySnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.error,
                color: Colors.red,
              ),
            ),
            Text(
              tr('common.images_mandatory'),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Open up a date picker to select a date.
  Future<void> _selectDate(BuildContext context, Function(DateTime) dateCallback) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null) {
      dateCallback(picked);
    }
  }

  /// The specific plant action form.
  Widget _plantActionForm() {
    switch (_currentPlantActionType) {
      case PlantActionType.watering:
        return PlantWateringForm(
          key: _plantWateringWidgetKey,
          action: widget.action as PlantWateringAction?,
          formKey: GlobalKey<FormState>(),
        );
      case PlantActionType.fertilizing:
        return PlantFertilizingForm(
          key: _plantFertilizingFormKey,
          action: widget.action as PlantFertilizingAction?,
          formKey: GlobalKey<FormState>(),
          fertilizerProvider: widget.fertilizerProvider,
        );
      case PlantActionType.pruning:
        return PlantPruningForm(
          key: _plantPruningFormKey,
          action: widget.action as PlantPruningAction?,
        );
      case PlantActionType.replanting:
        return Container();
      case PlantActionType.training:
        return PlantTrainingForm(
          key: _plantTrainingFormKey,
          action: widget.action as PlantTrainingAction?,
        );
      case PlantActionType.harvesting:
        return PlantHarvestingForm(
          key: _plantHarvestingFormKey,
          formKey: GlobalKey<FormState>(),
          action: widget.action as PlantHarvestingAction?,
        );
      case PlantActionType.measuring:
        return PlantMeasurementForm(
          key: _plantMeasuringFormKey,
          action: widget.action as PlantMeasurementAction?,
          plantMeasurementWidgetKey: _plantHeightMeasurementWidgetKey,
          plantPHMeasurementFormKey: _plantPHMeasurementWidgetKey,
          plantECMeasurementFormKey: _plantECMeasurementWidgetKey,
          plantPPMMeasurementFormKey: _plantPPMMeasurementWidgetKey,
        );
      case PlantActionType.picture:
        final pictureAction = widget.action as PlantPictureAction?;
        return PictureForm(
          key: _plantPictureFormState,
            value: pictureAction,
            allowMultiple: true,
            images: pictureAction == null
                ? []
                : pictureAction.images.map((image) => File(image)).toList(),
            changeCallback: (hasImages, images) {});
      case PlantActionType.death:
      case PlantActionType.other:
        return Container();
    }
  }

  /// The callback for creating a new [PlantAction].
  Future<void> _onPlantActionCreated() async {
    // If no plant is selected, show a snackbar and return.
    if (_currentPlant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.error,
                  color: Colors.red,
                ),
              ),
              Text(
                tr('plants.none'),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final currentPlant = _currentPlant!;
    final PlantAction action;

    // CHeck the current plant action type, check the form validity and create the action.
    if (_currentPlantActionType == PlantActionType.watering) {
      final isValid = _plantWateringWidgetKey.currentState!.isValid;
      if (!isValid) {
        return;
      }
      final watering = _plantWateringWidgetKey.currentState!.watering;
      action = PlantWateringAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
        amount: watering,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }
    if (_currentPlantActionType == PlantActionType.fertilizing) {
      // In case of fertilizing, check if the form has fertilizers.
      final hasFertilizer = _plantFertilizingFormKey.currentState!.hasFertilizers;
      if (!hasFertilizer) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.error,
                    color: Colors.red,
                  ),
                ),
                Text(
                  tr('fertilizers.none'),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
      final isValid = _plantFertilizingFormKey.currentState!.isValid;
      if (!isValid) {
        return;
      }
      final fertilization = _plantFertilizingFormKey.currentState!.fertilization;
      action = PlantFertilizingAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
        fertilization: fertilization,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }
    if (_currentPlantActionType == PlantActionType.pruning) {
      final pruning = _plantPruningFormKey.currentState!.pruningType;
      action = PlantPruningAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
        pruningType: pruning,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }

    if (_currentPlantActionType == PlantActionType.harvesting) {
      final isValid = _plantHarvestingFormKey.currentState!.isValid;
      if (!isValid) {
        return;
      }
      final harvesting = _plantHarvestingFormKey.currentState!.harvest;
      action = PlantHarvestingAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
        amount: harvesting,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }

    if (_currentPlantActionType == PlantActionType.training) {
      final training = _plantTrainingFormKey.currentState!.trainingType;
      action = PlantTrainingAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
        trainingType: training,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }

    // In case of measuring, check the measurement type and create the action.
    if (_currentPlantActionType == PlantActionType.measuring) {
      final currentPlantMeasurementType = _plantMeasuringFormKey.currentState!.measurementType;
      if (currentPlantMeasurementType == PlantMeasurementType.height) {
        final isValid = _plantHeightMeasurementWidgetKey.currentState!.isValid;
        if (!isValid) {
          return;
        }
        final height = _plantHeightMeasurementWidgetKey.currentState!.height;
        action = PlantMeasurementAction(
          id: const Uuid().v4().toString(),
          description: _plantActionDescriptionTextController.text,
          plantId: currentPlant.id,
          type: _currentPlantActionType,
          createdAt: _plantActionDate,
          measurement: PlantMeasurement(
            type: currentPlantMeasurementType,
            measurement: height.toJson(),
          ),
        );
        await widget.actionsProvider
            .addPlantAction(action)
            .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
        return;
      } else if (currentPlantMeasurementType == PlantMeasurementType.pH) {
        final isValid = _plantPHMeasurementWidgetKey.currentState!.isValid;
        if (!isValid) {
          return;
        }
        final ph = _plantPHMeasurementWidgetKey.currentState!.ph;
        action = PlantMeasurementAction(
          id: const Uuid().v4().toString(),
          description: _plantActionDescriptionTextController.text,
          plantId: currentPlant.id,
          type: _currentPlantActionType,
          createdAt: _plantActionDate,
          measurement: PlantMeasurement(
            type: currentPlantMeasurementType,
            measurement: Map<String, dynamic>.from({'ph': ph}),
          ),
        );
        await widget.actionsProvider
            .addPlantAction(action)
            .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
        return;
      } else if (currentPlantMeasurementType == PlantMeasurementType.ec) {
        final isValid = _plantECMeasurementWidgetKey.currentState!.isValid;
        if (!isValid) {
          return;
        }
        final ec = _plantECMeasurementWidgetKey.currentState!.ec;
        action = PlantMeasurementAction(
          id: const Uuid().v4().toString(),
          description: _plantActionDescriptionTextController.text,
          plantId: currentPlant.id,
          type: _currentPlantActionType,
          createdAt: _plantActionDate,
          measurement: PlantMeasurement(
            type: currentPlantMeasurementType,
            measurement: Map<String, dynamic>.from({'ec': ec}),
          ),
        );
        await widget.actionsProvider
            .addPlantAction(action)
            .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
        return;
      } else if (currentPlantMeasurementType == PlantMeasurementType.ppm) {
        final isValid = _plantPPMMeasurementWidgetKey.currentState!.isValid;
        if (!isValid) {
          return;
        }
        final ppm = _plantPPMMeasurementWidgetKey.currentState!.ppm;
        action = PlantMeasurementAction(
          id: const Uuid().v4().toString(),
          description: _plantActionDescriptionTextController.text,
          plantId: currentPlant.id,
          type: _currentPlantActionType,
          createdAt: _plantActionDate,
          measurement: PlantMeasurement(
            type: currentPlantMeasurementType,
            measurement: Map<String, dynamic>.from({'ppm': ppm}),
          ),
        );
        await widget.actionsProvider
            .addPlantAction(action)
            .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
        return;
      } else {
        throw Exception('Unknown plant measurement type: $currentPlantMeasurementType');
      }
    }

    if (_currentPlantActionType == PlantActionType.picture) {
      final images = _plantPictureFormState.currentState!.images;
      if (images.isEmpty) {
        _showImageSelectionMandatorySnackbar();
        return;
      }
      final action = PlantPictureAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
        images: images,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }

    if (_currentPlantActionType == PlantActionType.replanting) {
      action = PlantReplantingAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }

    if (_currentPlantActionType == PlantActionType.death) {
      action = PlantDeathAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }

    if (_currentPlantActionType == PlantActionType.other) {
      action = PlantOtherAction(
        id: const Uuid().v4().toString(),
        description: _plantActionDescriptionTextController.text,
        plantId: currentPlant.id,
        type: _currentPlantActionType,
        createdAt: _plantActionDate,
      );
      await widget.actionsProvider
          .addPlantAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
      return;
    }

    throw Exception('Unknown action type: $_currentPlantActionType');
  }
}

/// A general environment action form.
class EnvironmentActionForm extends StatefulWidget {
  final String title;
  final EnvironmentAction? action;
  final ActionsProvider actionsProvider;
  final EnvironmentsProvider environmentsProvider;
  final Function(bool, List<File>)? changeCallback;

  const EnvironmentActionForm({
    super.key,
    required this.title,
    required this.action,
    required this.actionsProvider,
    required this.environmentsProvider,
    required this.changeCallback,
  });

  @override
  State<EnvironmentActionForm> createState() => _EnvironmentActionFormState();
}

class _EnvironmentActionFormState extends State<EnvironmentActionForm> {
  /// Environment actions widget keys

  final GlobalKey<_EnvironmentMeasurementFormState> _environmentMeasurementFormKey = GlobalKey();
  final GlobalKey<EnvironmentTemperatureMeasurementFormState> _environmentTemperatureWidgetKey =
      GlobalKey();
  final GlobalKey<EnvironmentHumidityMeasurementFormState> _environmentHumidityWidgetKey =
      GlobalKey();
  final GlobalKey<EnvironmentLightDistanceMeasurementFormState> _environmentLightDistanceWidgetKey =
      GlobalKey();
  final GlobalKey<EnvironmentCO2MeasurementFormState> _environmentCO2WidgetKey = GlobalKey();
  final GlobalKey<PictureFormState> _environmentPictureFormState = GlobalKey();

  Environment? _currentEnvironment;
  late EnvironmentActionType _currentEnvironmentActionType = EnvironmentActionType.measurement;
  late final TextEditingController _environmentActionDescriptionTextController =
      TextEditingController();
  DateTime _environmentActionDate = DateTime.now();

  late final EnvironmentAction _initialAction;

  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      _initialAction = widget.action!;
      final action = widget.action!;
      _currentEnvironmentActionType = action.type;
      _environmentActionDate = action.createdAt;
      _environmentActionDescriptionTextController.text = action.description;

      // Postframe callback to update the current environment.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final environments = await widget.environmentsProvider.environments.first;
        final environment = environments[action.environmentId];
        _currentEnvironment = environment;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _environmentActionDescriptionTextController.dispose();
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
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(tr('actions.environments.choose')),
                  if (widget.action == null)
                    StreamBuilder<Map<String, Environment>>(
                      stream: widget.environmentsProvider.environments,
                      builder: (builder, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        final environments = snapshot.data!;
                        if (environments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                              child: Text(tr('environments.none')),
                            ),
                          );
                        }
                        return DropdownButton<Environment>(
                          icon: const Icon(Icons.arrow_downward_sharp),
                          isExpanded: true,
                          items: environments.values
                              .map(
                                (e) => DropdownMenuItem<Environment>(
                                  value: e,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(),
                          onChanged: (Environment? value) => _updateCurrentEnvironment(value),
                          hint: Text(tr('environments.mandatory')),
                          value: _currentEnvironment,
                        );
                      },
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Icon(Icons.calendar_month),
                      Text('${tr('common.select_date')}: '),
                      TextButton(
                        onPressed: () => _selectDate(context, (date) {
                          setState(() {
                            _environmentActionDate = date;
                          });
                        }),
                        child: Text(
                          '${_environmentActionDate.toLocal()}'.split(' ')[0],
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _environmentActionDescriptionTextController,
                    maxLines: null,
                    minLines: 5,
                    decoration: InputDecoration(
                      labelText: tr('common.description'),
                      hintText: tr('actions.environments.description_hint'),
                    ),
                    onChanged: (value) {
                      if (widget.changeCallback != null) {
                        if (widget.action != null) {
                          if (_initialAction.description != value) {
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
          const Divider(),
          if (widget.action == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    DropdownButton<EnvironmentActionType>(
                      icon: const Icon(Icons.arrow_downward_sharp),
                      value: _currentEnvironmentActionType,
                      isExpanded: true,
                      items: EnvironmentActionType.values
                          .map(
                            (action) => DropdownMenuItem<EnvironmentActionType>(
                              value: action,
                              child: Row(
                                children: [
                                  Text(
                                    action.icon,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(action.name),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (EnvironmentActionType? value) =>
                          _updateCurrentEnvironmentActionType(value),
                    ),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _environmentActionForm(),
            ),
          ),
          const Divider(),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async => await _onEnvironmentActionCreated(),
              label: Text(tr('common.save')),
              icon: const Icon(Icons.save),
            ),
          ),
        ],
      ),
    );
  }

  /// The specific environment action form.
  Widget _environmentActionForm() {
    switch (_currentEnvironmentActionType) {
      case EnvironmentActionType.measurement:
        return EnvironmentMeasurementForm(
          key: _environmentMeasurementFormKey,
          action: widget.action as EnvironmentMeasurementAction?,
          environmentTemperatureFormKey: _environmentTemperatureWidgetKey,
          environmentHumidityFormKey: _environmentHumidityWidgetKey,
          environmentLightDistanceFormKey: _environmentLightDistanceWidgetKey,
          environmentCO2FormKey: _environmentCO2WidgetKey,
          changeCallback: (changed, measurement) {
            if (widget.changeCallback != null) {
              if (widget.action != null) {
                if (changed) {
                  widget.changeCallback!(true, []);
                } else {
                  widget.changeCallback!(false, []);
                }
              }
            }
          },
        );
      case EnvironmentActionType.picture:
        final pictureAction = widget.action as EnvironmentPictureAction?;
        return PictureForm(
          key: _environmentPictureFormState,
          value: pictureAction,
          allowMultiple: true,
          images: pictureAction == null
              ? []
              : pictureAction.images.map((image) => File(image)).toList(),
          changeCallback: (hasImages, images) {
            if (widget.changeCallback != null) {
              if (images.isNotEmpty) {
                // Creation case - pictures were
                // taken but now user decided to leave the creation screen.
                if (pictureAction == null && images.isNotEmpty) {
                  widget.changeCallback!(true, images);
                  return;
                }

                // Find the differences between the current images and the new images.
                final newImages =
                    images.where((image) => !pictureAction!.images.contains(image.path));
                if (newImages.isNotEmpty) {
                  widget.changeCallback!(true, newImages.toList());
                  return;
                }

                // First case, action created without pictures, now pictures added
                // and user wants to save the action.
                Function eq = const ListEquality().equals;
                if (eq(pictureAction!.images, images)) {
                  widget.changeCallback!(true, images);
                } else {
                  widget.changeCallback!(false, images);
                }
              } else {
                if (pictureAction == null) {
                  widget.changeCallback!(false, images);
                  return;
                }
                // Second case, action created with pictures, now pictures removed
                // and user wants to save the action.
                if (pictureAction.images.isNotEmpty) {
                  widget.changeCallback!(true, images);
                } else {
                  widget.changeCallback!(false, images);
                }
              }
            }
          },
        );
      case EnvironmentActionType.other:
        return Container();
    }
  }

  /// Update the current environment.
  void _updateCurrentEnvironment(Environment? environment) {
    setState(() {
      _currentEnvironment = environment!;
    });
  }

  /// Update the current environment action type.
  void _updateCurrentEnvironmentActionType(EnvironmentActionType? actionType) {
    setState(() {
      _currentEnvironmentActionType = actionType!;
    });
  }

  /// The callback for creating a new [EnvironmentAction].
  Future<void> _onEnvironmentActionCreated() async {
    if (_currentEnvironment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.error,
                  color: Colors.red,
                ),
              ),
              Text(
                tr('environments.none'),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    final currentEnvironment = _currentEnvironment!;
    if (widget.action == null) {
      if (_currentEnvironmentActionType == EnvironmentActionType.measurement) {
        EnvironmentMeasurement measurement;
        final currentEnvironmentMeasurementType =
            _environmentMeasurementFormKey.currentState!.measurementType;
        if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.temperature) {
          final isValid = _environmentTemperatureWidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final temperature = _environmentTemperatureWidgetKey.currentState!.temperature;
          measurement = EnvironmentMeasurement(
            type: currentEnvironmentMeasurementType,
            measurement: temperature.toJson(),
          );
        } else if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.humidity) {
          final isValid = _environmentHumidityWidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final humidity = _environmentHumidityWidgetKey.currentState!.humidity;
          measurement = EnvironmentMeasurement(
              type: currentEnvironmentMeasurementType,
              measurement: Map<String, dynamic>.from({'humidity': humidity}));
        } else if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.lightDistance) {
          final isValid = _environmentLightDistanceWidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final distance = _environmentLightDistanceWidgetKey.currentState!.distance;
          measurement = EnvironmentMeasurement(
            type: currentEnvironmentMeasurementType,
            measurement: distance.toJson(),
          );
        } else if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.co2) {
          final isValid = _environmentCO2WidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final co2 = _environmentCO2WidgetKey.currentState!.co2;
          measurement = EnvironmentMeasurement(
              type: currentEnvironmentMeasurementType,
              measurement: Map<String, dynamic>.from({'co2': co2}));
        } else {
          throw Exception(
              'Unknown environment measurement type: $currentEnvironmentMeasurementType');
        }
        final action = EnvironmentMeasurementAction(
          id: const Uuid().v4().toString(),
          description: _environmentActionDescriptionTextController.text,
          environmentId: currentEnvironment.id,
          type: _currentEnvironmentActionType,
          measurement: measurement,
          createdAt: _environmentActionDate,
        );
        await widget.actionsProvider
            .addEnvironmentAction(action)
            .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
        return;
      }

      if (_currentEnvironmentActionType == EnvironmentActionType.picture) {
        final images = _environmentPictureFormState.currentState!.images;
        if (images.isEmpty) {
          _showImageSelectionMandatorySnackbar();
          return;
        }
        final action = EnvironmentPictureAction(
          id: const Uuid().v4().toString(),
          description: _environmentActionDescriptionTextController.text,
          environmentId: currentEnvironment.id,
          type: _currentEnvironmentActionType,
          createdAt: _environmentActionDate,
          images: images,
        );
        await widget.actionsProvider
            .addEnvironmentAction(action)
            .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
        return;
      }
      final action = EnvironmentOtherAction(
        id: const Uuid().v4().toString(),
        description: _environmentActionDescriptionTextController.text,
        environmentId: currentEnvironment.id,
        type: _currentEnvironmentActionType,
        createdAt: _environmentActionDate,
      );
      await widget.actionsProvider
          .addEnvironmentAction(action)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
    } else {
      final EnvironmentAction updatedAction;
      if (widget.action is EnvironmentOtherAction) {
        updatedAction = EnvironmentOtherAction(
          id: widget.action!.id,
          description: _environmentActionDescriptionTextController.text,
          environmentId: currentEnvironment.id,
          type: _currentEnvironmentActionType,
          createdAt: _environmentActionDate,
        );
      } else if (widget.action is EnvironmentPictureAction) {
        final images = _environmentPictureFormState.currentState!.images;
        if (images.isEmpty) {
          _showImageSelectionMandatorySnackbar();
          return;
        }
        updatedAction = EnvironmentPictureAction(
          id: widget.action!.id,
          description: _environmentActionDescriptionTextController.text,
          environmentId: currentEnvironment.id,
          type: _currentEnvironmentActionType,
          createdAt: _environmentActionDate,
          images: _environmentPictureFormState.currentState!.images,
        );
      } else if (widget.action is EnvironmentMeasurementAction) {
        EnvironmentMeasurement measurement;
        final currentEnvironmentMeasurementType =
            _environmentMeasurementFormKey.currentState!.measurementType;
        if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.temperature) {
          final isValid = _environmentTemperatureWidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final temperature = _environmentTemperatureWidgetKey.currentState!.temperature;
          measurement = EnvironmentMeasurement(
            type: currentEnvironmentMeasurementType,
            measurement: temperature.toJson(),
          );
        } else if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.humidity) {
          final isValid = _environmentHumidityWidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final humidity = _environmentHumidityWidgetKey.currentState!.humidity;
          measurement = EnvironmentMeasurement(
              type: currentEnvironmentMeasurementType,
              measurement: Map<String, dynamic>.from({'humidity': humidity}));
        } else if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.lightDistance) {
          final isValid = _environmentLightDistanceWidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final distance = _environmentLightDistanceWidgetKey.currentState!.distance;
          measurement = EnvironmentMeasurement(
            type: currentEnvironmentMeasurementType,
            measurement: distance.toJson(),
          );
        } else if (currentEnvironmentMeasurementType == EnvironmentMeasurementType.co2) {
          final isValid = _environmentCO2WidgetKey.currentState!.isValid;
          if (!isValid) {
            return;
          }
          final co2 = _environmentCO2WidgetKey.currentState!.co2;
          measurement = EnvironmentMeasurement(
              type: currentEnvironmentMeasurementType,
              measurement: Map<String, dynamic>.from({'co2': co2}));
        } else {
          throw Exception(
              'Unknown environment measurement type: $currentEnvironmentMeasurementType');
        }

        updatedAction = EnvironmentMeasurementAction(
          id: widget.action!.id,
          description: _environmentActionDescriptionTextController.text,
          environmentId: currentEnvironment.id,
          type: _currentEnvironmentActionType,
          measurement: measurement,
          createdAt: _environmentActionDate,
        );
      } else {
        throw Exception('Unknown environment action type: $_currentEnvironmentActionType');
      }

      await widget.actionsProvider
          .updateEnvironmentAction(updatedAction)
          .whenComplete(() => Navigator.of(context).popUntil((route) => route.isFirst));
    }
  }

  /// Show a snackbar if no images are selected.
  void _showImageSelectionMandatorySnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.error,
                color: Colors.red,
              ),
            ),
            Text(
              tr('common.images_mandatory'),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Open up a date picker to select a date.
  Future<void> _selectDate(BuildContext context, Function(DateTime) dateCallback) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null) {
      dateCallback(picked);
      if (widget.changeCallback != null) {
        if (widget.action != null) {
          widget.changeCallback!(true, []);
        } else {
          widget.changeCallback!(true, []);
        }
      }
    }
  }
}
