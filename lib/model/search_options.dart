class SearchOptions {
  final bool username;
  final bool other;
  final bool urls;
  final bool password;
  final bool otherProtected;
  final bool notes;
  final bool regex;
  final bool history;
  final bool title;
  final bool caseSensitive;

  SearchOptions({
    this.username = true,
    this.other = true,
    this.urls = true,
    this.password = false,
    this.otherProtected = false,
    this.notes = true,
    this.regex = false,
    this.history = false,
    this.title = true,
    this.caseSensitive = false,
  });

  SearchOptions copyWith({
    bool? username,
    bool? other,
    bool? urls,
    bool? password,
    bool? otherProtected,
    bool? notes,
    bool? regex,
    bool? history,
    bool? title,
    bool? caseSensitive,
  }) {
    return SearchOptions(
      username: username ?? this.username,
      other: other ?? this.other,
      urls: urls ?? this.urls,
      password: password ?? this.password,
      otherProtected: otherProtected ?? this.otherProtected,
      notes: notes ?? this.notes,
      regex: regex ?? this.regex,
      history: history ?? this.history,
      title: title ?? this.title,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SearchOptions &&
        other.username == username &&
        other.other == this.other &&
        other.urls == urls &&
        other.password == password &&
        other.otherProtected == otherProtected &&
        other.notes == notes &&
        other.regex == regex &&
        other.history == history &&
        other.title == title &&
        other.caseSensitive == caseSensitive;
  }

  @override
  int get hashCode {
    return username.hashCode ^
        other.hashCode ^
        urls.hashCode ^
        password.hashCode ^
        otherProtected.hashCode ^
        notes.hashCode ^
        regex.hashCode ^
        history.hashCode ^
        title.hashCode ^
        caseSensitive.hashCode;
  }
}
