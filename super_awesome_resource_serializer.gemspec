# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "super_awesome_resource_serializer"
  s.version = "1.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Brian Durand"]
  s.date = "2012-06-06"
  s.description = "Quickly create custom serializations for resources rather than relying on the generated ones."
  s.email = ["mdobrota@tribune.com", "bdurand@tribune.com"]
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    "License.txt",
    "README.rdoc",
    "Rakefile",
    "lib/super_awesome_resource_serializer.rb",
    "spec/super_awesome_resource_serializer_spec.rb"
  ]
  s.rdoc_options = ["--line-numbers", "--inline-source", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.10"
  s.summary = "Quickly create custom serializations for resources"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 2.0.0"])
    else
      s.add_dependency(%q<activesupport>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 2.0.0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 2.0.0"])
  end
end

