require 'fileutils'

require 'generamba/helpers/xcodeproj_helper.rb'
require 'generamba/helpers/paths_generator.rb'

module Generamba

	# Responsible for creating the whole code module using information from the CLI
	class ModuleGenerator

		def generate_module(name, code_module, template)
			# Setting up Xcode objects
			project = XcodeprojHelper.obtain_project(code_module.xcodeproj_path)

			# Configuring file paths
			FileUtils.mkdir_p code_module.module_file_path

			if code_module.test_file_path != nil
				FileUtils.mkdir_p code_module.test_file_path
			end

			# Creating code files
			puts('Creating code files...')
			process_files_if_needed(template.code_files,
									name,
									code_module,
									template,
									project,
									code_module.project_targets,
									code_module.module_group_path,
									code_module.module_file_path)

			# Creating test files
			included_tests = code_module.test_targets && code_module.test_group_path && code_module.test_file_path

			if included_tests
				puts('Creating test files...')
				process_files_if_needed(template.test_files,
										name,
										code_module,
										template,
										project,
										code_module.test_targets,
										code_module.test_group_path,
										code_module.test_file_path)
			end

			# Saving the current changes in the Xcode project
			project.save

			test_file_path_created_message = !code_module.test_file_path ? "" : "Test file path: #{code_module.test_file_path}".green + "\n"
			test_group_path_created_message = !code_module.test_group_path ? "" : "Test group path: #{code_module.test_group_path}".green

			puts("Module successfully created!\n" +
				 "Name: #{name}".green + "\n" +
				 "Module file path: #{code_module.module_file_path}".green + "\n" +
				 "Module group path: #{code_module.module_group_path}".green + "\n" +
				 test_file_path_created_message +
				 test_group_path_created_message)
		end

		def process_files_if_needed(files, name, code_module, template, project, targets, group_path, dir_path)
			# It's possible that current project doesn't test targets configured, so it doesn't need to generate tests.
			# The same is for files property - a template can have only test or project files
			if targets.count == 0 || files == nil || files.count == 0 || dir_path == nil || group_path == nil
				return
			end

			files.each do |file|

				file_path = PathsGenerator.generate_file_path(code_module.prefix, name, file[TEMPLATE_NAME_KEY], dir_path)
				group_file_path = PathsGenerator.generate_group_path(file[TEMPLATE_NAME_KEY], file_path, group_path)

				# Generating the content of the code file
				file_content = ContentGenerator.create_file_content(file, code_module, template)

				# Creating the file in the filesystem
				FileUtils.mkdir_p File.dirname(file_path)
				File.open(file_path, 'w+') do |f|
					f.write(file_content)
				end

				# Creating the file in the Xcode project
				XcodeprojHelper.add_file_to_project_and_targets(project, targets, group_file_path, file_path)
			end

			return true
		end

	end
end
