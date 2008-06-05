require 'rake/clean'
require 'rake/rdoctask'
require 'rake/testtask'

Rake::RDocTask.new(:doc) do |doc|
  doc.title    = 'pathname3'
  doc.main     = 'README'
  doc.rdoc_dir = 'doc'
  doc.rdoc_files.include(doc.main, 'lib/**/*.rb')
end

Rake::TestTask.new do |test|
  test.test_files = %w{test/lib/test_pathname3.rb}
  test.verbose    = true
  test.warning    = true
end

task :clean => :clobber_doc