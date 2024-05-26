import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

enum LifeCycleState {
  germination,
  seedling,
  vegetative,
  flowering,
  drying,
  curing,
}

@JsonSerializable()
class Plant {
  final String id;
  final String name;
  final String description;
  final LifeCycleState lifeCycleState;

  final String environmentId;

  Plant({
    required this.id,
    required this.name,
    required this.description,
    required this.lifeCycleState,
    required this.environmentId,
  });

  factory Plant.fromJson(Map<String, dynamic> json) => _$PlantFromJson(json);

  Map<String, dynamic> toJson() => _$PlantToJson(this);
}
