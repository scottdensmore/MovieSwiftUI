#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'MovieSwift.xcodeproj'
proj = Xcodeproj::Project.open(project_path)

# Find iOS target to clone settings from
ios_target = proj.targets.find { |t| t.name == 'MovieSwift' }
abort("Could not find iOS target 'MovieSwift'") unless ios_target

# Check if macOS target already exists
if proj.targets.any? { |t| t.name == 'MovieSwiftMac' }
  puts "Target 'MovieSwiftMac' already exists, removing it first..."
  old = proj.targets.find { |t| t.name == 'MovieSwiftMac' }
  old.remove_from_project
end

# Create new macOS application target
mac_target = proj.new_target(:application, 'MovieSwiftMac', :osx, '26.0')
puts "Created target: #{mac_target.name}"

# Copy build settings from iOS target's Debug/Release configs
ios_debug = ios_target.build_configurations.find { |c| c.name == 'Debug' }
ios_release = ios_target.build_configurations.find { |c| c.name == 'Release' }

# Get the xcconfig file reference
xcconfig_ref = nil
proj.files.each do |f|
  if f.path && f.path.end_with?('MovieSwiftConfig.xcconfig')
    xcconfig_ref = f
    break
  end
end

mac_target.build_configurations.each do |config|
  # Base config from xcconfig (for TMDB_API_KEY)
  config.base_configuration_reference = xcconfig_ref if xcconfig_ref

  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.scottdensmore.film-o-matic-mac'
  config.build_settings['PRODUCT_NAME'] = 'Film-O-Matic'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['INFOPLIST_FILE'] = 'MovieSwiftMac/Info.plist'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'MovieSwiftMac/MovieSwiftMac.entitlements'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '26.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['COMBINE_HIDPI_IMAGES'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['DEVELOPMENT_TEAM'] = ios_debug.build_settings['DEVELOPMENT_TEAM'] if ios_debug.build_settings['DEVELOPMENT_TEAM']

  if config.name == 'Debug'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
  else
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
    config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
  end
end

# Add package dependencies (Backend, UI packages) - copy from iOS target
ios_target.package_product_dependencies.each do |dep|
  mac_dep = proj.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  mac_dep.product_name = dep.product_name
  mac_dep.package = dep.package
  mac_target.package_product_dependencies << mac_dep
end

# Create the MovieSwiftMac group
mac_group = proj.main_group.new_group('MovieSwiftMac', 'MovieSwiftMac')

# Add the macOS entry point file
mac_app_ref = mac_group.new_file('MovieSwiftMacApp.swift')
mac_target.source_build_phase.add_file_reference(mac_app_ref)

# Add Info.plist and entitlements (no build phase needed, just reference)
mac_group.new_file('Info.plist')
mac_group.new_file('MovieSwiftMac.entitlements')

# Copy all source files from iOS target (except HomeView.swift which has @main)
ios_entry_point = 'HomeView.swift'
skipped = []

ios_target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref

  path = file_ref.path
  next if path == ios_entry_point

  # Add the same file reference to the macOS target
  mac_target.source_build_phase.add_file_reference(file_ref)
end

# Copy resource build phase files (assets, fonts, etc.)
if ios_target.resources_build_phase
  ios_target.resources_build_phase.files.each do |build_file|
    file_ref = build_file.file_ref
    next unless file_ref
    mac_target.resources_build_phase.add_file_reference(file_ref)
  end
end

# Copy framework dependencies
ios_target.frameworks_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  # Skip UIKit-specific frameworks
  next if file_ref.path && file_ref.path.include?('UIKit')
  mac_target.frameworks_build_phase.add_file_reference(file_ref)
end

proj.save
puts "macOS target 'MovieSwiftMac' added successfully!"
puts "Source files: #{mac_target.source_build_phase.files.count}"
puts "Resource files: #{mac_target.resources_build_phase.files.count}"
