import 'dart:io';

import 'package:cli_tools/cli_tools.dart';
import 'package:config/config.dart';
import 'package:path/path.dart' as path;
import 'package:serverpod_cli/analyzer.dart';
import 'package:serverpod_cli/src/config/serverpod_feature.dart';
import 'package:serverpod_cli/src/runner/serverpod_command.dart';
import 'package:serverpod_cli/src/util/project_name.dart';
import 'package:serverpod_cli/src/util/serverpod_cli_logger.dart';
import 'package:serverpod_cli/src/util/string_validators.dart';
import 'package:serverpod_shared/serverpod_shared.dart' hide ExitException;

enum CreateMigrationOption<V> implements OptionDefinition<V> {
  force(CreateMigrationCommand.forceOption),
  tag(CreateMigrationCommand.tagOption),
  preDatabaseSetup(CreateMigrationCommand.preDatabaseSetupHookOption),
  postDatabaseSetup(CreateMigrationCommand.postDatabaseSetupHookOption),
  preMigration(CreateMigrationCommand.preMigrationHookOption),
  postMigration(CreateMigrationCommand.postMigrationHookOption);

  const CreateMigrationOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class CreateMigrationCommand extends ServerpodCommand<CreateMigrationOption> {
  static const forceOption = FlagOption(
    argName: 'force',
    argAbbrev: 'f',
    negatable: false,
    defaultsTo: false,
    helpText:
        'Creates the migration even if there are warnings or information that '
        'may be destroyed.',
  );

  static const tagOption = StringOption(
    argName: 'tag',
    argAbbrev: 't',
    helpText: 'Add a tag to the revision to easier identify it.',
    customValidator: _validateTag,
  );

  static const preDatabaseSetupHookOption = StringOption(
    argName: 'pre-db-setup',
    helpText:
        'Optional SQL file to run before the generated definition.sql content.',
  );

  static const postDatabaseSetupHookOption = StringOption(
    argName: 'post-db-setup',
    helpText:
        'Optional SQL file to run after the generated definition.sql content.',
  );

  static const preMigrationHookOption = StringOption(
    argName: 'pre-migration',
    helpText:
        'Optional SQL file to run before the generated migration.sql content.',
  );

  static const postMigrationHookOption = StringOption(
    argName: 'post-migration',
    helpText:
        'Optional SQL file to run after the generated migration.sql content.',
  );

  static void _validateTag(String tag) {
    if (!StringValidators.isValidTagName(tag)) {
      throw const FormatException(
        'Tag names can only contain lowercase letters, numbers, and dashes.',
      );
    }
  }

  static Future<String?> _readHookFile(String? path) async {
    if (path == null) return null;

    var file = File(path);
    if (!file.existsSync()) {
      log.error('Hook file not found: $path');
      throw ExitException(ServerpodCommand.commandInvokedCannotExecute);
    }

    var sql = await file.readAsString();
    if (sql.trim().isEmpty) {
      log.warning('Hook file $path is empty.');
    }

    return sql;
  }

  @override
  final name = 'create-migration';

  @override
  final description =
      'Creates a migration from the last migration to the current state of the database.';

  CreateMigrationCommand() : super(options: CreateMigrationOption.values);

  @override
  Future<void> runWithConfig(
    final Configuration<CreateMigrationOption> commandConfig,
  ) async {
    bool force = commandConfig.value(CreateMigrationOption.force);
    String? tag = commandConfig.optionalValue(CreateMigrationOption.tag);
    var preDatabaseSetupSql = await _readHookFile(
      commandConfig.optionalValue(CreateMigrationOption.preDatabaseSetup),
    );
    var postDatabaseSetupSql = await _readHookFile(
      commandConfig.optionalValue(CreateMigrationOption.postDatabaseSetup),
    );
    var preMigrationSql = await _readHookFile(
      commandConfig.optionalValue(CreateMigrationOption.preMigration),
    );
    var postMigrationSql = await _readHookFile(
      commandConfig.optionalValue(CreateMigrationOption.postMigration),
    );

    GeneratorConfig config;
    try {
      config = await GeneratorConfig.load();
    } catch (_) {
      throw ExitException(ServerpodCommand.commandInvokedCannotExecute);
    }

    if (!config.isFeatureEnabled(ServerpodFeature.database)) {
      log.error(
        'The database feature is not enabled in this project. '
        'This command cannot be used.',
      );
      throw ExitException(ServerpodCommand.commandInvokedCannotExecute);
    }

    var projectName = await getProjectName();
    if (projectName == null) {
      throw ExitException(ServerpodCommand.commandInvokedCannotExecute);
    }

    var generator = MigrationGenerator(
      directory: Directory.current,
      projectName: projectName,
    );

    MigrationVersion? migration;
    await log.progress('Creating migration', () async {
      try {
        migration = await generator.createMigration(
          tag: tag,
          force: force,
          config: config,
          preDatabaseSetupSql: preDatabaseSetupSql,
          postDatabaseSetupSql: postDatabaseSetupSql,
          preMigrationSql: preMigrationSql,
          postMigrationSql: postMigrationSql,
        );
      } on MigrationVersionLoadException catch (e) {
        log.error(
          'Unable to determine latest database definition due to a corrupted '
          'migration. Please re-create or remove the migration version and try '
          'again. Migration version: "${e.versionName}".',
        );
        log.error(e.exception);
      } on GenerateMigrationDatabaseDefinitionException {
        log.error('Unable to generate database definition for project.');
      } on MigrationVersionAlreadyExistsException catch (e) {
        log.error(
          'Unable to create migration. A directory with the same name already '
          'exists: "${e.directoryPath}".',
        );
      }

      return migration != null;
    });

    var projectDirectory = migration?.projectDirectory;
    var migrationName = migration?.versionName;
    if (migration == null ||
        projectDirectory == null ||
        migrationName == null) {
      throw ExitException.error();
    }

    log.info(
      'Migration created: ${path.relative(
        MigrationConstants.migrationVersionDirectory(
          projectDirectory,
          migrationName,
        ).path,
        from: Directory.current.path,
      )}',
      type: TextLogType.bullet,
    );
    log.info('Done.', type: TextLogType.success);
  }
}
