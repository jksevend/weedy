import 'package:json_annotation/json_annotation.dart';

part 'measurement.g.dart';

/// A measurement unit.
enum MeasurementUnit {
  cm,
  m,
}

extension MeasurementUnitExtension on MeasurementUnit {
  /// The name of the measurement unit.
  String get name {
    switch (this) {
      case MeasurementUnit.cm:
        return 'Centimeters';
      case MeasurementUnit.m:
        return 'Meters';
    }
  }

  /// The symbol of the measurement unit.
  String get symbol {
    switch (this) {
      case MeasurementUnit.cm:
        return 'cm';
      case MeasurementUnit.m:
        return 'm';
    }
  }
}

/// A measurement amount.
@JsonSerializable()
class MeasurementAmount {
  final double value;
  final MeasurementUnit measurementUnit;

  MeasurementAmount({required this.value, required this.measurementUnit});

  factory MeasurementAmount.fromJson(Map<String, dynamic> json) =>
      _$MeasurementAmountFromJson(json);

  Map<String, dynamic> toJson() => _$MeasurementAmountToJson(this);
}
