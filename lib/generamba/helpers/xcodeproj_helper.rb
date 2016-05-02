module Generamba

  # Provides a number of helper methods for working with xcodeproj gem
  class XcodeprojHelper

    # Returns a PBXProject class for a given name
    # @param project_name [String] The name of the project file
    #
    # @return [Xcodeproj::Project]
    def self.obtain_project(project_name)
      Xcodeproj::Project.open(project_name)
    end

    # Adds a provided file to a specific Project and Target
    # @param project [Xcodeproj::Project] The target xcodeproj file
    # @param targets_name [String] Array of targets name
    # @param group_path [Pathname] The Xcode group path for current file
    # @param file_path [Pathname] The file path for current file
    #
    # @return [void]
    def self.add_file_to_project_and_targets(project, targets_name, group_path, file_path)
      module_group = self.retreive_group_or_create_if_needed(group_path, project, true)

      xcode_file = self.project_file_in_group(project, module_group, file_path)

      if xcode_file == nil
        xcode_file = module_group.new_file(File.absolute_path(file_path))
      end

      file_name = File.basename(file_path)
      targets_name.each do |target|
        xcode_target = self.obtain_target(target, project)

        if self.is_compile_source?(file_name)
          xcode_target.add_file_references([xcode_file])
        elsif self.is_bundle_resource?(file_name)
          xcode_target.add_resources([xcode_file])
        end

      end
    end

    # File is a compiled source
    # @param file_name [String] String of file name
    #
    # @return [TrueClass or FalseClass]
    def self.is_compile_source?(file_name)
      File.extname(file_name) == '.m' || File.extname(file_name) == '.swift' || File.extname(file_name) == '.mm'
    end

    # File is a resource
    # @param resource_name [String] String of resource name
    #
    # @return [TrueClass or FalseClass]
    def self.is_bundle_resource?(resource_name)
      File.extname(resource_name) == '.xib' || File.extname(resource_name) == '.storyboard'
    end

    # Recursively clears children of the given group
    # @param project [Xcodeproj::Project] The working Xcode project file
    # @param group_path [Pathname] The full group path
    #
    # @return [Void]
    def self.clear_group(project, targets_name, group_path)
      module_group = self.retreive_group_or_create_if_needed(group_path, project, false)
      return unless module_group

      files_path = self.files_path_from_group(module_group, project)
      return unless files_path

      files_path.each do |file_path|
        self.remove_file_by_file_path(file_path, targets_name, project)
      end

      module_group.clear
    end

    # Finds a group in a xcodeproj file with a given path
    # @param project [Xcodeproj::Project] The working Xcode project file
    # @param group_path [Pathname] The full group path
    #
    # @return [TrueClass or FalseClass]
    def self.module_with_group_path_already_exists(project, group_path)
      module_group = self.retreive_group_or_create_if_needed(group_path, project, false)
      return module_group == nil ? false : true
    end

    private

    # Finds or creates a group in a xcodeproj file with a given path
    # @param group_path [Pathname] The full group path
    # @param project [Xcodeproj::Project] The working Xcode project file
    # @param create_group_if_not_exists [TrueClass or FalseClass] If true notexistent group will be created
    #
    # @return [PBXGroup]
    def self.retreive_group_or_create_if_needed(group_path, project, create_group_if_not_exists)
      group_names = path_names_from_path(group_path)

      final_group = project

      group_names.each do |group_name|
        next_group = final_group[group_name]
        unless next_group
          unless create_group_if_not_exists
            return nil
          end

          new_group_path = group_name
          next_group = final_group.new_group(group_name, new_group_path)
        end

        final_group = next_group
      end

      return final_group
    end

    # Returns an AbstractTarget class for a given name
    # @param target_name [String] The name of the target
    # @param project [Xcodeproj::Project] The target xcodeproj file
    #
    # @return [Xcodeproj::AbstractTarget]
    def self.obtain_target(target_name, project)
      project.targets.each do |target|
        if target.name == target_name
          return target
        end
      end

      error_description = "Cannot find a target with name #{target_name} in Xcode project".red
      raise StandardError.new(error_description)
    end

    # Splits the provided Xcode path to an array of separate paths
    # @param path The full group or file path
    #
    # @return [[String]]
    def self.path_names_from_path(path)
      paths = path.to_s.split('/')
      return paths
    end

    # Remove build file from target build phase
    # @param file_path [String] The path of the file
    # @param targets_name [String] Array of targets
    # @param project [Xcodeproj::Project] The target xcodeproj file
    #
    # @return [Void]
    def self.remove_file_by_file_path(file_path, targets_name, project)
      file_names = path_names_from_path(file_path)

      build_phases = nil

      if self.is_compile_source?(file_names.last)
        build_phases = self.build_phases_from_targets(targets_name, project)
      elsif self.is_bundle_resource?(file_names.last)
        build_phases = self.resources_build_phase_from_targets(targets_name, project)
      end

      self.remove_file_from_build_phases(file_path, build_phases)
    end

    def self.remove_file_from_build_phases(file_path, build_phases)
      return if build_phases == nil

      build_phases.each do |build_phase|
        build_phase.files.each do |build_file|
          next if build_file.nil? || build_file.file_ref.nil?

          build_file_path = self.configure_file_ref_path(build_file.file_ref)

          if build_file_path == file_path
            build_phase.remove_build_file(build_file)
          end
        end
      end
    end

    # Find and return target build phases
    # @param targets_name [String] Array of targets
    # @param project [Xcodeproj::Project] The target xcodeproj file
    #
    # @return [[PBXSourcesBuildPhase]]
    def self.build_phases_from_targets(targets_name, project)
      build_phases = []

      targets_name.each do |target_name|
        xcode_target = self.obtain_target(target_name, project)
        xcode_target.build_phases.each do |build_phase|
          if build_phase.isa == 'PBXSourcesBuildPhase'
            build_phases.push(build_phase)
          end
        end
      end

      return build_phases
    end

    # Find and return target resources build phase
    # @param targets_name [String] Array of targets
    # @param project [Xcodeproj::Project] The target xcodeproj file
    #
    # @return [[PBXResourcesBuildPhase]]
    def self.resources_build_phase_from_targets(targets_name, project)
      resource_build_phase = []

      targets_name.each do |target_name|
        xcode_target = self.obtain_target(target_name, project)
        resource_build_phase.push(xcode_target.resources_build_phase)
      end

      return resource_build_phase
    end

    # Get configure file full path
    # @param file_ref [PBXFileReference] Build file
    #
    # @return [String]
    def self.configure_file_ref_path(file_ref)
      build_file_ref_path = file_ref.hierarchy_path.to_s
      build_file_ref_path[0] = ''

      return build_file_ref_path
    end

    # Get all files path from group path
    # @param module_group [PBXGroup] The module group
    # @param project [Xcodeproj::Project] The target xcodeproj file
    #
    # @return [[String]]
    def self.files_path_from_group(module_group, project)
      files_path = []

      module_group.recursive_children.each do |file_ref|
        if file_ref.isa == 'PBXFileReference'
          file_ref_path = self.configure_file_ref_path(file_ref)
          files_path.push(file_ref_path)
        end
      end

      return files_path
    end

    # Find xcodeproj file in group with given file_path
    # @param project [Xcodeproj::Project] The working Xcode project file
    # @param module_group [PBXGroup] The module group
    # @param file_path [String] File path to search
    #
    # @return [PBXFileReference]
    def self.project_file_in_group(project, group, file_path)
      files = group.files
      return nil unless files

      files.each do |file|
        if file.real_path.to_s == File.absolute_path(file_path).to_s
          return file
        end
      end

      return nil
    end

  end
end
