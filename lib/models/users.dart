class User {
  final String id;
  final String name;
  final String email;
  final String? token;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.token,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? token,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      token: token ?? this.token,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
    };
  }
}