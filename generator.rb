# Get the path of the application template
path = __dir__

# Questions
api_mode = yes? 'Will we work on api mode?'
simple_command = yes? 'Will we use service objects with simple_command?'
paperclip = yes? 'Will we use paperclip?'
friendly_id = yes? 'Will we use slugs with friendly id?'
change_template_language = yes? 'Will we use other template language?'
admin_database = yes? 'Will we use an web admin database?'
devise = yes? 'Will we authenticate with devise?'

# Global Gems
gem 'kaminari'
gem 'mail'
gem 'rails_12factor'

gem 'devise' if devise

if api_mode
  gem 'active_model_serializers'
  gem 'jwt'
  gem 'rack-cors', require: 'rack/cors'
end

gem 'simple_command' if simple_command

gem 'paperclip', '~> 5.0.0' if paperclip

gem 'friendly_id' if friendly_id

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
                           limited_to: %w[administrate rails_admin activeadmin])
  case web_admin_database
  when 'administrate'
    gem 'administrate'
  when 'rails_admin'
    gem 'rails_admin'
  when 'activeadmin'
    gem 'activeadmin', github: 'gregbell/active_admin'
  end
end

# Development Gems
gem_group :development do
  gem 'annotate'
  gem 'auto_annotate'
  gem 'autorefresh'
  gem 'awesome_print'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman'
  gem 'guard'
  gem 'guard-livereload', require: false
  gem 'hirb'
  gem 'hookup'
  gem 'letter_opener'
  gem 'meta_request'
  gem 'populator'
  gem 'pry-rails'
  gem 'rack-livereload'
  gem 'richrc'
  gem 'rubocop', require: false
end

# Test Gems
gem_group :test do
  gem 'minitest-osx'
  gem 'minitest-reporters'
  gem 'mocha', require: false
  gem 'shoulda'
end

# Config test helper
insert_into_file 'test/test_helper.rb', after: 'rails/test_help\n' do
  "require 'minitest/pride'\n"
  "require 'minitest/reporters'\n"
end

# Set postgres as my default database
gsub_file 'Gemfile', "gem 'sqlite3'", "gem 'pg'"
database_name = ask("What would you like the database to be called? Press <enter> for #{app_name}")
database_name = app_name.to_s if database_name.blank?
run 'rm config/database.yml'
run "cp #{path}/templates/database.yml.example config/database.yml"
gsub_file 'config/database.yml', 'application_database', database_name.to_s

# Database credentials
database_user_name = ask('Enter the database user name. Press <enter> to skip.')
gsub_file 'config/database.yml', '#user: database_user_name', "user: #{database_user_name}" unless database_user_name.empty?
database_user_password = ask('Enter the database user password. Press <enter> to skip.')
gsub_file 'config/database.yml', '#password: database_user_password', "password: #{database_user_password}" unless database_user_password.empty?

# Run bundle to install gems
run 'bundle'

# Create the database
rake 'db:create'

# Run administrate installer
if admin_database && web_admin_database == 'administrate'
  generate 'administrate:install'
end

# Generate a pages controller
pages_controller = yes? 'Will we use pages controller?'
generate(:controller, 'pages about home help') if pages_controller

# Set the default controller/action application
route "root to: 'pages#home'" if pages_controller

# Install devise
if devise
  generate 'devise:install'
  generate 'devise User'
end

# Config rack cors
if api_mode
  run "cp #{path}/templates/config/initializers/cors.rb config/initializers/cors.rb"
end

# Install rails admin
if admin_database && admin_database == 'rails_admin'
  generate 'rails_admin:install'
end

# Ask me if we want to run migration
rake('db:migrate') if yes?('Run db:migrate?')

# Config Guard
run 'guard init'

# Congig Rack-LiveReload
insert_into_file 'config/environments/development.rb', before: /^end/ do
  "  # From https://github.com/johnbintz/rack-livereload\n  config.middleware.use Rack::LiveReload\n"
end

# Git
run "cp #{path}/templates/.gitignore .gitignore"
git :init
git add: '.'
git commit: "-a -m 'Initial commit'"

# Run the server
run 'bundle exec spring rails s'
