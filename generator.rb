# Questions
rails_admin = yes? 'Will we use rails admin?'

# Global Gems
gem 'aws-s3'
gem 'devise'
gem 'foreman'
gem 'friendly_id'
gem 'kaminari'
gem 'mail'
gem 'paperclip'
gem 'slim-rails'

# Check and add rails_admin
if rails_admin
  gem 'rails_admin'
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
  gem 'hirb'
  gem 'hookup'
  gem 'jazz_hands'
  gem 'pry-rails'
  gem 'quiet_assets'
  gem 'richrc'
  gem 'spring'
  gem 'uniform_notifier'
end

# Test Gems
gem_group :test do
  gem "rspec-rails"
end

# Set postgres as my default database
gsub_file 'Gemfile', "gem 'sqlite3'", "gem 'pg'"
database_name = ask("What would you like the database to be called? Press <enter> for #{app_name}")
database_name = "#{app_name}" if database_name.blank?
run "cp ../templates/database.yml.example config/database.yml"
gsub_file 'config/database.yml', "application_database", "#{database_name}"

# Create the database
rake "db:create"

# Run bundle to install gems
run "bundle"

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
generate "rails_admin:install"

# Ask me if we want to run migration
rake("db:migrate") if yes?("Run db:migrate?")

# Git
run "cp ../templates/.gitignore .gitignore"
git :init
git add: "."
git commit: "-am 'First commit!'"

# Run the server
run "bundle exec spring rails s"
