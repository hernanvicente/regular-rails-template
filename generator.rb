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
gem 'simple_command' if simple_command
gem 'friendly_id' if friendly_id
gem 'sitemap_generator', '~> 6.0', '>= 6.0.1' if sitemap

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
  gem 'jsonapi-serializer'
  gem 'jwt'
  gem 'rack-cors', require: 'rack/cors'
end

if change_template_language
  template_language = ask('Which template engine would you like to use?',
                          limited_to: %w[slim haml])
  case template_language
  when 'slim'
    gem 'slim-rails'
  when 'haml'
    gem 'haml-rails'
  end
end

if admin_database
  web_admin_database = ask('What is your favorite web admin database?',
                           limited_to: %w[activeadmin administrate rails_admin trestle])
  case web_admin_database
  when 'activeadmin'
    gem 'activeadmin' # https://github.com/activeadmin/activeadmin
  when 'administrate'
    gem 'administrate' # https://github.com/thoughtbot/administrate
  when 'rails_admin'
    gem 'rails_admin', '~> 3.0' # https://github.com/railsadminteam/rails_admin
  when 'trestle'
    gem 'trestle' # https://github.com/TrestleAdmin/trestle
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
  gem 'dotenv'
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
  gem 'shoulda-matchers', '~> 5.0'
end

gem_group :development, :test do
  gem 'factory_bot_rails'
  gem 'ffaker'
end


# Config test environment
insert_into_file 'test/test_helper.rb', after: "require rails/test_help\n" do
  "require 'minitest/pride'\n"
  "require 'minitest/reporters'\n"
end


# Database setup for Postgres
gsub_file 'Gemfile', /gem "sqlite3".*$/, "gem 'pg'"

database_default_host = 'localhost'
database_default_port = 5432
database_host = ask("Enter your database host: Press <enter> for #{database_default_host}")
database_port = ask("Enter your database port: Press <enter> for #{database_default_port}")
database_prefix = ask("Enter the database prefix i.e 'garden' for 'garden_development' and 'garden_test') or press <enter> to use #{app_name} as prefix")
database_username = ask("Enter the database username")
database_password = ask("Enter the database password")

database_name = database_prefix.blank? ? app_name.to_s : database_prefix
puts '----- database_name -----'
puts database_prefix
puts app_name.to_s
puts '----- database_name -----'

run "cp #{path}/templates/database.yml.example config/database.yml"
gsub_file 'config/database.yml', 'app_db_database_development', "#{database_name}_development"
gsub_file 'config/database.yml', 'app_db_database_test', "#{database_name}_test"

run "cp #{path}/templates/.env.example .env"
gsub_file '.env', 'app_db_host', database_name
gsub_file '.env', 'app_db_port', database_port
gsub_file '.env', 'app_db_username', database_username
gsub_file '.env', 'app_db_password', database_password
gsub_file '.env', 'app_db_database', "#{database_name}_development"
gsub_file '.env', 'app_db_test_database', "#{database_name}_test"


# Run bundle to install gems
run 'bundle'


# Create the database
rake 'db:create'


# Generate a pages controller
pages_controller = yes? 'Will we use pages controller?'
generate(:controller, 'pages about home help') if pages_controller


# Set the default controller/action application
route "root to: 'pages#home'" if pages_controller


# Install authentication
def add_devise
  generate 'devise:install'
  generate 'devise User'
  rake('db:migrate')
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
              env: 'development'
end

def add_activeadmin
  generate 'active_admin:install'
end

def add_trestle
  generate 'trestle:install'
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


# Webpacker
rails_command 'webpacker:install'


# Git
run "cp #{path}/templates/.gitignore .gitignore"
git :init
git add: '.'
git commit: "-a -m 'Initial commit'"


# Run the server
run 'bundle exec rails s'
