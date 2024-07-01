import 'package:json_annotation/json_annotation.dart';

part 'temperature.g.dart';

/// A temperature unit.
enum TemperatureUnit {
  celsius,
  fahrenheit,
}

/// An extension for the [TemperatureUnit] enum.
extension TemperatureUnitExtension on TemperatureUnit {
  /// The name of the temperature unit.
  String get name {
    switch (this) {
      case TemperatureUnit.celsius:
        return 'Celsius';
      case TemperatureUnit.fahrenheit:
        return 'Fahrenheit';
    }
  }

  /// The symbol of the temperature unit.
  String get symbol {
    switch (this) {
      case TemperatureUnit.celsius:
        return '°C';
      case TemperatureUnit.fahrenheit:
        return '°F';
    }
  }
}

/// A temperature.
@JsonSerializable()
class Temperature {
  final double value;
  final TemperatureUnit temperatureUnit;

  Temperature({
    required this.value,
    required this.temperatureUnit,
  });

  factory Temperature.fromJson(Map<String, dynamic> json) => _$TemperatureFromJson(json);

  Map<String, dynamic> toJson() => _$TemperatureToJson(this);
}
