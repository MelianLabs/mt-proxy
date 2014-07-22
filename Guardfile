# More info at https://github.com/guard/guard#readme

guard :bundler do
  watch('Gemfile')
  watch(/^.+\.gemspec/)
end

guard 'pow' do
  watch('.powrc')
  watch('.powenv')
  watch('.rvmrc')
  watch('.ruby-version')
  watch('Gemfile')
  watch('Gemfile.lock')
  watch(%r{^lib/.*\.rb$})
  watch(%r{^config.ru$})
end

guard :rspec, cmd: 'bundle exec rspec -r spec_helper' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }

end
