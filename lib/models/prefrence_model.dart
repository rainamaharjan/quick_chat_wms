import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'prefrence_model.freezed.dart';
part 'prefrence_model.g.dart';

// Custom converter to handle Flutter Colors in JSON
class ColorConverter implements JsonConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromJson(int json) => Color(json);

  @override
  int toJson(Color object) => object.value;
}

@freezed
abstract class AppPreferences with _$AppPreferences {
  const factory AppPreferences({
    @Default('') String widgetCode,
    @ColorConverter() @Default(Color(0xFFFFFFFF)) Color backgroundColor,
    @Default('Chat With Us') String appBarTitle,
    @ColorConverter() @Default(Color(0xFF0000FF)) Color appBarBackgroundColor,
    @ColorConverter() @Default(Color(0xFFFFFFFF)) Color appBarTitleColor,
    @ColorConverter() @Default(Color(0xFFFFFFFF)) Color appBarBackButtonColor,
    @Default('') String fcmToken,
    @Default('') String userName,
    @Default('') String email,
    @Default(false) bool resetLocalStorage,
  }) = _AppPreferences;

  factory AppPreferences.fromJson(Map<String, dynamic> json) =>
      _$AppPreferencesFromJson(json);
}
