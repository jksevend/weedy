import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:weedy/actions/model.dart' as weedy;
import 'package:weedy/common/filestore.dart';

/// A provider for actions.
///
/// This provider manages the actions and provides them as a stream.
/// It also allows adding, removing, and updating actions.
class ActionsProvider with ChangeNotifier {
  /// The file name of the actions.
  static const String _fileName = 'actions.txt';

  /// The standard actions.
  static final weedy.Actions _standardActions = weedy.Actions.standard();

  /// The plant actions as a stream.
  final BehaviorSubject<List<weedy.PlantAction>> _plantActions = BehaviorSubject();

  /// The environment actions as a stream.
  final BehaviorSubject<List<weedy.EnvironmentAction>> _environmentActions = BehaviorSubject();

  /// The plant actions as a stream.
  Stream<List<weedy.PlantAction>> get plantActions => _plantActions.stream;

  /// The environment actions as a stream.
  Stream<List<weedy.EnvironmentAction>> get environmentActions => _environmentActions.stream;

  /// The actions.
  late weedy.Actions _actions;

  /// Creates a new actions provider.
  ActionsProvider() {
    _initialize();
  }

  /// Initializes the provider.
  void _initialize() async {
    final params = await getEncryptionParams();
    final actionsJson = await readJsonFile(
      name: _fileName,
      preset: json.encode(_standardActions.toJson()),
      params: params,
    );

    _actions = weedy.Actions.fromJson(actionsJson);
    await _setPlantActions(_actions.plantActions, params);
    await _setEnvironmentActions(_actions.environmentActions, params);
  }

  /// Sets the [plantActions].
  Future<void> _setPlantActions(
    List<weedy.PlantAction> plantActions,
    EncryptionParams params,
  ) async {
    _actions.plantActions = plantActions;
    await writeJsonFile(
      name: _fileName,
      content: _actions.toJson(),
      params: params,
    );
    _plantActions.sink.add(plantActions);
  }

  /// Sets the [environmentActions].
  Future<void> _setEnvironmentActions(
    List<weedy.EnvironmentAction> environmentActions,
    EncryptionParams params,
  ) async {
    _actions.environmentActions = environmentActions;
    await writeJsonFile(
      name: _fileName,
      content: _actions.toJson(),
      params: params,
    );
    _environmentActions.sink.add(environmentActions);
  }

  /// Adds a [plantAction].
  Future<void> addPlantAction(weedy.PlantAction plantAction) async {
    final params = await getEncryptionParams();
    final plantActions = await _plantActions.first;
    plantActions.add(plantAction);
    await _setPlantActions(plantActions, params);
  }

  /// Adds an [environmentAction].
  Future<void> addEnvironmentAction(weedy.EnvironmentAction environmentAction) async {
    final params = await getEncryptionParams();
    final environmentActions = await _environmentActions.first;
    environmentActions.add(environmentAction);
    await _setEnvironmentActions(environmentActions, params);
  }

  Future<void> updateEnvironmentAction(weedy.EnvironmentAction environmentAction) async {
    final params = await getEncryptionParams();
    final environmentActions = await _environmentActions.first;
    final index = environmentActions.indexWhere((action) => action.id == environmentAction.id);
    if (index != -1) {
      environmentActions[index] = environmentAction;
      await _setEnvironmentActions(environmentActions, params);
    }
  }

  /// Deletes a plant action by its [plantId].
  Future<void> removeActionsForPlant(String plantId) async {
    final params = await getEncryptionParams();
    final plantActions = await _plantActions.first;
    final actions = plantActions.where((action) => action.plantId != plantId).toList();
    await _setPlantActions(actions, params);
  }

  /// Deletes an environment action by its [environmentId].
  Future<void> removeActionsForEnvironment(String environmentId) async {
    final params = await getEncryptionParams();
    final environmentActions = await _environmentActions.first;
    final actions =
        environmentActions.where((action) => action.environmentId != environmentId).toList();
    await _setEnvironmentActions(actions, params);
  }

  /// Deletes a plant action by its [id].
  Future<void> deletePlantAction(weedy.PlantAction plantAction) async {
    final params = await getEncryptionParams();
    final plantActions = await _plantActions.first;
    plantActions.remove(plantAction);
    await _setPlantActions(plantActions, params);
  }

  /// Deletes an environment action by its [id].
  Future<void> deleteEnvironmentAction(weedy.EnvironmentAction environmentAction) async {
    final params = await getEncryptionParams();
    final environmentActions = await _environmentActions.first;
    environmentActions.remove(environmentAction);
    await _setEnvironmentActions(environmentActions, params);
  }
}
