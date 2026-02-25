// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prefrence_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppPreferences {

 String get widgetCode;@ColorConverter() Color get backgroundColor; String get appBarTitle;@ColorConverter() Color get appBarBackgroundColor;@ColorConverter() Color get appBarTitleColor;@ColorConverter() Color get appBarBackButtonColor; String get fcmToken; String get userName; String get email; bool get resetLocalStorage;
/// Create a copy of AppPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppPreferencesCopyWith<AppPreferences> get copyWith => _$AppPreferencesCopyWithImpl<AppPreferences>(this as AppPreferences, _$identity);

  /// Serializes this AppPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppPreferences&&(identical(other.widgetCode, widgetCode) || other.widgetCode == widgetCode)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.appBarTitle, appBarTitle) || other.appBarTitle == appBarTitle)&&(identical(other.appBarBackgroundColor, appBarBackgroundColor) || other.appBarBackgroundColor == appBarBackgroundColor)&&(identical(other.appBarTitleColor, appBarTitleColor) || other.appBarTitleColor == appBarTitleColor)&&(identical(other.appBarBackButtonColor, appBarBackButtonColor) || other.appBarBackButtonColor == appBarBackButtonColor)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.email, email) || other.email == email)&&(identical(other.resetLocalStorage, resetLocalStorage) || other.resetLocalStorage == resetLocalStorage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,widgetCode,backgroundColor,appBarTitle,appBarBackgroundColor,appBarTitleColor,appBarBackButtonColor,fcmToken,userName,email,resetLocalStorage);

@override
String toString() {
  return 'AppPreferences(widgetCode: $widgetCode, backgroundColor: $backgroundColor, appBarTitle: $appBarTitle, appBarBackgroundColor: $appBarBackgroundColor, appBarTitleColor: $appBarTitleColor, appBarBackButtonColor: $appBarBackButtonColor, fcmToken: $fcmToken, userName: $userName, email: $email, resetLocalStorage: $resetLocalStorage)';
}


}

/// @nodoc
abstract mixin class $AppPreferencesCopyWith<$Res>  {
  factory $AppPreferencesCopyWith(AppPreferences value, $Res Function(AppPreferences) _then) = _$AppPreferencesCopyWithImpl;
@useResult
$Res call({
 String widgetCode,@ColorConverter() Color backgroundColor, String appBarTitle,@ColorConverter() Color appBarBackgroundColor,@ColorConverter() Color appBarTitleColor,@ColorConverter() Color appBarBackButtonColor, String fcmToken, String userName, String email, bool resetLocalStorage
});




}
/// @nodoc
class _$AppPreferencesCopyWithImpl<$Res>
    implements $AppPreferencesCopyWith<$Res> {
  _$AppPreferencesCopyWithImpl(this._self, this._then);

  final AppPreferences _self;
  final $Res Function(AppPreferences) _then;

/// Create a copy of AppPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? widgetCode = null,Object? backgroundColor = null,Object? appBarTitle = null,Object? appBarBackgroundColor = null,Object? appBarTitleColor = null,Object? appBarBackButtonColor = null,Object? fcmToken = null,Object? userName = null,Object? email = null,Object? resetLocalStorage = null,}) {
  return _then(_self.copyWith(
widgetCode: null == widgetCode ? _self.widgetCode : widgetCode // ignore: cast_nullable_to_non_nullable
as String,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as Color,appBarTitle: null == appBarTitle ? _self.appBarTitle : appBarTitle // ignore: cast_nullable_to_non_nullable
as String,appBarBackgroundColor: null == appBarBackgroundColor ? _self.appBarBackgroundColor : appBarBackgroundColor // ignore: cast_nullable_to_non_nullable
as Color,appBarTitleColor: null == appBarTitleColor ? _self.appBarTitleColor : appBarTitleColor // ignore: cast_nullable_to_non_nullable
as Color,appBarBackButtonColor: null == appBarBackButtonColor ? _self.appBarBackButtonColor : appBarBackButtonColor // ignore: cast_nullable_to_non_nullable
as Color,fcmToken: null == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,resetLocalStorage: null == resetLocalStorage ? _self.resetLocalStorage : resetLocalStorage // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppPreferences].
extension AppPreferencesPatterns on AppPreferences {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppPreferences() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppPreferences value)  $default,){
final _that = this;
switch (_that) {
case _AppPreferences():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _AppPreferences() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String widgetCode, @ColorConverter()  Color backgroundColor,  String appBarTitle, @ColorConverter()  Color appBarBackgroundColor, @ColorConverter()  Color appBarTitleColor, @ColorConverter()  Color appBarBackButtonColor,  String fcmToken,  String userName,  String email,  bool resetLocalStorage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppPreferences() when $default != null:
return $default(_that.widgetCode,_that.backgroundColor,_that.appBarTitle,_that.appBarBackgroundColor,_that.appBarTitleColor,_that.appBarBackButtonColor,_that.fcmToken,_that.userName,_that.email,_that.resetLocalStorage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String widgetCode, @ColorConverter()  Color backgroundColor,  String appBarTitle, @ColorConverter()  Color appBarBackgroundColor, @ColorConverter()  Color appBarTitleColor, @ColorConverter()  Color appBarBackButtonColor,  String fcmToken,  String userName,  String email,  bool resetLocalStorage)  $default,) {final _that = this;
switch (_that) {
case _AppPreferences():
return $default(_that.widgetCode,_that.backgroundColor,_that.appBarTitle,_that.appBarBackgroundColor,_that.appBarTitleColor,_that.appBarBackButtonColor,_that.fcmToken,_that.userName,_that.email,_that.resetLocalStorage);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String widgetCode, @ColorConverter()  Color backgroundColor,  String appBarTitle, @ColorConverter()  Color appBarBackgroundColor, @ColorConverter()  Color appBarTitleColor, @ColorConverter()  Color appBarBackButtonColor,  String fcmToken,  String userName,  String email,  bool resetLocalStorage)?  $default,) {final _that = this;
switch (_that) {
case _AppPreferences() when $default != null:
return $default(_that.widgetCode,_that.backgroundColor,_that.appBarTitle,_that.appBarBackgroundColor,_that.appBarTitleColor,_that.appBarBackButtonColor,_that.fcmToken,_that.userName,_that.email,_that.resetLocalStorage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppPreferences implements AppPreferences {
  const _AppPreferences({this.widgetCode = '', @ColorConverter() this.backgroundColor = const Color(0xFFFFFFFF), this.appBarTitle = 'Chat With Us', @ColorConverter() this.appBarBackgroundColor = const Color(0xFF0000FF), @ColorConverter() this.appBarTitleColor = const Color(0xFFFFFFFF), @ColorConverter() this.appBarBackButtonColor = const Color(0xFFFFFFFF), this.fcmToken = '', this.userName = '', this.email = '', this.resetLocalStorage = false});
  factory _AppPreferences.fromJson(Map<String, dynamic> json) => _$AppPreferencesFromJson(json);

@override@JsonKey() final  String widgetCode;
@override@JsonKey()@ColorConverter() final  Color backgroundColor;
@override@JsonKey() final  String appBarTitle;
@override@JsonKey()@ColorConverter() final  Color appBarBackgroundColor;
@override@JsonKey()@ColorConverter() final  Color appBarTitleColor;
@override@JsonKey()@ColorConverter() final  Color appBarBackButtonColor;
@override@JsonKey() final  String fcmToken;
@override@JsonKey() final  String userName;
@override@JsonKey() final  String email;
@override@JsonKey() final  bool resetLocalStorage;

/// Create a copy of AppPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppPreferencesCopyWith<_AppPreferences> get copyWith => __$AppPreferencesCopyWithImpl<_AppPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppPreferences&&(identical(other.widgetCode, widgetCode) || other.widgetCode == widgetCode)&&(identical(other.backgroundColor, backgroundColor) || other.backgroundColor == backgroundColor)&&(identical(other.appBarTitle, appBarTitle) || other.appBarTitle == appBarTitle)&&(identical(other.appBarBackgroundColor, appBarBackgroundColor) || other.appBarBackgroundColor == appBarBackgroundColor)&&(identical(other.appBarTitleColor, appBarTitleColor) || other.appBarTitleColor == appBarTitleColor)&&(identical(other.appBarBackButtonColor, appBarBackButtonColor) || other.appBarBackButtonColor == appBarBackButtonColor)&&(identical(other.fcmToken, fcmToken) || other.fcmToken == fcmToken)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.email, email) || other.email == email)&&(identical(other.resetLocalStorage, resetLocalStorage) || other.resetLocalStorage == resetLocalStorage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,widgetCode,backgroundColor,appBarTitle,appBarBackgroundColor,appBarTitleColor,appBarBackButtonColor,fcmToken,userName,email,resetLocalStorage);

@override
String toString() {
  return 'AppPreferences(widgetCode: $widgetCode, backgroundColor: $backgroundColor, appBarTitle: $appBarTitle, appBarBackgroundColor: $appBarBackgroundColor, appBarTitleColor: $appBarTitleColor, appBarBackButtonColor: $appBarBackButtonColor, fcmToken: $fcmToken, userName: $userName, email: $email, resetLocalStorage: $resetLocalStorage)';
}


}

/// @nodoc
abstract mixin class _$AppPreferencesCopyWith<$Res> implements $AppPreferencesCopyWith<$Res> {
  factory _$AppPreferencesCopyWith(_AppPreferences value, $Res Function(_AppPreferences) _then) = __$AppPreferencesCopyWithImpl;
@override @useResult
$Res call({
 String widgetCode,@ColorConverter() Color backgroundColor, String appBarTitle,@ColorConverter() Color appBarBackgroundColor,@ColorConverter() Color appBarTitleColor,@ColorConverter() Color appBarBackButtonColor, String fcmToken, String userName, String email, bool resetLocalStorage
});




}
/// @nodoc
class __$AppPreferencesCopyWithImpl<$Res>
    implements _$AppPreferencesCopyWith<$Res> {
  __$AppPreferencesCopyWithImpl(this._self, this._then);

  final _AppPreferences _self;
  final $Res Function(_AppPreferences) _then;

/// Create a copy of AppPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? widgetCode = null,Object? backgroundColor = null,Object? appBarTitle = null,Object? appBarBackgroundColor = null,Object? appBarTitleColor = null,Object? appBarBackButtonColor = null,Object? fcmToken = null,Object? userName = null,Object? email = null,Object? resetLocalStorage = null,}) {
  return _then(_AppPreferences(
widgetCode: null == widgetCode ? _self.widgetCode : widgetCode // ignore: cast_nullable_to_non_nullable
as String,backgroundColor: null == backgroundColor ? _self.backgroundColor : backgroundColor // ignore: cast_nullable_to_non_nullable
as Color,appBarTitle: null == appBarTitle ? _self.appBarTitle : appBarTitle // ignore: cast_nullable_to_non_nullable
as String,appBarBackgroundColor: null == appBarBackgroundColor ? _self.appBarBackgroundColor : appBarBackgroundColor // ignore: cast_nullable_to_non_nullable
as Color,appBarTitleColor: null == appBarTitleColor ? _self.appBarTitleColor : appBarTitleColor // ignore: cast_nullable_to_non_nullable
as Color,appBarBackButtonColor: null == appBarBackButtonColor ? _self.appBarBackButtonColor : appBarBackButtonColor // ignore: cast_nullable_to_non_nullable
as Color,fcmToken: null == fcmToken ? _self.fcmToken : fcmToken // ignore: cast_nullable_to_non_nullable
as String,userName: null == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,resetLocalStorage: null == resetLocalStorage ? _self.resetLocalStorage : resetLocalStorage // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
