module Wordmove
  module Actions
    module Ssh
      module WpcliAdapter
        class AdaptRemoteDb
          extend ::LightService::Action
          include Wordmove::Actions::Helpers
          include Wordmove::Wpcli

          expects :local_options,
                  :remote_options,
                  :cli_options,
                  :logger,
                  :photocopier,
                  :db_paths

          executed do |context| # rubocop:disable Metrics/BlockLength
            context.logger.task 'Pull and adapt remote DB'

            unless wp_in_path?
              raise UnmetPeerDependencyError, 'WP-CLI is not installed or not in your $PATH'
            end

            next context if simulate?(cli_options: context.cli_options)

            Wordmove::Actions::Ssh::DownloadRemoteDb.execute(context)

            Wordmove::Actions::RunLocalCommand.execute(
              cli_options: context.cli_options,
              logger: context.logger,
              command: uncompress_command(file_path: context.db_paths.local.gzipped_path)
            )

            Wordmove::Actions::RunLocalCommand.execute(
              cli_options: context.cli_options,
              logger: context.logger,
              command: mysql_import_command(
                dump_path: context.db_paths.local.path,
                env_db_options: context.local_options[:database]
              )
            )

            if context.cli_options[:no_adapt]
              context.logger.warn 'Skipping DB adapt'
              next context
            end

            Wordmove::Actions::RunLocalCommand.execute(
              cli_options: context.cli_options,
              logger: context.logger,
              command: wpcli_search_replace_command(context, :vhost)
            )

            Wordmove::Actions::RunLocalCommand.execute(
              cli_options: context.cli_options,
              logger: context.logger,
              command: wpcli_search_replace_command(context, :wordpress_path)
            )
          end
        end
      end
    end
  end
end
