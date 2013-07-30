require 'delegate'

module Representable
  # The Binding wraps the Definition instance for this property and provides methods to read/write fragments.
  class Binding < SimpleDelegator
    class FragmentNotFound
    end

    def self.build(definition, *args)
      # DISCUSS: move #create_binding to this class?
      return definition.create_binding(*args) if definition.binding
      build_for(definition, *args)
    end

    def initialize(definition, represented, user_options={}, exec_context=represented)  # TODO: remove default arg for user options. # DISCUSS: make exec_context an options hash?
      super(definition)
      @represented  = represented
      @user_options = user_options
      @exec_context = exec_context
    end

    attr_reader :user_options, :represented # TODO: make private/remove.

    # Main entry point for rendering/parsing a property object.
    def serialize(value)
      value
    end

    def deserialize(fragment)
      fragment
    end

    # Retrieve value and write fragment to the doc.
    def compile_fragment(doc)
      represented_exec_for(:writer, doc) do
        write_fragment(doc, get)
      end
    end

    # Parse value from doc and update the model property.
    def uncompile_fragment(doc)
      represented_exec_for(:reader, doc) do
        read_fragment(doc) do |value|
          set(value)
        end
      end
    end

    def write_fragment(doc, value)
      value = default_for(value)

      write_fragment_for(value, doc)
    end

    def write_fragment_for(value, doc)
      return if skipable_nil_value?(value)
      write(doc, value)
    end

    def read_fragment(doc)
      value = read_fragment_for(doc)

      if value == FragmentNotFound
        return unless has_default?
        value = default
      end

      yield value
    end

    def read_fragment_for(doc)
      read(doc)
    end

    def get
      represented_exec_for(:getter) do
        exec_context.send(getter)
      end
    end

    def set(value)
      represented_exec_for(:setter, value) do
        exec_context.send(setter, value)
      end
    end

  private
    attr_reader :exec_context

    # Execute the block for +option_name+ on the represented object.
    # Executes passed block when there's no lambda for option.
    def represented_exec_for(option_name, *args)
      return yield unless options[option_name]
      call_proc_for(options[option_name], *args)
    end

    # All lambdas are executed on exec_context which is either represented or the decorator instance.
    def call_proc_for(proc, *args)
      return proc unless proc.is_a?(Proc)
      # TODO: call method when proc is sympbol.
      args << user_options # DISCUSS: we assume user_options is a Hash!
      exec_context.instance_exec(*args, &proc)
    end


    # Hooks into #serialize and #deserialize to setup (extend/decorate) typed properties
    # at runtime.
    module Prepare
      # def prepare(object)
      #   return object unless mod = representer_module_for(object) # :extend.

      #   mod = mod.first if mod.is_a?(Array) # TODO: deprecate :extend => [..]
      #   mod.prepare(object)
      # end

      def representer_module_for(object, *args)
        call_proc_for(representer_module, object)   # TODO: how to pass additional data to the computing block?`
      end
    end

    # Overrides #serialize/#deserialize to call #to_*/from_*.
    # Computes :class in #deserialize. # TODO: shouldn't this be in a separate module? ObjectSerialize/ObjectDeserialize?
    module Object
      include Binding::Prepare

      # def serialize(object)
      #   return object if object.nil?

      #   super.send(serialize_method, @user_options.merge!({:wrap => false}))  # TODO: pass :binding => self
      # end

      # def deserialize(data)
      #   # DISCUSS: does it make sense to skip deserialization of nil-values here?
      #   create_object(data).tap do |obj|
      #     super(obj).send(deserialize_method, data, @user_options)
      #   end
      # end

      def create_object(fragment)
        instance_for(fragment) or class_for(fragment)
      end

    private
      def class_for(fragment, *args)
        item_class = class_from(fragment) or return fragment # DISCUSS: is it legal to return the very fragment here?
        item_class.new
      end

      def class_from(fragment, *args)
        call_proc_for(sought_type, fragment)
      end

      def instance_for(fragment, *args)
        return unless options[:instance]
        call_proc_for(options[:instance], fragment) or get
      end
    end

    include Object
  end
end
