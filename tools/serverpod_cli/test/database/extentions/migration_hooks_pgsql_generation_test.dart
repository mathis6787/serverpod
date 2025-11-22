import 'package:serverpod_service_client/serverpod_service_client.dart';
import 'package:serverpod_cli/src/database/extensions.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseDefinition.toPgSql', () {
    test('includes pre and post hooks inside transaction', () {
      var definition = DatabaseDefinition(
        moduleName: 'example',
        tables: [],
        installedModules: [],
        migrationApiVersion: 0,
      );

      var sql = definition.toPgSql(
        installedModules: [],
        preSql: ['-- PRE HOOK'],
        postSql: ['-- POST HOOK'],
      );

      expect(sql, contains('BEGIN;\n\n-- PRE HOOK'));
      expect(sql, contains('-- POST HOOK\nCOMMIT;'));
    });
  });

  group('DatabaseMigration.toPgSql', () {
    test('includes pre and post hooks around migration body', () {
      var migration = DatabaseMigration(
        actions: [],
        warnings: [],
        migrationApiVersion: 0,
      );

      var sql = migration.toPgSql(
        installedModules: [],
        removedModules: [],
        preSql: ['-- PRE MIGRATION'],
        postSql: ['-- POST MIGRATION'],
      );

      expect(sql, contains('BEGIN;\n\n-- PRE MIGRATION'));
      expect(sql, contains('-- POST MIGRATION\n\nCOMMIT;'));
    });
  });
}
