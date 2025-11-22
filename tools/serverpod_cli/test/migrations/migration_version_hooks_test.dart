import 'dart:io';

import 'package:serverpod_cli/src/migrations/generator.dart';
import 'package:serverpod_cli/test/test_util/builders/migration_version_builder.dart';
import 'package:test/test.dart';

void main() {
  group('MigrationVersion.write', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('migration_version_hooks');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('orders module hooks before application hooks', () async {
      var appMigration = MigrationVersionBuilder()
          .withProjectDirectory(tempDir)
          .withVersionName('20240101000000')
          .build();

      var moduleMigration = MigrationVersionBuilder()
          .withModuleName('module')
          .withVersionName('20240101000000')
          .withProjectDirectory(tempDir)
          .withPreDatabaseSetupSql('MODULE PRE SETUP;')
          .withPostDatabaseSetupSql('MODULE POST SETUP;')
          .withPreMigrationSql('MODULE PRE MIG;')
          .withPostMigrationSql('MODULE POST MIG;')
          .build();

      await appMigration.write(
        installedModules: appMigration.databaseDefinitionFull.installedModules,
        removedModules: const [],
        moduleMigrations: [moduleMigration],
        preDatabaseSetupSql: 'APP PRE SETUP;',
        postDatabaseSetupSql: 'APP POST SETUP;',
        preMigrationSql: 'APP PRE MIG;',
        postMigrationSql: 'APP POST MIG;',
      );

      var definitionSql = await File(
        '${tempDir.path}/migrations/20240101000000/definition.sql',
      ).readAsString();

      expect(
        definitionSql.indexOf('MODULE PRE SETUP;') <
            definitionSql.indexOf('APP PRE SETUP;'),
        isTrue,
        reason: 'Module pre hooks should precede app pre hooks.',
      );

      expect(
        definitionSql.indexOf('MODULE POST SETUP;') <
            definitionSql.indexOf('APP POST SETUP;'),
        isTrue,
        reason: 'Module post hooks should precede app post hooks.',
      );

      var migrationSql = await File(
        '${tempDir.path}/migrations/20240101000000/migration.sql',
      ).readAsString();

      expect(
        migrationSql.indexOf('MODULE PRE MIG;') <
            migrationSql.indexOf('APP PRE MIG;'),
        isTrue,
        reason: 'Module pre migration hooks should precede app pre hooks.',
      );

      expect(
        migrationSql.indexOf('MODULE POST MIG;') <
            migrationSql.indexOf('APP POST MIG;'),
        isTrue,
        reason: 'Module post migration hooks should precede app post hooks.',
      );
    });

    test('creates placeholder hook files when no hook SQL is provided', () async {
      var migration = MigrationVersionBuilder()
          .withProjectDirectory(tempDir)
          .withVersionName('20240101000001')
          .build();

      await migration.write(
        installedModules: migration.databaseDefinitionFull.installedModules,
        removedModules: const [],
      );

      var preSetup = File(
        '${tempDir.path}/migrations/20240101000001/pre_database_setup.sql',
      );
      var postSetup = File(
        '${tempDir.path}/migrations/20240101000001/post_database_setup.sql',
      );
      var preMigration = File(
        '${tempDir.path}/migrations/20240101000001/pre_migration.sql',
      );
      var postMigration = File(
        '${tempDir.path}/migrations/20240101000001/post_migration.sql',
      );

      expect(preSetup.existsSync(), isTrue);
      expect(postSetup.existsSync(), isTrue);
      expect(preMigration.existsSync(), isTrue);
      expect(postMigration.existsSync(), isTrue);

      expect(
        preSetup.readAsStringSync(),
        contains('before definition.sql'),
      );
      expect(
        postSetup.readAsStringSync(),
        contains('after definition.sql'),
      );
      expect(
        preMigration.readAsStringSync(),
        contains('before migration.sql'),
      );
      expect(
        postMigration.readAsStringSync(),
        contains('after migration.sql'),
      );
    });

    test('writes placeholders when empty hook SQL is supplied', () async {
      var migration = MigrationVersionBuilder()
          .withProjectDirectory(tempDir)
          .withVersionName('20240101000002')
          .build();

      await migration.write(
        installedModules: migration.databaseDefinitionFull.installedModules,
        removedModules: const [],
        preDatabaseSetupSql: '  ',
        postDatabaseSetupSql: '',
        preMigrationSql: '\n',
        postMigrationSql: '',
      );

      var preSetup = File(
        '${tempDir.path}/migrations/20240101000002/pre_database_setup.sql',
      );
      var postSetup = File(
        '${tempDir.path}/migrations/20240101000002/post_database_setup.sql',
      );
      var preMigration = File(
        '${tempDir.path}/migrations/20240101000002/pre_migration.sql',
      );
      var postMigration = File(
        '${tempDir.path}/migrations/20240101000002/post_migration.sql',
      );

      expect(preSetup.readAsStringSync(), contains('before definition.sql'));
      expect(postSetup.readAsStringSync(), contains('after definition.sql'));
      expect(preMigration.readAsStringSync(), contains('before migration.sql'));
      expect(postMigration.readAsStringSync(), contains('after migration.sql'));
    });
  });
}
