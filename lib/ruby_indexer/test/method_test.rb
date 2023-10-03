# typed: true
# frozen_string_literal: true

require_relative "test_case"

module RubyIndexer
  class MethodTest < TestCase
    def test_method_with_no_parameters
      index(<<~RUBY)
        class Foo
          def bar
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
    end

    def test_method_with_parameters
      index(<<~RUBY)
        class Foo
          def bar(a)
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
      entry = T.must(@index["bar"].first)
      assert_equal([:a], entry.parameters)
      refute(entry.accepts_arity?(0))
      assert(entry.accepts_arity?(1))
      refute(entry.accepts_arity?(2))
    end

    def test_method_with_optional_positional_parameter
      index(<<~RUBY)
        class Foo
          def bar(a, b = 1)
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
      entry = T.must(@index["bar"].first)
      assert_equal([:a, :b], entry.parameters)
      assert(entry.accepts_arity?(1))
      assert(entry.accepts_arity?(2))
      refute(entry.accepts_arity?(3))
    end

    def test_method_with_splat
      index(<<~RUBY)
        class Foo
          def bar(a, b = 1, *c)
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
      entry = T.must(@index["bar"].first)
      assert_equal([:a, :b, :c], entry.parameters)
      assert(entry.accepts_arity?(1))
      assert(entry.accepts_arity?(2))
      assert(entry.accepts_arity?(3))
      assert(entry.accepts_arity?(99))
    end

    def test_method_with_post
      index(<<~RUBY)
        class Foo
          def bar(a, b = 1, d)
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
      entry = T.must(@index["bar"].first)
      assert_equal([:a, :b, :d], entry.parameters)
      refute(entry.accepts_arity?(1))
      assert(entry.accepts_arity?(2))
      assert(entry.accepts_arity?(3))
      refute(entry.accepts_arity?(4))
    end

    def test_method_with_keyword_parameter
      index(<<~RUBY)
        class Foo
          def bar(a, b: 1)
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
      entry = T.must(@index["bar"].first)
      assert_equal([:a, :b], entry.parameters)
      assert(entry.accepts_arity?(1))
      assert(entry.accepts_arity?(2))
      refute(entry.accepts_arity?(3))
    end

    def test_method_with_keyword_splat
      index(<<~RUBY)
        class Foo
          def bar(a, **b)
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
      entry = T.must(@index["bar"].first)
      assert_equal([:a, :b], entry.parameters)
      assert(entry.accepts_arity?(1))
      assert(entry.accepts_arity?(2))
      assert(entry.accepts_arity?(99))
    end

    def test_method_with_block
      index(<<~RUBY)
        class Foo
          def bar(a, &blk)
          end
        end
      RUBY

      assert_entry("bar", Index::Entry::Method, "/fake/path/foo.rb:1-2:2-5")
      entry = T.must(@index["bar"].first)
      assert_equal([:a, :blk], entry.parameters)
      assert(entry.accepts_arity?(1))
      refute(entry.accepts_arity?(2))
    end
  end
end
