require_relative "filesystem"
require_relative "command_runner"
require_relative "gem_version"

module Snowglobe
  class Bundle
    def initialize(fs:, command_runner:)
      @fs = fs
      @command_runner = command_runner
      @already_updating = false
    end

    def add_gem(gem, *args)
      updating do
        options = args.last.is_a?(Hash) ? args.pop : {}
        version = args.shift
        line = assemble_gem_line(gem, version, options)
        fs.append_to_file("Gemfile", line)
      end
    end

    def remove_gem(gem)
      updating do
        fs.comment_lines_matching_in_file("Gemfile", /^[ ]*gem ("|')#{gem}\1/)
      end
    end

    def updating
      if already_updating?
        yield self
        return
      end

      @already_updating = true

      yield self

      @already_updating = false

      install_gems
    end

    def install_gems
      command_runner.run_outside_of_bundle!(
        "bundle install --local"
      ) do |runner|
        runner.retries = 5
      end
    end

    def version_of(gem)
      GemVersion.new(Bundler.definition.specs[gem][0].version)
    end

    def includes?(gem)
      Bundler.definition.dependencies.any? do |dependency|
        dependency.name == gem
      end
    end

    private

    attr_reader :fs, :command_runner

    def already_updating?
      @already_updating
    end

    def assemble_gem_line(gem, version, options)
      formatted_options = options
        .map { |key, value| "#{key}: #{formatted_value(value)}" }
        .join(", ")

      line = %(gem '#{gem}')

      if version
        line << %(, '#{version}')
      end

      if options.any?
        line << %(, #{formatted_options})
      end

      line << "\n"
    end

    def formatted_value(value)
      if value.is_a?(Pathname)
        value.to_s.inspect
      else
        value.inspect
      end
    end
  end
end
