require 'config/compatibility'
require 'config/options'
require 'config/configuration'
require 'config/version'
require 'config/sources/yaml_source'
require 'config/sources/db_source'
require 'config/sources/hash_source'
require 'config/sources/env_source'
require 'config/validation/schema'
require 'deep_merge'

module Config
  extend Config::Validation::Schema
  extend Config::Configuration.new(
    # general options
    const_name: 'Settings',
    use_env: false,
    env_prefix: 'Settings',
    env_separator: '.',
    env_converter: :downcase,
    env_parse_values: true,
    fail_on_missing: false,
    # deep_merge options
    knockout_prefix: nil,
    merge_nil_values: true,
    overwrite_arrays: true,
    merge_hash_arrays: false,
    validation_contract: nil,
    evaluate_erb_in_yaml: true,
    # custom Corevist configuration
    database_yml_path: '/config/database.yml',
    key_key: :key,
    value_key: :value
  )

  def self.setup
    yield self unless @_ran_once
    @_ran_once = true
  end

  # Create a populated Options instance from a settings file. If a second file is given, then the sections of that
  # file will overwrite existing sections of the first file.
  def self.load_files(*files)
    load_sources(:files, files)
  end

  def self.load_tables(*files)
    load_sources(:tables, files)
  end

  def self.load_sources(source_type, *sources)
    config = Options.new

    # add settings sources
    [sources].flatten.compact.uniq.each do |source|
      next config.add_source!(source.to_s) if source_type == :files

      config.add_source!(Sources::DbSource.new(source))
    end

    config.add_source!(Sources::EnvSource.new(ENV)) if Config.use_env

    config.load!
    config
  end

  def self.load_and_set_settings(*files)
    reset_const(Config.load_files(files))
  end

  def self.load_and_set_settings_from_db(*tables)
    reset_const(Config.load_tables(tables))
  end

  def self.load_and_set_custom_settings(options = {})
    files = options.fetch(:files, [])
    tables = options.fetch(:tables, [])
    files_data = Config.load_files(files)
    tables_data = Config.load_tables(tables)
    data = files_data.merge!(tables_data.to_h)
    reset_const(data)
  end

  # Loads and sets the settings constant!
  def self.reset_const(data)
    name = Config.const_name
    Object.send(:remove_const, name) if Object.const_defined?(name)
    Object.const_set(name, data)
  end


  def self.setting_files(config_root, env)
    [
      File.join(config_root, 'settings.yml').to_s,
      File.join(config_root, 'settings', "#{env}.yml").to_s,
      File.join(config_root, 'environments', "#{env}.yml").to_s,
      *local_setting_files(config_root, env)
    ].freeze
  end

  def self.local_setting_files(config_root, env)
    [
      (File.join(config_root, 'settings.local.yml').to_s if env != 'test'),
      File.join(config_root, 'settings', "#{env}.local.yml").to_s,
      File.join(config_root, 'environments', "#{env}.local.yml").to_s
    ].compact
  end

  def self.reload!
    Object.const_get(Config.const_name).reload!
  end
end

# Rails integration
require('config/integrations/rails/railtie') if defined?(::Rails)

# Sinatra integration
require('config/integrations/sinatra') if defined?(::Sinatra)
