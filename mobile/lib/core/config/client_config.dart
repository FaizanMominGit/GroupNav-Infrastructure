import 'dart:convert';
import 'package:flutter/services.dart';

/// Strongly-typed configuration parsed directly from client-config.json
class ClientConfig {
  final String region;
  final CognitoConfig cognito;
  final LocationConfig location;
  final IotConfig iot;
  final NetworkConfig network;
  final DataConfig data;
  final ComputeConfig compute;
  final CicdConfig cicd;
  final PacksConfig packs;

  const ClientConfig({
    required this.region,
    required this.cognito,
    required this.location,
    required this.iot,
    required this.network,
    required this.data,
    required this.compute,
    required this.cicd,
    this.packs = const PacksConfig(tableName: 'groupnav-packs'),
  });

  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    return ClientConfig(
      region: json['region'] as String? ?? 'ap-south-1',
      cognito: CognitoConfig.fromJson(json['cognito'] as Map<String, dynamic>? ?? {}),
      location: LocationConfig.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      iot: IotConfig.fromJson(json['iot'] as Map<String, dynamic>? ?? {}),
      network: NetworkConfig.fromJson(json['network'] as Map<String, dynamic>? ?? {}),
      data: DataConfig.fromJson(json['data'] as Map<String, dynamic>? ?? {}),
      compute: ComputeConfig.fromJson(json['compute'] as Map<String, dynamic>? ?? {}),
      cicd: CicdConfig.fromJson(json['cicd'] as Map<String, dynamic>? ?? {}),
      packs: PacksConfig.fromJson(json['packs'] as Map<String, dynamic>? ?? {}),
    );
  }

  static Future<ClientConfig> loadFromAsset([String path = 'assets/config/client-config.json']) async {
    final rawString = await rootBundle.loadString(path);
    final jsonMap = json.decode(rawString) as Map<String, dynamic>;
    return ClientConfig.fromJson(jsonMap);
  }
}

class PacksConfig {
  final String tableName;

  const PacksConfig({required this.tableName});

  factory PacksConfig.fromJson(Map<String, dynamic> json) {
    return PacksConfig(
      tableName: json['tableName'] as String? ?? 'groupnav-packs',
    );
  }
}

class CognitoConfig {
  final String userPoolId;
  final String userPoolClientId;
  final String identityPoolId;

  const CognitoConfig({
    required this.userPoolId,
    required this.userPoolClientId,
    required this.identityPoolId,
  });

  factory CognitoConfig.fromJson(Map<String, dynamic> json) {
    return CognitoConfig(
      userPoolId: json['userPoolId'] as String? ?? '',
      userPoolClientId: json['userPoolClientId'] as String? ?? '',
      identityPoolId: json['identityPoolId'] as String? ?? '',
    );
  }
}

class LocationConfig {
  final String mapName;
  final String mapArn;
  final String geofenceCollectionName;
  final String geofenceCollectionArn;
  final String routeCalculatorName;
  final String routeCalculatorArn;
  final String placeIndexName;
  final String placeIndexArn;

  const LocationConfig({
    required this.mapName,
    required this.mapArn,
    required this.geofenceCollectionName,
    required this.geofenceCollectionArn,
    this.routeCalculatorName = 'GroupNavRouteCalculator',
    this.routeCalculatorArn = '',
    this.placeIndexName = 'GroupNavPlaceIndex',
    this.placeIndexArn = '',
  });

  factory LocationConfig.fromJson(Map<String, dynamic> json) {
    return LocationConfig(
      mapName: json['mapName'] as String? ?? '',
      mapArn: json['mapArn'] as String? ?? '',
      geofenceCollectionName: json['geofenceCollectionName'] as String? ?? '',
      geofenceCollectionArn: json['geofenceCollectionArn'] as String? ?? '',
      routeCalculatorName: json['routeCalculatorName'] as String? ?? 'GroupNavRouteCalculator',
      routeCalculatorArn: json['routeCalculatorArn'] as String? ?? '',
      placeIndexName: json['placeIndexName'] as String? ?? 'GroupNavPlaceIndex',
      placeIndexArn: json['placeIndexArn'] as String? ?? '',
    );
  }
}

class IotConfig {
  final String endpoint;

  const IotConfig({required this.endpoint});

  factory IotConfig.fromJson(Map<String, dynamic> json) {
    return IotConfig(
      endpoint: json['endpoint'] as String? ?? '',
    );
  }
}

class NetworkConfig {
  final String vpcId;
  final String computeSecurityGroupId;
  final String dataSecurityGroupId;

  const NetworkConfig({
    required this.vpcId,
    required this.computeSecurityGroupId,
    required this.dataSecurityGroupId,
  });

  factory NetworkConfig.fromJson(Map<String, dynamic> json) {
    return NetworkConfig(
      vpcId: json['vpcId'] as String? ?? '',
      computeSecurityGroupId: json['computeSecurityGroupId'] as String? ?? '',
      dataSecurityGroupId: json['dataSecurityGroupId'] as String? ?? '',
    );
  }
}

class DataConfig {
  final String redisEndpoint;
  final String auroraClusterEndpoint;

  const DataConfig({
    required this.redisEndpoint,
    required this.auroraClusterEndpoint,
  });

  factory DataConfig.fromJson(Map<String, dynamic> json) {
    return DataConfig(
      redisEndpoint: json['redisEndpoint'] as String? ?? '',
      auroraClusterEndpoint: json['auroraClusterEndpoint'] as String? ?? '',
    );
  }
}

class ComputeConfig {
  final String lambdaArn;
  final String dlqUrl;
  final String telemetryTopicPattern;

  const ComputeConfig({
    required this.lambdaArn,
    required this.dlqUrl,
    required this.telemetryTopicPattern,
  });

  factory ComputeConfig.fromJson(Map<String, dynamic> json) {
    return ComputeConfig(
      lambdaArn: json['lambdaArn'] as String? ?? '',
      dlqUrl: json['dlqUrl'] as String? ?? '',
      telemetryTopicPattern: json['telemetryTopicPattern'] as String? ?? 'groupnav/{riderId}/telemetry',
    );
  }
}

class CicdConfig {
  final String pipelineName;
  final String pipelineArn;
  final String gitHubConnectionArn;
  final String artifactBucketName;

  const CicdConfig({
    required this.pipelineName,
    required this.pipelineArn,
    required this.gitHubConnectionArn,
    required this.artifactBucketName,
  });

  factory CicdConfig.fromJson(Map<String, dynamic> json) {
    return CicdConfig(
      pipelineName: json['pipelineName'] as String? ?? '',
      pipelineArn: json['pipelineArn'] as String? ?? '',
      gitHubConnectionArn: json['gitHubConnectionArn'] as String? ?? '',
      artifactBucketName: json['artifactBucketName'] as String? ?? '',
    );
  }
}
