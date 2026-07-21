import '../../core/network/api_client.dart';

class TableColumn {
  final String name, type;
  final bool notNull, primaryKey;
  TableColumn({
    required this.name,
    required this.type,
    required this.notNull,
    required this.primaryKey,
  });

  factory TableColumn.fromJson(Map<String, dynamic> j) => TableColumn(
    name: j['name'],
    type: j['type'] ?? '',
    notNull: j['notNull'] ?? false,
    primaryKey: j['primaryKey'] ?? false,
  );
}

class DbTable {
  final String name;
  final List<TableColumn> columns;
  DbTable({required this.name, required this.columns});

  factory DbTable.fromJson(Map<String, dynamic> j) => DbTable(
    name: j['name'],
    columns: (j['columns'] as List? ?? [])
        .map((c) => TableColumn.fromJson(c))
        .toList(),
  );
}

class QueryResult {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final int rowCount;
  final bool truncated;
  QueryResult({
    required this.columns,
    required this.rows,
    required this.rowCount,
    required this.truncated,
  });

  factory QueryResult.fromJson(Map<String, dynamic> j) => QueryResult(
    columns: List<String>.from(j['columns'] ?? []),
    rows: (j['rows'] as List? ?? []).cast<Map<String, dynamic>>(),
    rowCount: j['rowCount'] ?? 0,
    truncated: j['truncated'] ?? false,
  );
}

class DbExplorerApi {
  final ApiClient client;
  DbExplorerApi(this.client);

  Future<List<DbTable>> fetchTables() async {
    final res = await client.get('/api/admin/db/tables');
    return (res.data['tables'] as List)
        .map((t) => DbTable.fromJson(t))
        .toList();
  }

  Future<QueryResult> runQuery(String sql, {int limit = 200}) async {
    final res = await client.post('/api/admin/db/query', {
      'sql': sql,
      'limit': limit,
    });
    return QueryResult.fromJson(res.data);
  }
}
