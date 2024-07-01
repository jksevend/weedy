// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'measurement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MeasurementAmount _$MeasurementAmountFromJson(Map<String, dynamic> json) => MeasurementAmount(
      value: (json['value'] as num).toDouble(),
      measurementUnit: $enumDecode(_$MeasurementUnitEnumMap, json['measurementUnit']),
    );

Map<String, dynamic> _$MeasurementAmountToJson(MeasurementAmount instance) => <String, dynamic>{
      'value': instance.value,
      'measurementUnit': _$MeasurementUnitEnumMap[instance.measurementUnit]!,
    };

const _$MeasurementUnitEnumMap = {
  MeasurementUnit.cm: 'cm',
  MeasurementUnit.m: 'm',
};
