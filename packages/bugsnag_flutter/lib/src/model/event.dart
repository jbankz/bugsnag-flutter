import 'dart:io';

import '_model_extensions.dart';
import 'app.dart';
import 'breadcrumbs.dart';
import 'device.dart';
import 'feature_flags.dart';
import 'metadata.dart';
import 'stackframe.dart';
import 'thread.dart';
import 'user.dart';

class BugsnagEvent {
  String? apiKey;
  List<BugsnagError> errors;
  List<BugsnagThread> threads;
  List<BugsnagBreadcrumb> breadcrumbs;
  String? context;
  String? groupingHash;
  bool _unhandled;
  final bool _originalUnhandled;
  Severity severity;
  final _SeverityReason _severityReason;
  final List<String> _projectPackages;
  final _Session? _session;
  User _user;

  DeviceWithState device;
  AppWithState app;

  final FeatureFlags _featureFlags;
  final BugsnagMetadata _metadata;

  bool get unhandled => _unhandled;

  User get user => _user;

  set unhandled(bool unhandled) {
    _unhandled = unhandled;
    _severityReason.unhandledOverridden =
        (_unhandled != _originalUnhandled) ? true : null;
  }

  void addMetadata(String section, MetadataSection metadata) =>
      _metadata.addMetadata(section, metadata);

  void clearMetadata(String section, [String? key]) =>
      _metadata.clearMetadata(section, key);

  MetadataSection? getMetadata(String section) =>
      _metadata.getMetadata(section);

  void addFeatureFlag(String name, [String? variant]) =>
      _featureFlags.addFeatureFlag(name, variant);

  void clearFeatureFlag(String name) => _featureFlags.clearFeatureFlag(name);

  void clearFeatureFlags() => _featureFlags.clearFeatureFlags();

  void setUser({String? id, String? email, String? name}) {
    _user = User(id: id, email: email, name: name);
  }

  BugsnagEvent.fromJson(Map<String, dynamic> json)
      : apiKey = json['apiKey'] as String?,
        errors = (json['exceptions'] as List?)
                ?.cast<Map>()
                .map((m) => BugsnagError.fromJson(m.cast()))
                .toList(growable: true) ??
            [],
        threads = (json['threads'] as List?)
                ?.cast<Map>()
                .map((m) => BugsnagThread.fromJson(m.cast()))
                .toList(growable: true) ??
            [],
        breadcrumbs = (json['breadcrumbs'] as List?)
                ?.cast<Map>()
                .map((m) => BugsnagBreadcrumb.fromJson(m.cast()))
                .toList(growable: true) ??
            [],
        context = json['context'] as String?,
        groupingHash = json['groupingHash'] as String?,
        _unhandled = json['unhandled'] == true,
        _originalUnhandled = json['unhandled'] == true,
        severity = Severity.values.byName(json['severity']),
        _severityReason = _SeverityReason.fromJson(json['severityReason']),
        _projectPackages =
            (json['projectPackages'] as List?)?.toList(growable: true).cast() ??
                [],
        _session = json
            .safeGet<Map>('session')
            ?.let((session) => _Session.fromJson(session.cast())),
        _user = User.fromJson(json['user']),
        device = DeviceWithState.fromJson(json['device']),
        app = AppWithState.fromJson(json['app']),
        _featureFlags = FeatureFlags.fromJson(
            json['featureFlags'].cast<Map<String, dynamic>>()),
        _metadata = json
                .safeGet<Map>('metaData')
                ?.let((m) => BugsnagMetadata.fromJson(m.cast())) ??
            BugsnagMetadata();

  dynamic toJson() {
    return {
      if (apiKey != null) 'apiKey': apiKey,
      'exceptions': errors,
      'threads': threads,
      'breadcrumbs': breadcrumbs,
      if (context != null) 'context': context,
      if (groupingHash != null) 'groupingHash': groupingHash,
      'unhandled': unhandled,
      'severity': severity.name,
      'severityReason': _severityReason,
      'projectPackages': _projectPackages,
      'user': user,
      if (_session != null) 'session': _session,
      'device': device,
      'app': app,
      'featureFlags': _featureFlags,
      'metaData': _metadata,
    };
  }
}

class _SeverityReason {
  String type;
  bool? unhandledOverridden;

  _SeverityReason.fromJson(Map<String, dynamic> json)
      : type = json['type'],
        unhandledOverridden = json.safeGet('unhandledOverridden');

  dynamic toJson() => {
        'type': type,
        if (unhandledOverridden != null)
          'unhandledOverridden': unhandledOverridden,
      };
}

class _Session {
  String id;

  int handledCount;
  int unhandledCount;

  DateTime startedAt;

  _Session.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        startedAt = DateTime.parse(json['startedAt'] as String).toUtc(),
        handledCount =
            (json['events'] as Map?)?.safeGet<num>('handled')?.toInt() ?? 0,
        unhandledCount =
            (json['events'] as Map?)?.safeGet<num>('unhandled')?.toInt() ?? 0;

  dynamic toJson() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'events': {
          'handled': handledCount,
          'unhandled': unhandledCount,
        }
      };
}

enum Severity {
  error,
  warning,
  info,
}

class BugsnagError {
  String errorClass;
  String? message;
  BugsnagErrorType type;

  BugsnagStacktrace stacktrace;

  BugsnagError(this.errorClass, this.message, this.stacktrace)
      : type = BugsnagErrorType.dart;

  BugsnagError.fromJson(Map<String, dynamic> json)
      : errorClass = json.safeGet('errorClass'),
        message = json.safeGet('message'),
        type = json.safeGet<String>('type')?.let(BugsnagErrorType.forName) ??
            (Platform.isAndroid
                ? BugsnagErrorType.android
                : BugsnagErrorType.cocoa),
        stacktrace = BugsnagStackframe.stacktraceFromJson(
            (json['stacktrace'] as List).cast());

  dynamic toJson() => {
        'errorClass': errorClass,
        if (message != null) 'message': message,
        'type': type.name,
        'stacktrace': stacktrace,
      };
}

class BugsnagErrorType {
  static const android = BugsnagErrorType._create('android');
  static const cocoa = BugsnagErrorType._create('cocoa');
  static const c = BugsnagErrorType._create('c');
  static const dart = BugsnagErrorType._create('dart');

  final String name;

  const BugsnagErrorType._create(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BugsnagErrorType &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;

  factory BugsnagErrorType.forName(String name) {
    if (name == android.name) return android;
    if (name == cocoa.name) return cocoa;
    if (name == c.name) return c;
    if (name == dart.name) return dart;

    return BugsnagErrorType._create(name);
  }
}