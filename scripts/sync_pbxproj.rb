# Registers or removes Swift source files in the Xcode project (the project uses
# explicit PBXFileReference entries, not synchronized folders, so a file on disk
# is not compiled until it is listed here). Requires the xcodeproj gem.
#
# Usage: ruby scripts/sync_pbxproj.rb "Gecko Climbing.xcodeproj" add:<path> ... remove:<path> ...
# Paths are relative to the "Gecko Climbing" source folder, e.g. Shared/Components/FollowButton.swift.
require "xcodeproj"

proj_path = ARGV.shift
project = Xcodeproj::Project.open(proj_path)
target = project.targets.find { |t| t.name == "Gecko Climbing" } or abort("target not found")
source_root = project.main_group.children.find { |g| g.respond_to?(:path) && g.path == "Gecko Climbing" } or abort("source group not found")

def find_or_create_group(parent, name)
  parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.path == name || c.name == name) } || parent.new_group(name, name)
end

ARGV.each do |arg|
  op, rel = arg.split(":", 2)
  parts = rel.split("/")
  file = parts.pop
  group = parts.inject(source_root) { |g, name| find_or_create_group(g, name) }
  existing = group.files.find { |f| f.path == file }
  case op
  when "add"
    if existing
      puts "skip (exists): #{rel}"
    else
      ref = group.new_file(file)
      target.source_build_phase.add_file_reference(ref, true)
      puts "added: #{rel}"
    end
  when "remove"
    if existing
      target.source_build_phase.remove_file_reference(existing)
      existing.remove_from_project
      puts "removed: #{rel}"
    else
      puts "skip (missing): #{rel}"
    end
  end
end
project.save
puts "saved"
