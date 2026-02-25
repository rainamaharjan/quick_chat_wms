// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefrence_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppPreferences _$AppPreferencesFromJson(Map<String, dynamic> json) =>
    _AppPreferences(
      widgetCode: json['widgetCode'] as String? ?? '',
      backgroundColor: json['backgroundColor'] == null
          ? const Color(0xFFFFFFFF)
          : const ColorConverter().fromJson(
              (json['backgroundColor'] as num).toInt(),
            ),
      appBarTitle: json['appBarTitle'] as String? ?? 'Chat With Us',
      appBarBackgroundColor: json['appBarBackgroundColor'] == null
          ? const Color(0xFF0000FF)
          : const ColorConverter().fromJson(
              (json['appBarBackgroundColor'] as num).toInt(),
            ),
      appBarTitleColor: json['appBarTitleColor'] == null
          ? const Color(0xFFFFFFFF)
          : const ColorConverter().fromJson(
              (json['appBarTitleColor'] as num).toInt(),
            ),
      appBarBackButtonColor: json['appBarBackButtonColor'] == null
          ? const Color(0xFFFFFFFF)
          : const ColorConverter().fromJson(
              (json['appBarBackButtonColor'] as num).toInt(),
            ),
      fcmToken: json['fcmToken'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      resetLocalStorage: json['resetLocalStorage'] as bool? ?? false,
    );

Map<String, dynamic> _$AppPreferencesToJson(
  _AppPreferences instance,
) => <String, dynamic>{
  'widgetCode': instance.widgetCode,
  'backgroundColor': const ColorConverter().toJson(instance.backgroundColor),
  'appBarTitle': instance.appBarTitle,
  'appBarBackgroundColor': const ColorConverter().toJson(
    instance.appBarBackgroundColor,
  ),
  'appBarTitleColor': const ColorConverter().toJson(instance.appBarTitleColor),
  'appBarBackButtonColor': const ColorConverter().toJson(
    instance.appBarBackButtonColor,
  ),
  'fcmToken': instance.fcmToken,
  'userName': instance.userName,
  'email': instance.email,
  'resetLocalStorage': instance.resetLocalStorage,
};
