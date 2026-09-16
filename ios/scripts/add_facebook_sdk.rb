#!/usr/bin/env ruby
# Adds the Facebook iOS SDK (FacebookCore only — app events + SKAdNetwork, no
# Login) to GoalDigger.xcodeproj, and bumps the ship version to 2.2 (build 11).
# Idempotent + re-runnable: re-asserts the package reference, the product
# dependency and the link phase entry rather than duplicating them.
#
#   ruby ios/scripts/add_facebook_sdk.rb
#   xcodebuild -resolvePackageDependencies -project ios/GoalDigger.xcodeproj -scheme GoalDigger
#
# NEVER hand-edit project.pbxproj — see IOS_GOTCHAS.md §18.
# Requires the `xcodeproj` gem (already installed: 1.27.0).

require 'xcodeproj'

PROJECT      = File.expand_path(File.join(__dir__, '..', 'GoalDigger.xcodeproj'))
APP_NAME     = 'GoalDigger'
REPO         = 'https://github.com/facebook/facebook-ios-sdk'
MIN_VERSION  = '18.1.1'
PRODUCT      = 'FacebookCore' # the SPM product behind `import FBSDKCoreKit`
MARKETING    = '2.2'
BUILD_NUMBER = '11'

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == APP_NAME } or abort("target #{APP_NAME} not found")

# --- Remote package reference ----------------------------------------------
pkg = project.root_object.package_references.find do |r|
  r.is_a?(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference) && r.repositoryURL == REPO
end
unless pkg
  pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg.repositoryURL = REPO
  project.root_object.package_references << pkg
  puts "+ package  #{REPO}"
end
# Always re-assert the requirement so a version bump is a one-line edit here.
pkg.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => MIN_VERSION }

# --- Product dependency on the app target ONLY (not the Live Activity ext) --
dep = app.package_product_dependencies.find { |d| d.product_name == PRODUCT }
unless dep
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.product_name = PRODUCT
  app.package_product_dependencies << dep
  puts "+ product  #{PRODUCT} -> #{APP_NAME}"
end
dep.package = pkg

# --- Link it: a PBXBuildFile with product_ref in the Frameworks phase -------
frameworks = app.frameworks_build_phase
unless frameworks.files.any? { |bf| bf.product_ref == dep }
  bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.product_ref = dep
  frameworks.files << bf
  puts "+ link     #{PRODUCT} in Frameworks phase"
end

# --- Version bump on every target/configuration -----------------------------
project.targets.each do |t|
  t.build_configurations.each do |c|
    c.build_settings['MARKETING_VERSION'] = MARKETING
    c.build_settings['CURRENT_PROJECT_VERSION'] = BUILD_NUMBER
  end
end
puts "= version  #{MARKETING} (#{BUILD_NUMBER}) on #{project.targets.map(&:name).join(', ')}"

project.save
puts "saved #{PROJECT}"
