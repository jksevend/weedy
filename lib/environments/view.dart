import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:weedy/actions/provider.dart';
import 'package:weedy/actions/view.dart';
import 'package:weedy/common/measurement.dart';
import 'package:weedy/common/validators.dart';
import 'package:weedy/environments/model.dart';
import 'package:weedy/environments/provider.dart';
import 'package:weedy/environments/sheet.dart';
import 'package:weedy/plants/model.dart';
import 'package:weedy/plants/provider.dart';

/// A widget that shows an overview of the environments.
class EnvironmentOverview extends StatefulWidget {
  final EnvironmentsProvider environmentsProvider;
  final PlantsProvider plantsProvider;
  final ActionsProvider actionsProvider;

  const EnvironmentOverview({
    super.key,
    required this.environmentsProvider,
    required this.plantsProvider,
    required this.actionsProvider,
  });

  @override
  State<EnvironmentOverview> createState() => _EnvironmentOverviewState();
}

class _EnvironmentOverviewState extends State<EnvironmentOverview> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: CombineLatestStream.list([
        widget.environmentsProvider.environments,
        widget.plantsProvider.plants,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final environments = snapshot.data![0] as Map<String, Environment>;
        final plants = snapshot.data![1] as Map<String, Plant>;
        if (environments.isEmpty) {
          return Center(
            child: Text(tr('environments.none')),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            shrinkWrap: true,
            children: environments.values.map(
              (environment) {
                final plantsInEnvironment =
                    plants.values.where((plant) => plant.environmentId == environment.id).toList();
                return LayoutBuilder(builder: (context, constraints) {
                  return Card(
                    child: Column(
                      children: [
                        environment.bannerImagePath == ''
                            ? Placeholder(
                                fallbackHeight: constraints.maxWidth / 2,
                                fallbackWidth: constraints.maxWidth,
                              )
                            : GestureDetector(
                                child: Image.file(
                                  height: constraints.maxWidth / 2,
                                  width: constraints.maxWidth,
                                  fit: BoxFit.fitWidth,
                                  File(environment.bannerImagePath),
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
                                              File(environment.bannerImagePath),
                                            ),
                                          ),
                                        );
                                      });
                                },
                              ),
                        ListTile(
                          leading: Text(
                            environment.type.icon,
                            style: const TextStyle(fontSize: 22.0),
                          ),
                          title: Text(environment.name),
                          subtitle: Text(environment.description),
                          onTap: () async {
                            debugPrint(
                                'Navigate to the environment detail view for ${environment.name}');
                            await showEnvironmentDetailSheet(
                                context,
                                environment,
                                plantsInEnvironment,
                                widget.environmentsProvider,
                                widget.plantsProvider,
                                widget.actionsProvider);
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.timeline),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => EnvironmentActionOverview(
                                        environment: environment,
                                        actionsProvider: widget.actionsProvider,
                                      )));
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                });
              },
            ).toList(),
          ),
        );
      },
    );
  }
}

/// A reusable form for creating and editing environments.
class EnvironmentForm extends StatefulWidget {
  final Environment? environment;
  final GlobalKey<FormState> formKey;
  final String title;
  final EnvironmentsProvider environmentsProvider;

  const EnvironmentForm({
    super.key,
    required this.formKey,
    required this.title,
    required this.environmentsProvider,
    this.environment,
  });

  @override
  State<EnvironmentForm> createState() => _EnvironmentFormState();
}

class _EnvironmentFormState extends State<EnvironmentForm> {
  final GlobalKey<PictureFormState> _pictureFormKey = GlobalKey<PictureFormState>();

  final _wattFormKey = GlobalKey<FormState>();
  final _dimensionFormKey = GlobalKey<FormState>();

  final _nameFocus = FocusNode();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _wattController;
  late final TextEditingController _widthController;
  late final TextEditingController _lengthController;
  late final TextEditingController _heightController;

  // The first element is for indoor, the second for outdoor.
  late List<bool> _selectedEnvironmentType;
  late double _currentLightHours;
  late LightType _currentLightType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.environment?.name);
    _descriptionController = TextEditingController(text: widget.environment?.description);
    _wattController = TextEditingController(
        text: widget.environment != null && widget.environment!.lightDetails.lights.isNotEmpty
            ? widget.environment!.lightDetails.lights.first.watt.toString()
            : '0.0');
    _widthController = TextEditingController(
        text: widget.environment != null
            ? widget.environment!.dimension?.width.value.toString()
            : '0.0');
    _lengthController = TextEditingController(
        text: widget.environment != null
            ? widget.environment!.dimension?.length.value.toString()
            : '0.0');
    _heightController = TextEditingController(
        text: widget.environment != null
            ? widget.environment!.dimension?.height.value.toString()
            : '0.0');
    _selectedEnvironmentType = widget.environment == null
        ? [true, false]
        : [
            widget.environment!.type == EnvironmentType.indoor,
            widget.environment!.type == EnvironmentType.outdoor
          ];
    _currentLightHours = widget.environment?.lightDetails.lightHours.toDouble() ?? 12;
    _currentLightType = widget.environment == null
        ? LightType.led
        : widget.environment!.lightDetails.lights.isEmpty
            ? LightType.led
            : widget.environment!.lightDetails.lights.first.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _wattController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Padding(
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
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: tr('common.name'),
                            hintText: tr('environments.name_hint'),
                          ),
                          focusNode: _nameFocus,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              FocusScope.of(context).requestFocus(_nameFocus);
                              return tr('common.name_mandatory');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: null,
                          minLines: 5,
                          decoration: InputDecoration(
                            labelText: tr('common.description'),
                            hintText: tr('environments.description_hint'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                    '${tr('environments.choose_type')} ${_selectedEnvironmentType[0] ? tr('common.indoor') : tr('common.outdoor')}'),
                const SizedBox(height: 16.0),
                ToggleButtons(
                    isSelected: _selectedEnvironmentType,
                    onPressed: (int index) => _onToggleEnvironmentType(index),
                    children: EnvironmentType.values
                        .map(
                          (environment) => Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Text(environment.icon),
                                const SizedBox(width: 8.0),
                                Text(environment.name),
                              ],
                            ),
                          ),
                        )
                        .toList()),
                const SizedBox(height: 16.0),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(
                            '${tr('environments.choose_light_hours')}: ${_currentLightHours.round()}'),
                        Row(
                          children: [
                            const Icon(Icons.nightlight_round_outlined),
                            Expanded(
                              child: Slider(
                                max: 24,
                                divisions: 24,
                                label: _currentLightHours.round().toString(),
                                value: _currentLightHours,
                                onChanged: (double value) => _updateCurrentLightHours(value),
                              ),
                            ),
                            const Icon(Icons.wb_sunny),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Text(tr('common.banner_image')),
                        PictureForm(
                          key: _pictureFormKey,
                          allowMultiple: false,
                          images: widget.environment == null
                              ? []
                              : widget.environment!.bannerImagePath.isEmpty
                                  ? []
                                  : [File(widget.environment!.bannerImagePath)],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedEnvironmentType[0])
                  Column(
                    children: [
                      const SizedBox(height: 16.0),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(tr('environments.choose_light_details')),
                              const SizedBox(height: 16.0),
                              DropdownButton<LightType>(
                                icon: const Icon(Icons.arrow_downward_sharp),
                                isExpanded: true,
                                items: LightType.values
                                    .map(
                                      (e) => DropdownMenuItem<LightType>(
                                        value: e,
                                        child: Text(e.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (LightType? value) => _updateCurrentLightType(value!),
                                value: _currentLightType,
                              ),
                              const SizedBox(height: 16.0),
                              Form(
                                key: _wattFormKey,
                                child: TextFormField(
                                  controller: _wattController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: tr('common.watt'),
                                    hintText: tr('common.watt_hint'),
                                    suffixIcon: Icon(Icons.electrical_services),
                                  ),
                                  validator: (value) => validateInput(value, isDouble: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Dimension
                      const SizedBox(height: 16.0),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Form(
                            key: _dimensionFormKey,
                            child: Column(
                              children: [
                                Text(tr('common.dimension_hint')),
                                const SizedBox(height: 16.0),
                                TextFormField(
                                    controller: _widthController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: tr('common.width'),
                                      hintText: tr('common.width_hint'),
                                    ),
                                    validator: (value) => validateInput(value, isDouble: true)),
                                const SizedBox(height: 16.0),
                                TextFormField(
                                    controller: _lengthController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: tr('common.length'),
                                      hintText: tr('common.length_hint'),
                                    ),
                                    validator: (value) => validateInput(value, isDouble: true)),
                                const SizedBox(height: 16.0),
                                TextFormField(
                                    controller: _heightController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: tr('common.height'),
                                      hintText: tr('common.height_hint'),
                                    ),
                                    validator: (value) => validateInput(value, isDouble: true)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                // Submit button
                const SizedBox(height: 16.0),
                OutlinedButton.icon(
                  onPressed: () async => await _onEnvironmentSaved(),
                  label: Text(tr('common.save')),
                  icon: const Icon(Icons.arrow_right),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Updates the current light hours.
  void _updateCurrentLightHours(double value) {
    setState(() {
      _currentLightHours = value;
    });
  }

  /// Updates the current light type.
  void _updateCurrentLightType(LightType value) {
    setState(() {
      _currentLightType = value;
    });
  }

  /// Toggles the environment type.
  void _onToggleEnvironmentType(int index) {
    setState(() {
      for (int i = 0; i < _selectedEnvironmentType.length; i++) {
        _selectedEnvironmentType[i] = i == index;
      }
    });
  }

  /// Saves the environment.
  Future<void> _onEnvironmentSaved() async {
    if (widget.formKey.currentState!.validate()) {
      Environment environment;
      if (widget.environment == null) {
        if (_selectedEnvironmentType[0]) {
          if (_wattFormKey.currentState!.validate() && _dimensionFormKey.currentState!.validate()) {
            environment = Environment(
              id: const Uuid().v4().toString(),
              name: _nameController.text,
              description: _descriptionController.text,
              type: _selectedEnvironmentType[0] ? EnvironmentType.indoor : EnvironmentType.outdoor,
              lightDetails: LightDetails(
                lightHours: _currentLightHours.toInt(),
                lights: [
                  Light(
                    id: const Uuid().v4().toString(),
                    type: _currentLightType,
                    watt: double.parse(_wattController.text),
                  ),
                ],
              ),
              dimension: Dimension(
                  width: MeasurementAmount(
                    value: double.parse(_widthController.text),
                    unit: MeasurementUnit.cm,
                  ),
                  length: MeasurementAmount(
                    value: double.parse(_lengthController.text),
                    unit: MeasurementUnit.cm,
                  ),
                  height: MeasurementAmount(
                    value: double.parse(_heightController.text),
                    unit: MeasurementUnit.cm,
                  )),
              bannerImagePath: _pictureFormKey.currentState!.images.isEmpty
                  ? ''
                  : _pictureFormKey.currentState!.images.first,
            );
          } else {
            return;
          }
        } else {
          environment = Environment(
            id: const Uuid().v4().toString(),
            name: _nameController.text,
            description: _descriptionController.text,
            type: _selectedEnvironmentType[0] ? EnvironmentType.indoor : EnvironmentType.outdoor,
            lightDetails: LightDetails(
              lightHours: _currentLightHours.toInt(),
              lights: [],
            ),
            dimension: null,
            bannerImagePath: _pictureFormKey.currentState!.images.isEmpty
                ? ''
                : _pictureFormKey.currentState!.images.first,
          );
        }
        await widget.environmentsProvider.addEnvironment(environment).whenComplete(() {
          Navigator.of(context).pop();
        });
      } else {
        if (_selectedEnvironmentType[0]) {
          environment = widget.environment!.copyWith(
            name: _nameController.text,
            description: _descriptionController.text,
            type: _selectedEnvironmentType[0] ? EnvironmentType.indoor : EnvironmentType.outdoor,
            lightDetails: LightDetails(
              lightHours: _currentLightHours.toInt(),
              lights: [
                Light(
                  id: const Uuid().v4().toString(),
                  type: _currentLightType,
                  watt: double.parse(_wattController.text),
                ),
              ],
            ),
            dimension: Dimension(
                width: MeasurementAmount(
                  value: double.parse(_widthController.text),
                  unit: MeasurementUnit.cm,
                ),
                length: MeasurementAmount(
                  value: double.parse(_lengthController.text),
                  unit: MeasurementUnit.cm,
                ),
                height: MeasurementAmount(
                  value: double.parse(_heightController.text),
                  unit: MeasurementUnit.cm,
                )),
            bannerImagePath: _pictureFormKey.currentState!.images.isEmpty
                ? ''
                : _pictureFormKey.currentState!.images.first,
          );
        } else {
          environment = widget.environment!.copyWith(
            name: _nameController.text,
            description: _descriptionController.text,
            type: _selectedEnvironmentType[0] ? EnvironmentType.indoor : EnvironmentType.outdoor,
            lightDetails: LightDetails(
              lightHours: _currentLightHours.toInt(),
              lights: [],
            ),
            dimension: null,
            bannerImagePath: _pictureFormKey.currentState!.images.isEmpty
                ? ''
                : _pictureFormKey.currentState!.images.first,
          );
        }
        await widget.environmentsProvider.updateEnvironment(environment).whenComplete(() {
          Navigator.of(context).pop(environment);
        });
      }
    }
  }
}

/// A view that allows the user to create a new environment.
class CreateEnvironmentView extends StatelessWidget {
  final EnvironmentsProvider environmentsProvider;

  CreateEnvironmentView({super.key, required this.environmentsProvider});

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return EnvironmentForm(
      formKey: _formKey,
      title: tr('environments.create'),
      environment: null,
      environmentsProvider: environmentsProvider,
    );
  }
}

/// A view that allows the user to edit an existing environment.
class EditEnvironmentView extends StatelessWidget {
  final Environment environment;
  final EnvironmentsProvider environmentsProvider;

  EditEnvironmentView({super.key, required this.environment, required this.environmentsProvider});

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final editTranslation = tr('environments.edit');
    return EnvironmentForm(
      formKey: _formKey,
      title: '$editTranslation ${environment.name}',
      environment: environment,
      environmentsProvider: environmentsProvider,
    );
  }
}
