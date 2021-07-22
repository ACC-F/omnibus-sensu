#
# Copyright 2014 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Omnibus
  class Packager::BFF < Packager::Base
    # @return [Hash]
    SCRIPT_MAP = {
      # Default Omnibus naming
      preinst:  'Pre-installation Script',
      postinst: 'Post-installation Script',
      prerm:    'Pre_rm Script',
      postrm:   'Unconfiguration Script',
    }.freeze

    id :bff

    setup do
      # Copy the full-stack installer into our scratch directory, accounting for
      # any excluded files.
      #
      # /opt/hamlet => /tmp/daj29013/opt/hamlet
      destination = File.join(staging_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)

      # Create the scripts staging directory
      create_directory(scripts_staging_dir)
    end

    build do
      # Render the gen template
      write_gen_template

      # Create the package
      create_bff_file
    end

    # @see Base#package_name
    def package_name
      "#{safe_base_package_name}.#{bff_version}.#{safe_architecture}.bff"
    end

    #
    # The path where the package scripts in the install directory.
    #
    # @return [String]
    #
    def scripts_install_dir
      File.expand_path("#{project.install_dir}/embedded/share/installp")
    end

    #
    # The path where the package scripts will staged.
    #
    # @return [String]
    #
    def scripts_staging_dir
      File.expand_path("#{staging_dir}#{scripts_install_dir}")
    end

    #
    # Copy all scripts in {Project#package_scripts_path} to the package
    # directory.
    #
    # @return [void]
    #
    def write_scripts
      SCRIPT_MAP.each do |script, _installp_name|
        source_path = File.join(project.package_scripts_path, script.to_s)

        if File.file?(source_path)
          log.debug(log_key) { "Adding script `#{script}' to `#{scripts_staging_dir}'" }
          copy_file(source_path, scripts_staging_dir)
        end
      end
    end

    #
    # Create the gen template for +mkinstallp+.
    #
    # @return [void]
    #
    # Some details on the various lifecycle scripts:
    #
    # The order of the installp scripts is:
    # - install
    #   - pre-install
    #   - post-install
    #   - config
    # - upgrade
    #   - pre-remove (of previous version)
    #   - pre-install (previous version of software not present anymore)
    #   - post-install
    #   - config
    # - remove
    #   - unconfig
    #   - unpre-install
    #
    # To run the new version of scc, the post-install will do.
    # To run the previous version with an upgrade, use the pre-remove script.
    # To run a source install of scc upon installation of installp package, use the pre-install.
    # Upon upgrade, both the pre-remove and the pre-install scripts will run.
    # As scc has been removed between the runs of these scripts, it will only run once during upgrade.
    #
    # Keywords for scripts:
    #
    #   Pre-installation Script: /path/script
    #   Unpre-installation Script: /path/script
    #   Post-installation Script: /path/script
    #   Pre_rm Script: /path/script
    #   Configuration Script: /path/script
    #   Unconfiguration Script: /path/script
    #
    def write_gen_template
      # Create a map of scripts that exist and install path
      scripts = SCRIPT_MAP.inject({}) do |hash, (script, installp_key)|
        staging_path =  File.join(scripts_staging_dir, script.to_s)
        install_path =  File.join(scripts_install_dir, script.to_s)

        if File.file?(staging_path)
          hash[installp_key] = install_path
        end

        hash
      end

      # Get a list of all files
      files = FileSyncer.glob("#{staging_dir}/**/*")
                .map { |path| path.gsub(/^#{staging_dir}/, '') }

      render_template(resource_path('gen.template.erb'),
        destination: File.join(staging_dir, 'gen.template'),
        variables: {
          name:           safe_base_package_name,
          install_dir:    project.install_dir,
          friendly_name:  project.friendly_name,
          version:        bff_version,
          description:    project.description,
          files:          files,
          scripts:        scripts,
        }
      )
    end

    #
    # Create the bff file using +mkinstallp+.
    #
    # Warning: This command runs as sudo! AIX requires the use of sudo to run
    # the +mkinstallp+ command.
    #
    # @return [void]
    #
    def create_bff_file
      log.info(log_key) { "Creating .bff file" }

      shellout!("/usr/sbin/mkinstallp -d #{staging_dir} -T #{staging_dir}/gen.template")

      # Copy the resulting package up to the package_dir
      FileSyncer.glob("#{staging_dir}/tmp/*.bff").each do |bff|
        copy_file(bff, Config.package_dir)
      end
    end

    #
    # Return the BFF-ready base package name, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_base_package_name
      if project.package_name =~ /\A[a-z0-9\.\+\-]+\z/
        project.package_name.dup
      else
        converted = project.package_name.downcase.gsub(/[^a-z0-9\.\+\-]+/, '-')

        log.warn(log_key) do
          "The `name' compontent of BFF package names can only include " \
          "lowercase alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.package_name}' to " \
          "`#{converted}'."
        end

        converted
      end
    end

    #
    # Return the BFF-specific version for this package. This is calculated
    # using the first three digits of the version, concatenated by a dot, then
    # suffixed with the build_iteration.
    #
    # @todo This is probably not the best way to extract the version and
    #   probably misses edge cases like when using git describe!
    #
    # @return [String]
    #
    def bff_version
      version = project.build_version.split(/[^\d]/)[0..2].join('.')
      "#{version}.#{project.build_iteration}"
    end

    #
    # The architecture for this RPM package.
    #
    # @return [String]
    #
    def safe_architecture
      Ohai['kernel']['machine']
    end
  end
end
