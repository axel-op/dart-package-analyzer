extension MapExtension on Map<String, dynamic> {
  bool containsNonNull(String key) => this[key] != null;
}
