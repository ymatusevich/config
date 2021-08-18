require 'yaml'
require 'erb'

module Config
  module Sources
    class DbSource
      attr_reader :table, :config_line, :db_config

      def initialize(table)
        @table = table.to_s
        @db_config = File.read(Config.database_yml_path)
      end

      # returns a config hash from the YML file
      def load
        config = YAML.load(db_config)[Rails.env]
        connection_pool = ActiveRecord::Base.establish_connection(config)

        if table && connection_pool.connection && connection_pool.connected? && connection_pool.connection.table_exists?(table)
          sql = "select `#{Config.key_key}`, `#{Config.value_key}` from #{table};"
          file_contents = { table => parse_values(ActiveRecord::Base.connection.execute(sql).to_h) }
          result = file_contents.with_indifferent_access
        end

        connection_pool.connection.close if connection_pool.connected?

        result || {}
      rescue ActiveRecord::NoDatabaseError
        {}
      end

      def parse_values(file_contents)
        return file_contents if file_contents.blank?

        file_contents.each { |k, v| (@config_line = k) && (file_contents[k] = YAML.load(v)) }
      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing config item #{config_line}. " \
                "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                "Error: #{e.message}"
      end
    end
  end
end
