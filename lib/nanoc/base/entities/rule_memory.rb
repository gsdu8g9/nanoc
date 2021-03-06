module Nanoc::Int
  class RuleMemory
    include Nanoc::Int::ContractsSupport
    include Enumerable

    def initialize(item_rep, actions: [])
      @item_rep = item_rep
      @actions = actions
    end

    contract C::None => Numeric
    def size
      @actions.size
    end

    contract Numeric => C::Maybe[Nanoc::Int::ProcessingAction]
    def [](idx)
      @actions[idx]
    end

    contract Symbol, Hash => self
    def add_filter(filter_name, params)
      @actions << Nanoc::Int::ProcessingActions::Filter.new(filter_name, params)
      self
    end

    contract String, C::Maybe[Hash] => self
    def add_layout(layout_identifier, params)
      @actions << Nanoc::Int::ProcessingActions::Layout.new(layout_identifier, params)
      self
    end

    contract Symbol, C::Maybe[String] => self
    def add_snapshot(snapshot_name, path)
      will_add_snapshot(snapshot_name)
      @actions << Nanoc::Int::ProcessingActions::Snapshot.new([snapshot_name], path ? [path] : [])
      self
    end

    contract C::None => C::ArrayOf[Nanoc::Int::ProcessingAction]
    def snapshot_actions
      @actions.select { |a| a.is_a?(Nanoc::Int::ProcessingActions::Snapshot) }
    end

    contract C::None => C::Bool
    def any_layouts?
      @actions.any? { |a| a.is_a?(Nanoc::Int::ProcessingActions::Layout) }
    end

    contract C::None => Array
    def paths
      snapshot_actions.map { |a| [a.snapshot_names, a.paths] }
    end

    # TODO: Add contract
    def serialize
      to_a.map(&:serialize)
    end

    contract C::Func[Nanoc::Int::ProcessingAction => C::Any] => self
    def each
      @actions.each { |a| yield(a) }
      self
    end

    contract C::Func[Nanoc::Int::ProcessingAction => C::Any] => self
    def map
      self.class.new(
        @item_rep,
        actions: @actions.map { |a| yield(a) },
      )
    end

    def compact_snapshots
      actions = []
      @actions.each do |action|
        if [actions.last, action].all? { |a| a.is_a?(Nanoc::Int::ProcessingActions::Snapshot) }
          actions[-1] = actions.last.update(snapshot_names: action.snapshot_names, paths: action.paths)
        else
          actions << action
        end
      end
      self.class.new(@item_rep, actions: actions)
    end

    private

    def will_add_snapshot(name)
      @_snapshot_names ||= Set.new
      if @_snapshot_names.include?(name)
        raise Nanoc::Int::Errors::CannotCreateMultipleSnapshotsWithSameName.new(@item_rep, name)
      else
        @_snapshot_names << name
      end
    end
  end
end
