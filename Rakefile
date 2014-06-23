

Rake::TaskManager.record_task_metadata = true

# Main namespace for building

namespace :docs do
  desc "Generate documentation"
  task :generate do 
    sh "bundle exec yardoc -e 3rdparty/yardoc-sinatra.rb transmuter.rb lib/* spells/* models/*"
  end

  desc "Show what needs documentation"
  task :todo do 
    sh "bundle exec yardoc -e 3rdparty/yardoc-sinatra.rb  stats --list-undoc transmuter.rb lib/* spells/* models/*"
  end

end

namespace :demo do
desc "Setup for demo"
  task :setup do 
    sh "cp config/collins.yml.example config/collins.yml"
  end
end

desc "Print a detailed help with usage examples"
task :help do

  help = <<-eos
So far just used to generate docs

  rake docs
  eos
  puts help

end

# Print the help if no arguments are given
task :default do
  Rake::application.options.show_tasks = :tasks  
  Rake::application.options.show_task_pattern = //
  Rake::application.display_tasks_and_comments
end
