import 'package:app/section.dart';

class Report {
  final String? packageName;
  final int? grantedPoints;
  final int? maxPoints;
  final String? panaVersion;
  final String? flutterVersion;
  final String? dartSdkVersion;
  final String? dartSdkInFlutterVersion;
  final Map<String, List<String>> supportedPlatforms;
  final List<Section> sections;
  final String? errorMessage;

  Report._({
    required this.packageName,
    required this.grantedPoints,
    required this.maxPoints,
    required this.panaVersion,
    required this.dartSdkInFlutterVersion,
    required this.dartSdkVersion,
    required this.flutterVersion,
    required this.supportedPlatforms,
    required this.sections,
    required this.errorMessage,
  });

  factory Report.fromOutput(Map<String, dynamic> output) {
    final packageName = output['packageName'] as String?;
    final runtimeInfo = output['runtimeInfo'] as Map<String, dynamic>?;
    final panaVersion = runtimeInfo?['panaVersion'] as String?;
    final dartSdkVersion = runtimeInfo?['sdkVersion'] as String?;
    final flutterInfo =
        runtimeInfo?['flutterVersions'] as Map<String, dynamic>?;
    final flutterVersion = flutterInfo?['frameworkVersion'] as String?;
    final dartInFlutterVersion = flutterInfo?['dartSdkVersion'] as String?;
    final scores = output['scores'] as Map<String, dynamic>?;
    final int? grantedPoints = scores?['grantedPoints'];
    final int? maxPoints = scores?['maxPoints'];
    final String? errorMessage = output['errorMessage'];
    final sections = <Section>[];

    final supportedPlatforms = <String, List<String>>{};

    final List<dynamic>? tags = output['tags'];
    if (tags != null) {
      List.castFrom<dynamic, String>(tags).forEach((tag) {
        final splitted = tag.split(":");
        if (splitted.length != 2) return;
        switch (splitted[0]) {
          case 'platform':
            supportedPlatforms
                .putIfAbsent('Flutter', () => [])
                .add(splitted[1]);
            break;
          case 'runtime':
            supportedPlatforms.putIfAbsent('Dart', () => []).add(splitted[1]);
            break;
        }
      });
    }

    if (output['report'] != null && output['report']['sections'] != null) {
      for (final s in (output['report']['sections'] as List<dynamic>)) {
        sections.add(Section.fromJSON(s as Map<String, dynamic>));
      }
    }

    return Report._(
      packageName: packageName,
      panaVersion: panaVersion,
      flutterVersion: flutterVersion,
      dartSdkInFlutterVersion: dartInFlutterVersion,
      dartSdkVersion: dartSdkVersion,
      supportedPlatforms: supportedPlatforms,
      grantedPoints: grantedPoints,
      maxPoints: maxPoints,
      sections: sections,
      errorMessage: errorMessage,
    );
  }
}
