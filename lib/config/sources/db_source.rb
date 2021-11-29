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

      def load
        Thread.current[:current_configs] = nil

        Thread.current do
          connection_pool = ActiveRecord::Base.connection_pool
          connection = connection_pool.retrieve_connection

          if table && connection && connection_pool.connected? && connection.table_exists?(table)
            sql = "select `#{Config.key_key}`, `#{Config.value_key}` from #{table};"
            file_contents = { table => parse_values(connection.execute(sql).to_h) }
            result = file_contents.with_indifferent_access
          end

          connection_pool.connection.close if connection_pool.active_connection?
          connection_pool.disconnect! if connection_pool.connected?

          Thread.current[:current_configs] = result.presence
        end

        Thread.current[:current_configs] || {}
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
