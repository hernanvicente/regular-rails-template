# Get the path of the application template
path = __dir__

# Questions
api_mode = yes? 'Will we work on api mode?'
simple_command = yes? 'Will we use service objects with simple_command?'
friendly_id = yes? 'Will we use slugs with friendly id?'
change_template_language = yes? 'Will we use other template language?'
admin_database = yes? 'Will we use an web admin database?'
authentication = yes? 'Will we authenticate?'
sitemap = yes? 'Will we need a sitemap generator?'
pagination = yes? 'Will we paginate with kaminari?'

# Global Gems
gem 'kaminari' if pagination

if authentication
  authentication_gem = ask('Which authentication gem would you like to use?',
                           limited_to: %w[clearance devise sorcery])
  case authentication_gem
  when 'clearance'
    gem 'clearance'
  when 'devise'
    gem 'devise'
  when 'sorcery'
    gem 'sorcery'
  end
end

if api_mode
  gem 'active_model_serializers'
  gem 'jwt'
  gem 'rack-cors', require: 'rack/cors'
end

gem 'simple_command' if simple_command
gem 'friendly_id' if friendly_id
gem 'sitemap_generator', '~> 6.0', '>= 6.0.1' if sitemap

if change_template_language
  template_language = ask('Which template engine would you like to use?',
                          limited_to: %w[slim haml])
  case template_language
  when 'slim'
    gem 'slim-rails'
  when 'haml'
    gem 'slim-rails'
  end
end

# Check and add admin
if admin_database
  web_admin_database = ask('What is your favorite web admin database?',
                           limited_to: %w[administrate rails_admin])
  case web_admin_database
  when 'administrate'
    gem 'administrate'
  when 'rails_admin'
    gem 'rails_admin'
  end
end

# Development Gems
letter_opener = yes? 'Will use letter_opener on dev mode?'

gem_group :development do
  gem 'annotate'
  gem 'awesome_print'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman'
  gem 'ffaker'
  gem 'guard'
  gem 'guard-livereload', require: false
  gem 'guard-minitest'
  gem 'letter_opener' if letter_opener
  gem 'pry-rails'
  gem 'rack-livereload'
  gem 'rubocop', require: false
end

# Test Gems
gem_group :test do
  gem 'minitest-reporters'
  gem 'mocha', require: false
  gem 'shoulda-context'
  gem 'shoulda-matchers', '4.0.0.rc1'
end

gem_group :development, :test do
  gem 'factory_bot_rails'
end

# Config test helper
insert_into_file 'test/test_helper.rb', after: 'rails/test_help\n' do
  "require 'minitest/pride'\n"
  "require 'minitest/reporters'\n"
end

# Set postgres as my default database
db_host = 'localhost'
gsub_file 'Gemfile', /gem 'sqlite3'.*$/, "gem 'pg'"
database_name = ask("Enter your database host: Press <enter> for #{db_host}")
database_name = ask("What would you like the database to be called? Press <enter> for #{app_name}")
database_name = app_name.to_s if database_name.blank?
run 'rm config/database.yml'
run "cp #{path}/templates/database.yml.example config/database.yml"
gsub_file 'config/database.yml', 'application_database', database_name.to_s

# Database credentials
database_user_name = ask('Enter the database user name. Press <enter> to skip.')
unless database_user_name.empty?
  gsub_file 'config/database.yml', '#user: database_user_name', "user: #{database_user_name}"
end
database_user_password = ask('Enter the database user password. Press <enter> to skip.')
unless database_user_password.empty?
  gsub_file 'config/database.yml', '#password: database_user_password', "password: #{database_user_password}"
end

# Run bundle to install gems
run 'bundle'

# Create the database
rake 'db:create'

# Generate a pages controller
pages_controller = yes? 'Will we use pages controller?'
generate(:controller, 'pages about home help') if pages_controller

# Set the default controller/action application
route "root to: 'pages#home'" if pages_controller

# Install devise
def add_devise
  generate 'devise:install'
  generate 'devise User'
  rake('db:migrate')
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'
end

def add_administrate(authentication, authentication_gem)
  generate 'administrate:install'

  append_to_file 'app/assets/config/manifest.js' do
    "//= link administrate/application.css\n//= link administrate/application.js"
  end

  if authentication && authentication_gem == ('devise' || 'clearance')
    gsub_file 'app/dashboards/user_dashboard.rb',
              /email: Field::String/,
              "email: Field::String,\n    password: Field::String.with_options(searchable: false)"

    gsub_file 'app/dashboards/user_dashboard.rb',
              /FORM_ATTRIBUTES = \[/,
              "FORM_ATTRIBUTES = [\n    :password,"

    gsub_file 'app/controllers/admin/application_controller.rb',
              /# TODO Add authentication logic here\./,
              "redirect_to '/', alert: 'Not authorized.' unless user_signed_in? && current_user.admin?"
  end

  environment do
    <<-RUBY
    # Expose our application's helpers to Administrate
    config.to_prepare do
      Administrate::ApplicationController.helper #{@app_name.camelize}::Application.helpers
    end
    RUBY
  end
end

def add_sitemap
  rails_command 'sitemap:install'
end

# Config rack cors
run "cp #{path}/templates/config/initializers/cors.rb config/initializers/cors.rb" if api_mode

# Ask me if we want to run migration
rake('db:migrate') if yes?('Run db:migrate?')

# Config Guard
run 'guard init'
run 'guard init minitest'

# FactoryBot syntax methods
comment_lines 'test/test_helper.rb', /fixtures :all/
insert_into_file 'test/test_helper.rb', after: /class ActiveSupport::TestCase\n/ do
  "  include FactoryBot::Syntax::Methods\n"
end

insert_into_file 'test/test_helper.rb', after: %r{require \'rails/test_help\'\n} do
  "  Shoulda::Matchers.configure do |config|\n" \
  "    config.integrate do |with|\n" \
  "      with.test_framework :minitest\n" \
  "      with.library :rails\n" \
  "    end\n" \
  '  end'
end

# Minitest Reporters
insert_into_file 'test/test_helper.rb', after: %r{require \'rails/test_help\'\n} do
  "  require 'minitest/reporters'\n" \
  "  Minitest::Reporters.use!\n" \
  "\n"
end

# Congig Rack-LiveReload
insert_into_file 'config/environments/development.rb', before: /^end/ do
  "  # From https://github.com/johnbintz/rack-livereload\n  config.middleware.use Rack::LiveReload\n"
end

# Run devise
add_devise if authentication_gem == 'devise'

# Run admin installer
if admin_database
  add_administrate(authentication, authentication_gem) if web_admin_database == 'administrate'
end

# Sitemap
add_sitemap if sitemap

rails_command 'webpacker:install'

# Git
run "cp #{path}/templates/.gitignore .gitignore"
git :init
git add: '.'
git commit: "-a -m 'Initial commit'"

# Run the server
run 'bundle exec rails s'
