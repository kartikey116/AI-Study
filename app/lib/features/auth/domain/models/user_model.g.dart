// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      profile: json['profile'] == null
          ? null
          : ProfileModel.fromJson(json['profile'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'profile': instance.profile,
    };

_ProfileModel _$ProfileModelFromJson(Map<String, dynamic> json) =>
    _ProfileModel(
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$ProfileModelToJson(_ProfileModel instance) =>
    <String, dynamic>{
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'avatarUrl': instance.avatarUrl,
    };
