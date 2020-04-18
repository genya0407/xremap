module Xremap
  class ConfigDSL
    # @param [Xremap::Config] config
    def initialize(config, win = Config::AnyWindow)
      @config = config
      @window = win
    end

    def remap(from_str, options = {})
      # Array() doesn't work for Config::Execute somehow.
      to_strs = options.fetch(:to)
      to_strs = [to_strs] unless to_strs.is_a?(Array)
      with_masks = Array(options.fetch(:with_modifier, [])).map { |mod| KeyExpression.modifier_to_mask(mod) }

      @config.remaps_by_window[@window] << Config::Remap.new(
        compile_exp(from_str),
        to_strs.map { |str| compile_exp(str) },
        all_possible_with_masks(with_masks),
      )
    end

    def window(options = {}, &block)
      win = Config::Window.new(options[:class_only], options[:class_not])
      ConfigDSL.new(@config, win).instance_exec(&block)
    end

    def execute(str)
      Config::Execute.new(str, :execute)
    end

    def press(str)
      key = compile_exp(str)
      key.action = :press
      key
    end

    def release(str)
      key = compile_exp(str)
      key.action = :release
      key
    end

    def define(name, &block)
      ConfigDSL.define_method(name, &block)
    end

    def include_config(filename)
      path = File.expand_path(filename, @config.config_dir)
      path << '.rb' unless path.start_with?('.rb')
      raise "config file not found!: #{path.inspect}" unless File.exist?(path)
      instance_eval(File.read(path))
    end

    private

    def compile_exp(exp)
      case exp
      when Config::Key, Config::Execute
        exp
      when String
        KeyExpression.compile(exp)
      else
        raise "unexpected expression: #{exp.inspect}"
      end
    end

    def all_possible_with_masks(with_masks)
      if with_masks.size == 0
        [0]
      else
        possible_masks_without_first_mask = all_possible_with_masks(with_masks[1..with_masks.size])
        possible_masks_without_first_mask.map { |mask| mask | with_masks[0] }.to_a + possible_masks_without_first_mask
      end
    end
  end
end
