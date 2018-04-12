# frozen_string_literal: true

require 'ruby_terraform'

class TerraformHelper
  attr_accessor :dir, :vars

  # @param [String] dir Working directory for Terraform
  # @param [Hash] vars Variables that will be applied to Terraform when applying or destroying.
  # @param [Hash] backend_vars Configuration to use when setting up the backend storage of Terraform
  def initialize(dir, vars, backend_vars = {})
    @dir = dir
    @vars = vars
    @backend_vars = backend_vars
    @disable_colour = ENV['TF_DISABLE_COLOUR'] || false
  end

  # Run terraform init and terraform apply.
  # @param [String] template_dir Directory that Terraform will copy the template will from
  def apply(template_dir)
    template_dir = File.expand_path template_dir
    puts "Applying terraform from #{template_dir} to #{@dir}"
    Dir.mkdir @dir unless File.exist? @dir

    Dir.chdir @dir do
      RubyTerraform.init(
        from_module: template_dir,
        backend: true,
        backend_config: @backend_vars,
        no_color: @disable_colour
      )

      RubyTerraform.apply(
        vars: @vars,
        no_backup: true,
        auto_approve: true,
        no_color: @disable_colour
      )
    end
  end

  def destroy
    puts 'Destroying terraform'
    Dir.chdir @dir do
      RubyTerraform.destroy(directory: @dir, vars: @vars, force: true, no_color: @disable_colour)
    end
  end

  def output(name)
    puts "Getting terraform output for #{name}"
    Dir.chdir @dir do
      RubyTerraform.output(
        name: name,
        no_color: true
      )
    end
  end
end
