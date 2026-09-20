import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/client_config.dart';
import '../../../core/services/aws_sigv4_signer.dart';
import '../../radar/models/convoy_route.dart';
import '../models/pack_formation.dart';
import '../models/pack_member.dart';

class DynamoDbPackService {
  final ClientConfig config;
  final AwsSigV4Signer _signer;

  DynamoDbPackService({required this.config})
      : _signer = AwsSigV4Signer(
          region: config.region,
          endpoint: config.iot.endpoint,
        );

  String get _tableName => config.packs.tableName;
  String get _dynamoHost => 'dynamodb.${config.region}.amazonaws.com';
  Uri get _endpoint => Uri.parse('https://$_dynamoHost/');

  /// Create a new pack room on AWS DynamoDB
  Future<PackFormation> createPack({
    required String packCode,
    required String title,
    required String hostRiderId,
    required String hostCallsign,
    required String bikeModel,
    double geofenceRadiusMeters = 800.0,
    String formationType = 'STAGGERED',
    ConvoyRoute? activeRoute,
    required Map<String, String> awsCredentials,
  }) async {
    final hostMember = {
      'M': {
        'id': {'S': hostRiderId},
        'callsign': {'S': hostCallsign},
        'initials': {'S': _extractInitials(hostCallsign)},
        'vehicleClass': {'S': bikeModel},
        'isLeader': {'BOOL': true},
        'role': {'S': 'roadCaptain'},
        'speedKmh': {'N': '0.0'},
        'offsetMeters': {'N': '0.0'},
        'offsetDescription': {'S': 'Road Captain'},
        'latencyMs': {'N': '0'},
        'status': {'S': 'lead'},
        'joinedAt': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      }
    };

    final itemMap = <String, dynamic>{
      'packCode': {'S': packCode},
      'packId': {'S': packCode.replaceAll(RegExp(r'[^0-9]'), '')},
      'title': {'S': title},
      'hostRiderId': {'S': hostRiderId},
      'formationType': {'S': formationType},
      'geofenceRadiusMeters': {'N': geofenceRadiusMeters.toString()},
      'isLocked': {'BOOL': false},
      'status': {'S': 'active'},
      'createdAt': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      'updatedAt': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      'members': {
        'L': [hostMember],
      },
    };

    if (activeRoute != null) {
      itemMap['activeRouteJson'] = {'S': jsonEncode(activeRoute.toJson())};
    }

    final body = json.encode({
      'TableName': _tableName,
      'Item': itemMap,
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.PutItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    final response = await http.post(_endpoint, headers: headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final err = _parseError(response.body);
      throw Exception('AWS DynamoDB CreatePack Error: $err');
    }

    debugPrint('[DynamoDbPackService] Created pack $packCode on AWS DynamoDB.');

    return PackFormation(
      packId: packCode.replaceAll(RegExp(r'[^0-9]'), ''),
      packCode: packCode,
      title: title,
      geofenceRadiusMeters: geofenceRadiusMeters,
      formationType: formationType,
      isTelemetrySyncActive: true,
      isInPack: true,
      members: [
        PackMember(
          id: hostRiderId,
          callsign: hostCallsign,
          initials: _extractInitials(hostCallsign),
          status: PackMemberStatus.lead,
          speedKmh: 0.0,
          offsetMeters: 0.0,
          offsetDescription: 'Road Captain (Host)',
          latencyMs: 0,
          isLeader: true,
          role: PackRole.roadCaptain,
          isCurrentUser: true,
        ),
      ],
      activeRoute: activeRoute,
    );
  }

  /// Query an existing pack room from AWS DynamoDB
  Future<PackFormation?> getPack({
    required String packCode,
    required Map<String, String> awsCredentials,
    String? currentRiderId,
  }) async {
    final body = json.encode({
      'TableName': _tableName,
      'Key': {
        'packCode': {'S': packCode},
      },
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.GetItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    final response = await http.post(_endpoint, headers: headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final err = _parseError(response.body);
      throw Exception('AWS DynamoDB GetPack Error: $err');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final item = data['Item'] as Map<String, dynamic>?;
    if (item == null) return null;

    return _parsePackItem(item, currentRiderId);
  }

  /// Join an existing pack room on AWS DynamoDB
  Future<PackFormation> joinPack({
    required String packCode,
    required String riderId,
    required String callsign,
    required String bikeModel,
    required Map<String, String> awsCredentials,
  }) async {
    // 1. Fetch current pack from AWS
    final existingPack = await getPack(
      packCode: packCode,
      awsCredentials: awsCredentials,
      currentRiderId: riderId,
    );

    if (existingPack == null) {
      throw Exception("Pack room '$packCode' does not exist on AWS. Please verify the room code.");
    }

    if (existingPack.isLocked) {
      throw Exception("Convoy room '$packCode' is locked by the Road Captain. New entries are restricted.");
    }

    // 2. Check if rider is already in the pack
    final alreadyInPack = existingPack.members.any((m) => m.id == riderId);

    if (!alreadyInPack) {
      // Append rider to members in DynamoDB
      final newMemberObj = {
        'M': {
          'id': {'S': riderId},
          'callsign': {'S': callsign},
          'initials': {'S': _extractInitials(callsign)},
          'vehicleClass': {'S': bikeModel},
          'isLeader': {'BOOL': false},
          'role': {'S': 'packMember'},
          'speedKmh': {'N': '0.0'},
          'offsetMeters': {'N': '0.0'},
          'offsetDescription': {'S': 'Pack Rider'},
          'latencyMs': {'N': '10'},
          'status': {'S': 'inBounds'},
          'joinedAt': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
        }
      };

      final updateBody = json.encode({
        'TableName': _tableName,
        'Key': {
          'packCode': {'S': packCode},
        },
        'UpdateExpression': 'SET #members = list_append(if_not_exists(#members, :empty_list), :new_member), #updatedAt = :now',
        'ExpressionAttributeNames': {
          '#members': 'members',
          '#updatedAt': 'updatedAt',
        },
        'ExpressionAttributeValues': {
          ':new_member': {
            'L': [newMemberObj],
          },
          ':empty_list': {
            'L': [],
          },
          ':now': {
            'N': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        },
      });

      final headers = _signer.signHttpRequest(
        method: 'POST',
        path: '/',
        service: 'dynamodb',
        host: _dynamoHost,
        target: 'DynamoDB_20120810.UpdateItem',
        body: updateBody,
        accessKeyId: awsCredentials['AccessKeyId']!,
        secretKey: awsCredentials['SecretKey']!,
        sessionToken: awsCredentials['SessionToken'],
      );

      final response = await http.post(_endpoint, headers: headers, body: updateBody)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        final err = _parseError(response.body);
        throw Exception('AWS DynamoDB JoinPack Error: $err');
      }

      debugPrint('[DynamoDbPackService] Rider $callsign ($riderId) joined pack $packCode on AWS.');
    }

    // Refresh and return latest pack
    final refreshedPack = await getPack(
      packCode: packCode,
      awsCredentials: awsCredentials,
      currentRiderId: riderId,
    );

    return refreshedPack ?? existingPack;
  }

  /// Leave a pack room on AWS DynamoDB
  Future<void> leavePack({
    required String packCode,
    required String riderId,
    required Map<String, String> awsCredentials,
  }) async {
    final pack = await getPack(
      packCode: packCode,
      awsCredentials: awsCredentials,
      currentRiderId: riderId,
    );

    if (pack == null) return;

    final updatedMembers = pack.members
        .where((m) => m.id != riderId)
        .map((m) => {
              'M': {
                'id': {'S': m.id},
                'callsign': {'S': m.callsign.replaceAll(' (You)', '')},
                'initials': {'S': m.initials},
                'isLeader': {'BOOL': m.isLeader},
                'speedKmh': {'N': m.speedKmh.toString()},
                'offsetMeters': {'N': m.offsetMeters.toString()},
                'offsetDescription': {'S': m.offsetDescription},
                'latencyMs': {'N': m.latencyMs.toString()},
                'status': {'S': m.status.name},
              }
            })
        .toList();

    final body = json.encode({
      'TableName': _tableName,
      'Key': {
        'packCode': {'S': packCode},
      },
      'UpdateExpression': 'SET #members = :members, #updatedAt = :now',
      'ExpressionAttributeNames': {
        '#members': 'members',
        '#updatedAt': 'updatedAt',
      },
      'ExpressionAttributeValues': {
        ':members': {'L': updatedMembers},
        ':now': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      },
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.UpdateItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    await http.post(_endpoint, headers: headers, body: body).timeout(const Duration(seconds: 10));
    debugPrint('[DynamoDbPackService] Rider $riderId left pack $packCode on AWS.');
  }

  /// Kick a member from the pack room on AWS DynamoDB
  Future<void> kickMember({
    required String packCode,
    required String memberId,
    required Map<String, String> awsCredentials,
  }) async {
    final pack = await getPack(packCode: packCode, awsCredentials: awsCredentials);
    if (pack == null) return;

    final updatedMembers = pack.members
        .where((m) => m.id != memberId)
        .map((m) => {
              'M': {
                'id': {'S': m.id},
                'callsign': {'S': m.callsign.replaceAll(' (You)', '')},
                'initials': {'S': m.initials},
                'isLeader': {'BOOL': m.isLeader},
                'role': {'S': m.role.name},
                'speedKmh': {'N': m.speedKmh.toString()},
                'offsetMeters': {'N': m.offsetMeters.toString()},
                'offsetDescription': {'S': m.offsetDescription},
                'latencyMs': {'N': (m.latencyMs ?? 0).toString()},
                'status': {'S': m.status.name},
              }
            })
        .toList();

    final body = json.encode({
      'TableName': _tableName,
      'Key': {'packCode': {'S': packCode}},
      'UpdateExpression': 'SET #members = :members, #updatedAt = :now',
      'ExpressionAttributeNames': {'#members': 'members', '#updatedAt': 'updatedAt'},
      'ExpressionAttributeValues': {
        ':members': {'L': updatedMembers},
        ':now': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      },
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.UpdateItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    await http.post(_endpoint, headers: headers, body: body).timeout(const Duration(seconds: 10));
    debugPrint('[DynamoDbPackService] Rider $memberId was kicked from pack $packCode on AWS.');
  }

  /// Update geofence radius on AWS DynamoDB
  Future<void> updateGeofenceRadius({
    required String packCode,
    required double radiusMeters,
    required Map<String, String> awsCredentials,
  }) async {
    final body = json.encode({
      'TableName': _tableName,
      'Key': {
        'packCode': {'S': packCode},
      },
      'UpdateExpression': 'SET #radius = :r, #updatedAt = :now',
      'ExpressionAttributeNames': {
        '#radius': 'geofenceRadiusMeters',
        '#updatedAt': 'updatedAt',
      },
      'ExpressionAttributeValues': {
        ':r': {'N': radiusMeters.toString()},
        ':now': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      },
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.UpdateItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    await http.post(_endpoint, headers: headers, body: body).timeout(const Duration(seconds: 10));
  }

  PackFormation _parsePackItem(Map<String, dynamic> item, String? currentRiderId) {
    final packCode = item['packCode']?['S'] as String? ?? '';
    final packId = item['packId']?['S'] as String? ?? packCode;
    final title = item['title']?['S'] as String? ?? 'Pack $packCode';
    final radius = double.tryParse(item['geofenceRadiusMeters']?['N'] as String? ?? '800') ?? 800.0;

    final membersList = item['members']?['L'] as List<dynamic>? ?? [];
    final members = <PackMember>[];

    for (final m in membersList) {
      final map = m['M'] as Map<String, dynamic>?;
      if (map == null) continue;

      final id = map['id']?['S'] as String? ?? '';
      final rawCallsign = map['callsign']?['S'] as String? ?? 'Rider';
      final isCurrentUser = (currentRiderId != null && id == currentRiderId);
      final callsign = rawCallsign.replaceAll(' (You)', '').trim();

      final initials = map['initials']?['S'] as String? ?? _extractInitials(callsign);
      final isLeader = map['isLeader']?['BOOL'] as bool? ?? false;
      final speedKmh = double.tryParse(map['speedKmh']?['N'] as String? ?? '0') ?? 0.0;
      final offsetMeters = double.tryParse(map['offsetMeters']?['N'] as String? ?? '0') ?? 0.0;
      final offsetDesc = map['offsetDescription']?['S'] as String? ?? '';
      final latencyMs = int.tryParse(map['latencyMs']?['N'] as String? ?? '0') ?? 0;
      final statusStr = map['status']?['S'] as String? ?? 'inBounds';

      PackMemberStatus status = PackMemberStatus.inBounds;
      if (isLeader) {
        status = PackMemberStatus.lead;
      } else if (statusStr == 'warning') {
        status = PackMemberStatus.warning;
      } else if (statusStr == 'offline') {
        status = PackMemberStatus.offline;
      }

      final roleStr = map['role']?['S'] as String? ?? (isLeader ? 'roadCaptain' : 'packMember');
      PackRole role = PackRole.packMember;
      if (roleStr == 'roadCaptain' || isLeader) {
        role = PackRole.roadCaptain;
      } else if (roleStr == 'tailGunner') {
        role = PackRole.tailGunner;
      }

      members.add(PackMember(
        id: id,
        callsign: callsign,
        initials: initials,
        status: status,
        speedKmh: speedKmh,
        offsetMeters: offsetMeters,
        offsetDescription: offsetDesc,
        latencyMs: latencyMs,
        isLeader: isLeader,
        role: role,
        isCurrentUser: isCurrentUser,
      ));
    }

    final formationType = item['formationType']?['S'] as String? ?? 'STAGGERED';
    final isLocked = item['isLocked']?['BOOL'] as bool? ?? false;
    final hostRiderId = item['hostRiderId']?['S'] as String? ?? '';
    final status = item['status']?['S'] as String? ?? 'active';

    ConvoyRoute? activeRoute;
    final activeRouteJsonStr = item['activeRouteJson']?['S'] as String?;
    if (activeRouteJsonStr != null && activeRouteJsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(activeRouteJsonStr) as Map<String, dynamic>;
        activeRoute = ConvoyRoute.fromJson(decoded);
      } catch (e) {
        debugPrint('[DynamoDbPackService] Failed to parse activeRouteJson: $e');
      }
    }

    return PackFormation(
      packId: packId,
      packCode: packCode,
      title: title,
      geofenceRadiusMeters: radius,
      formationType: formationType,
      isTelemetrySyncActive: true,
      isInPack: packCode.isNotEmpty,
      members: members,
      isLocked: isLocked,
      hostRiderId: hostRiderId,
      status: status,
      activeRoute: activeRoute,
    );
  }

  /// Update a member's tactical role (e.g. promote to Tail Gunner)
  Future<void> updateMemberRole({
    required String packCode,
    required String memberId,
    required PackRole newRole,
    required Map<String, String> awsCredentials,
  }) async {
    final pack = await getPack(packCode: packCode, awsCredentials: awsCredentials);
    if (pack == null) return;

    final updatedMembers = pack.members.map((m) {
      final updatedRole = m.id == memberId ? newRole : m.role;
      return {
        'M': {
          'id': {'S': m.id},
          'callsign': {'S': m.callsign.replaceAll(' (You)', '')},
          'initials': {'S': m.initials},
          'isLeader': {'BOOL': updatedRole == PackRole.roadCaptain},
          'role': {'S': updatedRole.name},
          'speedKmh': {'N': m.speedKmh.toString()},
          'offsetMeters': {'N': m.offsetMeters.toString()},
          'offsetDescription': {'S': updatedRole == PackRole.tailGunner ? 'Tail Gunner (Sweeper)' : m.offsetDescription},
          'latencyMs': {'N': (m.latencyMs ?? 0).toString()},
          'status': {'S': m.status.name},
        }
      };
    }).toList();

    final body = json.encode({
      'TableName': _tableName,
      'Key': {'packCode': {'S': packCode}},
      'UpdateExpression': 'SET #members = :members, #updatedAt = :now',
      'ExpressionAttributeNames': {'#members': 'members', '#updatedAt': 'updatedAt'},
      'ExpressionAttributeValues': {
        ':members': {'L': updatedMembers},
        ':now': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      },
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.UpdateItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    await http.post(_endpoint, headers: headers, body: body).timeout(const Duration(seconds: 10));
  }

  /// Lock or unlock a pack room against new joiners
  Future<void> setPackLocked({
    required String packCode,
    required bool isLocked,
    required Map<String, String> awsCredentials,
  }) async {
    final body = json.encode({
      'TableName': _tableName,
      'Key': {'packCode': {'S': packCode}},
      'UpdateExpression': 'SET #isLocked = :isLocked, #updatedAt = :now',
      'ExpressionAttributeNames': {'#isLocked': 'isLocked', '#updatedAt': 'updatedAt'},
      'ExpressionAttributeValues': {
        ':isLocked': {'BOOL': isLocked},
        ':now': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      },
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.UpdateItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    await http.post(_endpoint, headers: headers, body: body).timeout(const Duration(seconds: 10));
  }

  /// Disband pack and close session on AWS DynamoDB
  Future<void> disbandPack({
    required String packCode,
    required Map<String, String> awsCredentials,
  }) async {
    final body = json.encode({
      'TableName': _tableName,
      'Key': {'packCode': {'S': packCode}},
      'UpdateExpression': 'SET #status = :disbanded, #members = :empty, #updatedAt = :now',
      'ExpressionAttributeNames': {'#status': 'status', '#members': 'members', '#updatedAt': 'updatedAt'},
      'ExpressionAttributeValues': {
        ':disbanded': {'S': 'disbanded'},
        ':empty': {'L': []},
        ':now': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
      },
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.UpdateItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    await http.post(_endpoint, headers: headers, body: body).timeout(const Duration(seconds: 10));
  }

  /// Update or clear the pack's active navigation route on AWS DynamoDB
  Future<void> updatePackRoute({
    required String packCode,
    required ConvoyRoute? route,
    required Map<String, String> awsCredentials,
  }) async {
    final updateExpr = route != null
        ? 'SET #route = :route, #updatedAt = :now'
        : 'REMOVE #route SET #updatedAt = :now';
    final exprNames = {
      '#route': 'activeRouteJson',
      '#updatedAt': 'updatedAt',
    };
    final exprValues = <String, dynamic>{
      ':now': {'N': DateTime.now().millisecondsSinceEpoch.toString()},
    };
    if (route != null) {
      exprValues[':route'] = {'S': jsonEncode(route.toJson())};
    }

    final body = json.encode({
      'TableName': _tableName,
      'Key': {
        'packCode': {'S': packCode},
      },
      'UpdateExpression': updateExpr,
      'ExpressionAttributeNames': exprNames,
      'ExpressionAttributeValues': exprValues,
    });

    final headers = _signer.signHttpRequest(
      method: 'POST',
      path: '/',
      service: 'dynamodb',
      host: _dynamoHost,
      target: 'DynamoDB_20120810.UpdateItem',
      body: body,
      accessKeyId: awsCredentials['AccessKeyId']!,
      secretKey: awsCredentials['SecretKey']!,
      sessionToken: awsCredentials['SessionToken'],
    );

    final response = await http.post(_endpoint, headers: headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final err = _parseError(response.body);
      throw Exception('AWS DynamoDB UpdatePackRoute Error: $err');
    }
    debugPrint('[DynamoDbPackService] Updated pack $packCode active route on AWS DynamoDB.');
  }

  String _extractInitials(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim();
    final parts = cleaned.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (cleaned.isNotEmpty) {
      return cleaned.substring(0, cleaned.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'RD';
  }

  String _parseError(String responseBody) {
    try {
      final jsonMap = json.decode(responseBody) as Map<String, dynamic>;
      final type = (jsonMap['__type'] as String? ?? '').split('#').last;
      final msg = jsonMap['message'] as String? ?? responseBody;
      return '[$type]: $msg';
    } catch (_) {
      return responseBody;
    }
  }
}
