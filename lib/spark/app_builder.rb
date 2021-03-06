module Spark
  class AppBuilder < Rails::AppBuilder
    include Spark::Actions

    def readme
      template 'README.md.erb', 'README.md'
    end

    def raise_on_delivery_errors
      replace_in_file 'config/environments/development.rb',
        'raise_delivery_errors = false', 'raise_delivery_errors = true'
    end

    def set_test_delivery_method
      config = <<-RUBY

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = { :address => "localhost", :port => 1025 }
      RUBY

      inject_into_file(
        "config/environments/development.rb",
        config,
        after: "config.action_mailer.raise_delivery_errors = true",
      )
    end

    def raise_on_unpermitted_parameters
      config = <<-RUBY
    config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      inject_into_class "config/application.rb", "Application", config
    end

    def provide_setup_script
      template "bin/setup.erb", "bin/setup", force: true
      run "chmod a+x bin/setup"
    end

    def provide_dev_prime_task
      copy_file 'tasks/development_seeds.rake', 'lib/tasks/development_seeds.rake'
    end

    def configure_generators
      config = <<-RUBY

    config.generators do |generate|
      generate.helper false
      generate.javascript_engine false
      generate.request_specs false
      generate.routing_specs false
      generate.stylesheets false
      generate.test_framework :rspec
      generate.view_specs false
    end

      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def set_up_factory_girl_for_rspec
      copy_file 'spec/support/factory_girl_rspec.rb', 'spec/support/factory_girl.rb'
    end

    def configure_exception_notification
      template 'config/initializers/exception_notification.rb.erb',
        'config/initializers/exception_notification.rb'
    end

    def configure_mailsocio
      config = <<-RUBY

  config.action_mailer.delivery_method = :mailsocio
  config.action_mailer.smtp_settings = {
    account_id: ENV.fetch("MAILSOCIO_ACCOUNT_ID"),
    api_key: ENV.fetch("MAILSOCIO_API_KEY")
  }
      RUBY

      inject_into_file 'config/environments/production.rb', config,
        :after => 'config.action_mailer.raise_delivery_errors = false'
    end

    def setup_asset_host
      replace_in_file 'config/environments/production.rb',
        "# config.action_controller.asset_host = 'http://assets.example.com'",
        'config.action_controller.asset_host = ENV.fetch("ASSET_HOST", ENV.fetch("HOST"))'

      replace_in_file 'config/initializers/assets.rb',
        "config.assets.version = '1.0'",
        'config.assets.version = ENV.fetch("ASSETS_VERSION", "1.0")'

      inject_into_file(
        "config/environments/production.rb",
        '  config.static_cache_control = "public, max-age=#{1.year.to_i}"',
        after: serve_static_files_line
      )
    end

    def setup_secret_token
      template 'config/rails_secrets.yml', 'config/secrets.yml', force: true
    end

    def disallow_wrapping_parameters
      remove_file "config/initializers/wrap_parameters.rb"
    end

    def create_partials
      empty_directory 'app/views/application'

      copy_file 'views/application/_flashes.html.erb',
        'app/views/application/_flashes.html.erb'
      copy_file 'views/application/_javascript.html.erb',
        'app/views/application/_javascript.html.erb'
      copy_file 'views/application/_navigation.html.erb',
        'app/views/application/_navigation.html.erb'
      copy_file 'views/application/_navigation_links.html.erb',
        'app/views/application/_navigation_links.html.erb'
      copy_file 'views/application/_analytics.html.erb',
        'app/views/application/_analytics.html.erb'
      copy_file 'views/application/_footer.html.erb',
        'app/views/application/_footer.html.erb'
    end

    def create_home_page
      copy_file 'views/pages/home.html.erb',
        'app/views/pages/home.html.erb'
    end

    def create_application_layout
      remove_file 'app/views/layouts/application.html.erb'
      template 'views/layouts/application.html.erb.erb',
        'app/views/layouts/application.html.erb', force: true
    end

    def use_postgres_config_template
      template 'config/postgresql_database.yml.erb', 'config/database.yml',
        force: true
    end

    def create_database
      bundle_command 'exec rake db:create db:migrate'
    end

    def replace_gemfile
      remove_file 'Gemfile'
      template 'Gemfile.erb', 'Gemfile'
    end

    def set_ruby_to_version_being_used
      create_file '.ruby-version', "#{::RUBY_VERSION}\n"
    end

    def enable_database_cleaner
      copy_file 'spec/support/database_cleaner_rspec.rb', 'spec/support/database_cleaner.rb'
    end

    def configure_spec_support_features
      empty_directory_with_keep_file 'spec/lib'
      empty_directory_with_keep_file 'spec/features'

      empty_directory_with_keep_file 'spec/support/matchers'
      empty_directory_with_keep_file 'spec/support/mixins'
      empty_directory_with_keep_file 'spec/support/shared_examples'
      empty_directory_with_keep_file 'spec/support/features'
    end

    def configure_rspec
      remove_file "spec/rails_helper.rb"
      remove_file "spec/spec_helper.rb"
      copy_file "spec/rails_helper.rb", "spec/rails_helper.rb"
      copy_file "spec/spec_helper.rb", "spec/spec_helper.rb"
    end

    def configure_jasmine_rails
      bundle_command "exec rails generate jasmine_rails:install"
    end

    def add_jasmine_spec_sample
      copy_file "spec/javascripts/application.spec.js", "spec/javascripts/application.spec.js"
    end

    def configure_i18n_for_missing_translations
      raise_on_missing_translations_in("development")
      raise_on_missing_translations_in("test")
    end

    def configure_background_jobs_for_rspec
      run 'rails g delayed_job:active_record'
    end

    def configure_action_mailer_in_specs
      copy_file 'spec/support/action_mailer.rb', 'spec/support/action_mailer.rb'
    end

    def configure_time_formats
      remove_file "config/locales/en.yml"
      template "config/locales/en/formats.yml.erb", "config/locales/en/formats.yml"
    end

    def configure_simple_form
      # Here we suppress simple_form warning that simple_form hasn't been configured
      bundle_command "exec rails generate simple_form:install --bootstrap > /dev/null 2>&1"
    end

    def configure_action_mailer
      action_mailer_host "development", %{"localhost:3000"}
      action_mailer_host "test", %{"www.example.com"}
      action_mailer_host "production", %{ENV.fetch("HOST")}
    end

    def configure_active_job
      configure_application_file(
        "config.active_job.queue_adapter = :delayed_job"
      )
      configure_environment "test", "config.active_job.queue_adapter = :inline"
    end

    def fix_i18n_deprecation_warning
      config = <<-RUBY
    config.i18n.enforce_available_locales = true
      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def configure_locales_load_from_folders
      config = <<-RUBY
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
      RUBY

      gsub_file 'config/application.rb', /config\.i18n\.load_path.+/, config
      uncomment_lines 'config/application.rb', /config\.i18n\.load_path/
    end

    def generate_rspec
      generate 'rspec:install'
    end

    def setup_foreman
      copy_file 'Procfile', 'Procfile'
    end

    def setup_figaro
      copy_file 'config/application.yml.sample', 'config/application.yml.sample'
    end

    def setup_stylesheets
      remove_file 'app/assets/stylesheets/application.css'
      copy_file 'assets/application.scss',
        'app/assets/stylesheets/application.scss'
    end

    def setup_javascripts
      remove_file 'app/assets/javascripts/application.js'
      copy_file 'assets/application.js',
        'app/assets/javascripts/application.js'
    end

    def gitignore_files
      remove_file '.gitignore'
      copy_file 'dot_gitignore', '.gitignore'
    end

    def init_git
      run 'git init'
    end

    def setup_bundler_audit
      copy_file "tasks/bundler_audit.rake", "lib/tasks/bundler_audit.rake"
      append_file "Rakefile", %{\ntask default: "bundler:audit"\n}
    end

    def copy_miscellaneous_files
      copy_file "config/initializers/errors.rb", "config/initializers/errors.rb"
      copy_file "config/initializers/json_encoding.rb", "config/initializers/json_encoding.rb"
    end

    def customize_error_pages
      meta_tags =<<-EOS
  <meta charset="utf-8" />
  <meta name="ROBOTS" content="NOODP" />
  <meta name="viewport" content="initial-scale=1" />
      EOS

      %w(500 404 422).each do |page|
        inject_into_file "public/#{page}.html", meta_tags, :after => "<head>\n"
        replace_in_file "public/#{page}.html", /<!--.+-->\n/, ''
      end
    end

    def remove_routes_comment_lines
      replace_in_file 'config/routes.rb',
        /Rails\.application\.routes\.draw do.*end/m,
        "Rails.application.routes.draw do\nend"
    end

    def add_root_route
      route "root 'high_voltage/pages#show', id: 'home'"
    end

    def disable_xml_params
      copy_file 'config/initializers/disable_xml_params.rb',
        'config/initializers/disable_xml_params.rb'
    end

    def setup_default_rake_task
      append_file 'Rakefile' do
        <<-EOS
task(:default).clear
task default: [:spec]

if defined? RSpec
  task(:spec).clear
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.verbose = false
  end
end
        EOS
      end
    end

    def run_bin_setup
      run "./bin/setup"
    end

    private

    def raise_on_missing_translations_in(environment)
      config = 'config.action_view.raise_on_missing_translations = true'

      uncomment_lines("config/environments/#{environment}.rb", config)
    end

    def override_path_for_tests
      if ENV['TESTING']
        support_bin = File.expand_path(File.join('..', '..', 'spec', 'fakes', 'bin'))
        "PATH=#{support_bin}:$PATH"
      end
    end

    def generate_secret
      SecureRandom.hex(64)
    end

    def serve_static_files_line
      "config.serve_static_files = ENV['RAILS_SERVE_STATIC_FILES'].present?\n"
    end
  end
end
