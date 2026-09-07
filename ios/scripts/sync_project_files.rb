#!/usr/bin/env ruby
# Adds every Swift file under ios/GoalDigger that the app target does not yet
# compile, and every resource folder listed in RESOURCE_FOLDERS that is not yet
# copied, to GoalDigger.xcodeproj. Idempotent — safe to run any time.
#
# Why this exists: the project is a classic pbxproj (no file-system-synchronized
# groups), so a new .swift on disk is invisible to xcodebuild until it is
# referenced. Adding files by hand-editing the pbxproj is error-prone; the
# xcodeproj gem (already installed, 1.27.0) does it correctly.
#
#   ruby ios/scripts/sync_project_files.rb
require 'xcodeproj'

PROJECT = File.expand_path(File.join(__dir__, '..', 'GoalDigger.xcodeproj'))
SRC_ROOT = File.expand_path(File.join(__dir__, '..'))          # ios/
APP_DIR  = File.join(SRC_ROOT, 'GoalDigger')                    # ios/GoalDigger
TARGET   = 'GoalDigger'
# Folder references (blue folders) copied into the bundle as directories, so
# Bundle.main.url(forResource:withExtension:subdirectory:) works.
RESOURCE_FOLDERS = ['GoalDigger/Resources/MyTurn']
# Directories whose sources belong to another target (or none).
SKIP_DIRS = ['GoalDigger/LiveActivity']

project = Xcodeproj::Project.open(PROJECT)
target  = project.targets.find { |t| t.name == TARGET } or abort("target #{TARGET} not found")
app_group = project.main_group.children.find { |g| g.path == 'GoalDigger' } or abort('GoalDigger group not found')

# Every file reference path currently in the project, relative to ios/.
known = project.files.map { |f| f.real_path.to_s rescue nil }.compact.to_set

added = 0

# --- Swift sources ---------------------------------------------------------
Dir.glob(File.join(APP_DIR, '**', '*.swift')).sort.each do |abs|
  rel = abs.sub("#{SRC_ROOT}/", '')
  next if SKIP_DIRS.any? { |d| rel.start_with?(d + '/') }
  next if known.include?(abs)

  # Walk/create the group chain matching the directory path.
  parts = File.dirname(rel).split('/')[1..] # drop leading "GoalDigger"
  group = app_group
  parts.each do |part|
    child = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.path == part || c.name == part) }
    child ||= group.new_group(part, part)
    group = child
  end
  ref = group.new_file(abs)
  target.source_build_phase.add_file_reference(ref, true)
  puts "  + source   #{rel}"
  added += 1
end

# --- Resource folder references ------------------------------------------
RESOURCE_FOLDERS.each do |rel|
  abs = File.join(SRC_ROOT, rel)
  next unless Dir.exist?(abs)
  next if known.include?(abs)
  parts = File.dirname(rel).split('/')[1..]
  group = app_group
  parts.each do |part|
    child = group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && (c.path == part || c.name == part) }
    child ||= group.new_group(part, part)
    group = child
  end
  ref = group.new_reference(abs)
  ref.last_known_file_type = 'folder'
  target.resources_build_phase.add_file_reference(ref, true)
  puts "  + folder   #{rel}"
  added += 1
end

if added.zero?
  puts 'project already in sync'
else
  project.save
  puts "saved #{PROJECT} (#{added} added)"
end
