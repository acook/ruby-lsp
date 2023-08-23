# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyIndexer
  class ConfigurationTest < Minitest::Test
    def setup
      @config = Configuration.new
    end

    def test_load_configuration_executes_configure_block
      @config.load_config
      files_to_index = @config.files_to_index

      assert(files_to_index.none? { |path| path.include?("test/fixtures") })
      assert(files_to_index.none? { |path| path.include?("minitest-reporters") })
      assert(files_to_index.none? { |path| path == __FILE__ })
    end

    def test_paths_are_unique
      @config.load_config
      files_to_index = @config.files_to_index

      assert_equal(files_to_index.uniq.length, files_to_index.length)
    end

    def test_configuration_raises_for_unknown_keys
      Psych::Nodes::Document.any_instance.expects(:to_ruby).returns({ "unknown_config" => 123 })

      assert_raises(ArgumentError) do
        @config.load_config
      end
    end

    def test_magic_comments_regex
      regex = RubyIndexer.configuration.magic_comment_regex

      [
        "# frozen_string_literal:",
        "# typed:",
        "# compiled:",
        "# encoding:",
        "# shareable_constant_value:",
        "# warn_indent:",
        "# rubocop:",
        "# nodoc:",
        "# doc:",
        "# coding:",
        "# warn_past_scope:",
      ].each do |comment|
        assert_match(regex, comment)
      end
    end
  end
end
