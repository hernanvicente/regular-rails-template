# Questions
admin_database = yes? "Will we use an web admin database?"

# Global Gems
gem 'aws-s3'
gem 'devise'
gem 'foreman'
gem 'friendly_id'
gem 'kaminari'
gem 'mail'
gem 'paperclip'
gem 'slim-rails'

# Check and add admin
if admin_database
    web_admin_database = ask("What is your favorite web admin database?", :limited_to => ["rails_admin", "activeadmin"])
  case web_admin_database
    when "rails_admin"
      gem 'rails_admin'
    when "activeadmin"
      gem 'activeadmin', github: 'gregbell/active_admin'
  end
end

# Development Gems
gem_group :development do
  gem 'annotate'
  gem 'auto_annotate'
  gem 'autorefresh'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman'
  gem 'bullet'
  gem 'guard'
  gem 'guard-livereload', require:false
  gem 'hirb'
  gem 'hookup'
  gem 'jazz_hands'
  gem 'letter_opener'
  gem 'populator'
  gem 'pry-rails'
  gem 'quiet_assets'
  gem 'rack-livereload'
  gem 'richrc'
  gem 'spring'
  gem 'uniform_notifier'
end

# Test Gems
gem_group :test do
  gem "shoulda"
end

# Set postgres as my default database
gsub_file 'Gemfile', "gem 'sqlite3'", "gem 'pg'"
database_name = ask("What would you like the database to be called? Press <enter> for #{app_name}")
database_name = "#{app_name}" if database_name.blank?
run "cp ../templates/database.yml.example config/database.yml"
gsub_file 'config/database.yml', "application_database", "#{database_name}"

# Database credentials
database_user_name = ask("Enter the database user name. Press <enter> to skip.")
gsub_file 'config/database.yml', "#user: database_user_name", "user: #{database_user_name}" unless database_user_name.empty?
database_user_password = ask("Enter the database user password. Press <enter> to skip.")
gsub_file 'config/database.yml', "#password: database_user_password", "password: #{database_user_password}" unless database_user_password.empty?

# Run bundle to install gems
run "bundle"

# Create the database
rake "db:create"

# Generate a pages controller
pages_controller = yes? 'Will we use pages controller?'
generate(:controller, "pages about home help") if pages_controller

# Set the default controller/action application
route "root to: 'pages#home'" if pages_controller

# Remove README.rdoc
run "rm README.rdoc"

# Install devise
generate "devise:install"
generate "devise User"

# Install rails admin
if admin_database && admin_database == 'rails_admin'
  generate "rails_admin:install"
end



# Ask me if we want to run migration
rake("db:migrate") if yes?("Run db:migrate?")

# Config Guard
run "guard init"
# Congig Rack-LiveReload
insert_into_file "config/environments/development.rb", :before => /^end/ do
  "  # From https://github.com/johnbintz/rack-livereload\n  config.middleware.use Rack::LiveReload\n"
end

# Git
run "cp ../templates/.gitignore .gitignore"
git :init
git add: "."
git commit: "-am 'First commit!'"

# Run the server
run "bundle exec spring rails s"
