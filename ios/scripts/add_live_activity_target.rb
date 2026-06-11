#!/usr/bin/env ruby
# Adds the GoalDiggerLiveActivity widget-extension target to GoalDigger.xcodeproj.
# Idempotent + re-runnable: skips creation if the target exists, but always
# re-asserts build settings, file membership, the app dependency, and the
# "Embed Foundation Extensions" copy-files phase.
#
# Run from anywhere:  ruby ios/scripts/add_live_activity_target.rb
# Requires the `xcodeproj` gem (already installed: 1.27.0).

require 'xcodeproj'

PROJECT  = File.expand_path(File.join(__dir__, '..', 'GoalDigger.xcodeproj'))
APP_NAME = 'GoalDigger'
EXT_NAME = 'GoalDiggerLiveActivity'
EXT_BID  = 'com.goaldigger.app.LiveActivity'
TEAM     = 'XG9549JP5L'
GROUP_REL = 'GoalDigger/LiveActivity' # relative to the project source root (ios/)

project = Xcodeproj::Project.open(PROJECT)

app = project.targets.find { |t| t.name == APP_NAME }
abort("App target #{APP_NAME} not found") unless app

ext = project.targets.find { |t| t.name == EXT_NAME }
if ext
  puts "Target #{EXT_NAME} already present — re-asserting settings/files."
else
  ext = project.new_target(:app_extension, EXT_NAME, :ios, '17.0')
  puts "Created target #{EXT_NAME}."
end

# --- Build settings (both Debug + Release) ---------------------------------
ext.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER']   = EXT_BID
  s['PRODUCT_NAME']                = '$(TARGET_NAME)'
  s['INFOPLIST_FILE']              = "#{GROUP_REL}/Info.plist"
  s['IPHONEOS_DEPLOYMENT_TARGET']  = '17.0'
  s['DEVELOPMENT_TEAM']            = TEAM
  s['CODE_SIGN_STYLE']             = 'Automatic'
  s['SWIFT_VERSION']               = '5.0'
  s['TARGETED_DEVICE_FAMILY']      = '1'
  s['MARKETING_VERSION']           = '1.0'
  s['CURRENT_PROJECT_VERSION']     = '4'
  s['SKIP_INSTALL']                = 'YES'
  s['GENERATE_INFOPLIST_FILE']     = 'NO'
  s['ENABLE_PREVIEWS']             = 'YES'
  s['CODE_SIGN_IDENTITY']          = 'Apple Development'
  s['LD_RUNPATH_SEARCH_PATHS']     = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  # Do NOT inherit the app's Configuration.xcconfig (SUPABASE_* vars are
  # irrelevant to the extension); leave baseConfigurationReference unset.
end

# --- Files + group ---------------------------------------------------------
grp = project.main_group.groups.find { |g| g.display_name == 'LiveActivity' } ||
      project.main_group.new_group('LiveActivity', GROUP_REL)

def file_in(group, name)
  group.files.find { |f| f.display_name == name } || group.new_file(name)
end

attrs    = file_in(grp, 'MatchActivityAttributes.swift') # shared (app + ext)
bundle   = file_in(grp, 'LiveActivityBundle.swift')      # ext only
activity = file_in(grp, 'MatchLiveActivity.swift')       # ext only
manager  = file_in(grp, 'LiveActivityManager.swift')     # app only
snapshot = file_in(grp, 'LiveMatchSnapshot.swift')       # app only
file_in(grp, 'Info.plist')                               # ref only, not compiled

# Compile membership (add_file_reference(ref, avoid_duplicates=true))
[attrs, bundle, activity].each { |r| ext.source_build_phase.add_file_reference(r, true) }
[attrs, manager, snapshot].each { |r| app.source_build_phase.add_file_reference(r, true) }

# --- App depends on the extension ------------------------------------------
app.add_dependency(ext) unless app.dependencies.any? { |d| d.target == ext }

# --- Embed the .appex into the app (Embed Foundation Extensions) ------------
EMBED = 'Embed Foundation Extensions'
embed = app.copy_files_build_phases.find { |p| p.name == EMBED }
unless embed
  embed = app.new_copy_files_build_phase(EMBED)
  embed.symbol_dst_subfolder_spec = :plug_ins
end
unless embed.files.any? { |bf| bf.file_ref == ext.product_reference }
  bf = embed.add_file_reference(ext.product_reference, true)
  bf.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy CodeSignOnCopy] }
end

project.save
puts "Wired #{EXT_NAME}: settings, files, dependency, embed phase. Saved."
