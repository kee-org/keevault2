class Argon2Params {
  final int iterations;
  final int memory;
  final int version;
  final int parallelism;
  final int saltLength;
  final Argon2StrengthCategory strength;
  Argon2Params({
    required this.iterations,
    required this.memory,
    required this.version,
    required this.parallelism,
    required this.saltLength,
    required this.strength,
  });

  factory Argon2Params.forStrength(Argon2StrengthCategory strength) {
    const saltLength = 32;
    const version = 0x13;
    const parallelism = 4;
    if (strength == Argon2StrengthCategory.veryHigh) {
      return Argon2Params(
        iterations: 1,
        memory: 3 * 1024 * 1024,
        version: version,
        parallelism: parallelism,
        saltLength: saltLength,
        strength: Argon2StrengthCategory.veryHigh,
      );
    }
    if (strength == Argon2StrengthCategory.high) {
      return Argon2Params(
        iterations: 1,
        memory: 10 * 1024 * 1024,
        version: version,
        parallelism: parallelism,
        saltLength: saltLength,
        strength: Argon2StrengthCategory.high,
      );
    }
    if (strength == Argon2StrengthCategory.medium) {
      return Argon2Params(
        iterations: 1,
        memory: 25 * 1024 * 1024,
        version: version,
        parallelism: parallelism,
        saltLength: saltLength,
        strength: Argon2StrengthCategory.medium,
      );
    }
    if (strength == Argon2StrengthCategory.low) {
      return Argon2Params(
        iterations: 1,
        memory: 50 * 1024 * 1024,
        version: version,
        parallelism: parallelism,
        saltLength: saltLength,
        strength: Argon2StrengthCategory.low,
      );
    }
    return Argon2Params(
      iterations: 2,
      memory: 75 * 1024 * 1024,
      version: version,
      parallelism: parallelism,
      saltLength: saltLength,
      strength: Argon2StrengthCategory.veryLow,
    );
  }

  Argon2Params copyWith({
    int? iterations,
    int? memory,
    int? version,
    int? parallelism,
    int? saltLength,
    Argon2StrengthCategory? strength,
  }) {
    return Argon2Params(
      iterations: iterations ?? this.iterations,
      memory: memory ?? this.memory,
      version: version ?? this.version,
      parallelism: parallelism ?? this.parallelism,
      saltLength: saltLength ?? this.saltLength,
      strength: strength ?? this.strength,
    );
  }

  @override
  String toString() {
    return 'Argon2Params(iterations: $iterations, memory: $memory, version: $version, parallelism: $parallelism, saltLength: $saltLength, strength: $strength)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Argon2Params &&
        other.iterations == iterations &&
        other.memory == memory &&
        other.version == version &&
        other.parallelism == parallelism &&
        other.saltLength == saltLength &&
        other.strength == strength;
  }

  @override
  int get hashCode {
    return iterations.hashCode ^
        memory.hashCode ^
        version.hashCode ^
        parallelism.hashCode ^
        saltLength.hashCode ^
        strength.hashCode;
  }
}

enum Argon2StrengthCategory { veryLow, low, medium, high, veryHigh }
