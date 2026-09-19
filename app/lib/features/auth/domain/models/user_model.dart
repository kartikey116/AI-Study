class UserModel {
  final String id;
  final String email;
  final ProfileModel? profile;

  const UserModel({
    required this.id,
    required this.email,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      profile: json['profile'] != null
          ? ProfileModel.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'profile': profile?.toJson(),
    };
  }
}

class ProfileModel {
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const ProfileModel({
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'avatarUrl': avatarUrl,
    };
  }
}
