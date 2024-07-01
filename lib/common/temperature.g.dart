// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'temperature.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Temperature _$TemperatureFromJson(Map<String, dynamic> json) => Temperature(
      value: (json['value'] as num).toDouble(),
      temperatureUnit: $enumDecode(_$TemperatureUnitEnumMap, json['temperatureUnit']),
    );

Map<String, dynamic> _$TemperatureToJson(Temperature instance) => <String, dynamic>{
      'value': instance.value,
      'temperatureUnit': _$TemperatureUnitEnumMap[instance.temperatureUnit]!,
    };

const _$TemperatureUnitEnumMap = {
  TemperatureUnit.celsius: 'celsius',
  TemperatureUnit.fahrenheit: 'fahrenheit',
};
