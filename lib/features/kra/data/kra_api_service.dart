import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_service.dart';

class KraApiService {
  final ApiService api;

  KraApiService(this.api);

  Future<dynamic> listKras({
    String? departmentId,
    String? employeeId,
    int? page,
    int? limit,
  }) {
    final query = <String, dynamic>{};
    if (departmentId != null && departmentId.trim().isNotEmpty) {
      query['department_id'] = departmentId.trim();
    }
    if (employeeId != null && employeeId.trim().isNotEmpty) {
      query['employee_id'] = employeeId.trim();
    }
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;

    return api.get(ApiEndpoints.kra, queryParams: query.isEmpty ? null : query);
  }

  Future<dynamic> getTeamMembers({int? page, int? limit}) {
    final query = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };

    return api.get(
      ApiEndpoints.kraTeamMembers,
      queryParams: query.isEmpty ? null : query,
    );
  }

  Future<dynamic> createKra(Map<String, dynamic> payload) {
    return api.post(ApiEndpoints.kra, payload);
  }

  Future<dynamic> updateKra(String id, Map<String, dynamic> payload) {
    return api.put('${ApiEndpoints.kra}/$id', payload);
  }

  Future<void> deleteKra(String id) async {
    await api.deleteNoBody('${ApiEndpoints.kra}/$id');
  }

  Future<dynamic> initiateCycle({required int month, required int year}) {
    return api.post(ApiEndpoints.kraInitiate, {'month': month, 'year': year});
  }

  Future<dynamic> getActiveCycle() => api.get(ApiEndpoints.kraActiveCycle);

  Future<dynamic> listCycles({int? page, int? limit}) {
    final query = <String, dynamic>{
      if (page != null) 'page': page,
      if (limit != null) 'limit': limit,
    };

    return api.get(
      ApiEndpoints.kraCycles,
      queryParams: query.isEmpty ? null : query,
    );
  }

  Future<dynamic> listEvaluations({
    required String mode,
    String? cycleId,
    int? page,
    int? limit,
  }) {
    final query = <String, dynamic>{'mode': mode};
    if (cycleId != null && cycleId.trim().isNotEmpty) {
      query['cycle_id'] = cycleId.trim();
    }
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    return api.get(ApiEndpoints.kraEvaluations, queryParams: query);
  }

  Future<dynamic> submitRating({
    required String evaluationId,
    required List<Map<String, dynamic>> ratings,
    Map<String, String> documentPathsByKpi = const {},
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('evaluation_id', evaluationId));
    formData.fields.add(MapEntry('ratings', jsonEncode(ratings)));

    for (final entry in documentPathsByKpi.entries) {
      final path = entry.value.trim();
      if (path.isEmpty) continue;

      formData.files.add(
        MapEntry(
          'document_${entry.key}',
          await MultipartFile.fromFile(
            path,
            filename: p.basename(path),
            contentType: _contentTypeForPath(path),
          ),
        ),
      );
    }

    return api.postMultipart(ApiEndpoints.kraSubmitRating, formData);
  }

  MediaType? _contentTypeForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.png':
        return MediaType('image', 'png');
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case '.xlsx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case '.csv':
        return MediaType('text', 'csv');
      default:
        return null;
    }
  }
}
