# typed: strict
# frozen_string_literal: true

module RubyIndexer
  class IndexVisitor < Prism::Visitor
    extend T::Sig

    sig { params(index: Index, parse_result: Prism::ParseResult, file_path: String).void }
    def initialize(index, parse_result, file_path)
      @index = index
      @parse_result = parse_result
      @file_path = file_path
      @stack = T.let([], T::Array[String])
      @comments_by_line = T.let(
        parse_result.comments.to_h do |c|
          [c.location.start_line, c]
        end,
        T::Hash[Integer, Prism::Comment],
      )

      super()
    end

    sig { void }
    def run
      visit(@parse_result.value)
    end

    sig { params(node: T.nilable(Prism::Node)).void }
    def visit(node)
      case node
      when Prism::ProgramNode, Prism::StatementsNode
        visit_child_nodes(node)
      when Prism::ClassNode
        add_index_entry(node, Index::Entry::Class)
      when Prism::ModuleNode
        add_index_entry(node, Index::Entry::Module)
      when Prism::ConstantWriteNode, Prism::ConstantOrWriteNode
        name = fully_qualify_name(node.name.to_s)
        add_constant(node, name)
      when Prism::ConstantPathWriteNode, Prism::ConstantPathOrWriteNode, Prism::ConstantPathOperatorWriteNode,
        Prism::ConstantPathAndWriteNode

        # ignore variable constants like `var::FOO` or `self.class::FOO`
        return unless node.target.parent.nil? || node.target.parent.is_a?(Prism::ConstantReadNode)

        name = fully_qualify_name(node.target.location.slice)
        add_constant(node, name)
      when Prism::CallNode
        message = node.message
        handle_private_constant(node) if message == "private_constant"
      end
    end

    # Override to avoid using `map` instead of `each`
    sig { params(nodes: T::Array[T.nilable(Prism::Node)]).void }
    def visit_all(nodes)
      nodes.each { |node| visit(node) }
    end

    private

    sig { params(node: Prism::CallNode).void }
    def handle_private_constant(node)
      arguments = node.arguments&.arguments
      return unless arguments

      first_argument = arguments.first

      name = case first_argument
      when Prism::StringNode
        first_argument.content
      when Prism::SymbolNode
        first_argument.value
      end

      return unless name

      receiver = node.receiver
      name = "#{receiver.slice}::#{name}" if receiver

      # The private_constant method does not resolve the constant name. It always points to a constant that needs to
      # exist in the current namespace
      entries = @index[fully_qualify_name(name)]
      entries&.each { |entry| entry.visibility = :private }
    end

    sig do
      params(
        node: T.any(
          Prism::ConstantWriteNode,
          Prism::ConstantOrWriteNode,
          Prism::ConstantPathWriteNode,
          Prism::ConstantPathOrWriteNode,
          Prism::ConstantPathOperatorWriteNode,
          Prism::ConstantPathAndWriteNode,
        ),
        name: String,
      ).void
    end
    def add_constant(node, name)
      value = node.value
      comments = collect_comments(node)

      @index << case value
      when Prism::ConstantReadNode, Prism::ConstantPathNode
        Index::Entry::UnresolvedAlias.new(value.slice, @stack.dup, name, @file_path, node.location, comments)
      when Prism::ConstantWriteNode, Prism::ConstantAndWriteNode, Prism::ConstantOrWriteNode,
        Prism::ConstantOperatorWriteNode

        # If the right hand side is another constant assignment, we need to visit it because that constant has to be
        # indexed too
        visit(value)
        Index::Entry::UnresolvedAlias.new(value.name.to_s, @stack.dup, name, @file_path, node.location, comments)
      when Prism::ConstantPathWriteNode, Prism::ConstantPathOrWriteNode, Prism::ConstantPathOperatorWriteNode,
        Prism::ConstantPathAndWriteNode

        visit(value)
        Index::Entry::UnresolvedAlias.new(value.target.slice, @stack.dup, name, @file_path, node.location, comments)
      else
        Index::Entry::Constant.new(name, @file_path, node.location, comments)
      end
    end

    sig { params(node: T.any(Prism::ClassNode, Prism::ModuleNode), klass: T.class_of(Index::Entry)).void }
    def add_index_entry(node, klass)
      name = node.constant_path.location.slice

      unless /^[A-Z:]/.match?(name)
        return visit_child_nodes(node)
      end

      comments = collect_comments(node)
      @index << klass.new(fully_qualify_name(name), @file_path, node.location, comments)
      @stack << name
      visit_child_nodes(node)
      @stack.pop
    end

    sig { params(node: Prism::Node).returns(T::Array[String]) }
    def collect_comments(node)
      comments = []

      start_line = node.location.start_line - 1
      start_line -= 1 unless @comments_by_line.key?(start_line)

      start_line.downto(1) do |line|
        comment = @comments_by_line[line]
        break unless comment

        comment_content = comment.location.slice.chomp
        next if comment_content.match?(RubyIndexer.configuration.magic_comment_regex)

        comment_content.delete_prefix!("#")
        comment_content.delete_prefix!(" ")
        comments.unshift(comment_content)
      end

      comments
    end

    sig { params(name: String).returns(String) }
    def fully_qualify_name(name)
      if @stack.empty? || name.start_with?("::")
        name
      else
        "#{@stack.join("::")}::#{name}"
      end.delete_prefix("::")
    end
  end
end
