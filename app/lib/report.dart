import 'package:app/section.dart';
import 'package:app/test_mode.dart';
import 'package:meta/meta.dart';

extension on Map<String, dynamic> {
  T get<T>(String key, T Function(dynamic) ifNotNull) {
    final dynamic value = this['key'];
    return value != null ? ifNotNull(value) : null;
  }
}

class Report {
  final String packageName;
  final double grantedPoints;
  final double maxPoints;
  final String panaVersion;
  final String flutterVersion;
  final String dartSdkVersion;
  final String dartSdkInFlutterVersion;
  final Map<String, List<String>> supportedPlatforms;
  final List<Section> sections;
  final String errorMessage;

  Report._({
    @required this.packageName,
    @required this.grantedPoints,
    @required this.maxPoints,
    @required this.panaVersion,
    @required this.dartSdkInFlutterVersion,
    @required this.dartSdkVersion,
    @required this.flutterVersion,
    @required this.supportedPlatforms,
    @required this.sections,
    @required this.errorMessage,
  });

  factory Report.fromOutput(Map<String, dynamic> output) {
    final packageName = output['packageName'] as String;
    final runtimeInfo = output['runtimeInfo'] as Map<String, dynamic>;
    final panaVersion = runtimeInfo['panaVersion'] as String;
    final dartSdkVersion = runtimeInfo['sdkVersion'] as String;
    final flutterInfo = runtimeInfo['flutterVersions'] as Map<String, dynamic>;
    final flutterVersion = flutterInfo['frameworkVersion'] as String;
    final dartInFlutterVersion = flutterInfo['dartSdkVersion'] as String;
    final scores = output['scores'] as Map<String, dynamic>;
    final grantedPoints =
        scores.get('grantedPoints', (dynamic i) => (i as int).toDouble());
    final maxPoints =
        scores.get('maxPoints', (dynamic i) => (i as int).toDouble());
    final String errorMessage = output['errorMessage'];
    final sections = <Section>[];

    final supportedPlatforms = <String, List<String>>{};

    final List<dynamic> tags = output['tags'];
    if (tags != null) {
      if (testing) tags.add('runtime:web');
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
      (output['report']['sections'] as List<dynamic>).forEach((dynamic s) =>
          sections.add(Section.fromJSON(s as Map<String, dynamic>)));
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
