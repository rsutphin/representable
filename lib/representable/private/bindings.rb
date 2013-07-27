require 'representable/private/representers'

class JSONObjectBinding
    def initialize(definition)
      @definition = definition
    end

    def write(hash, value)
      hash[from] = serialize(value) # so the binding takes care of wrapping. how can we tell the object to additionally wrap?
      hash
    end

    def read(hash)
      fragment = hash[from] # if we wrap here, we can use :from, but also the representer's wrap or both. if we let the representer wrap itself here, it doesn't know about alternative wraps.

      deserialize(fragment)
    end

    def serialize(value) # DISCUSS: pass from outside?
      decorate(value).serialize # prepare, to_json
    end

    def deserialize(fragment)
      decorate(nil).deserialize(fragment) # prepare, from_json # FIXME: nothing to decorate here!
    end

  # DISCUSS: have wrapping _and_ representing in one class?
  private

    def from
      @definition.from
    end

    def decorate(value)
      ObjectRepresenter.new(value, SimplerDefinition.new(@definition, nil), format) # FIXME: remove need for SimplerDefinition.
    end

    def format
      :hash
    end
  end

  class JSONScalarBinding < JSONObjectBinding # DISCUSS: do we really need this binding?
    def initialize(*)
      super
      @definition.options[:extend] = HashScalarDecorator
    end
  end

  class JSONCollectionBinding < JSONObjectBinding # inherit #read and #write
    module SerialMethods # this should actually be a separate class embracing an already un-bound array.
      def initialize(definition, item_binding_class=JSONObjectBinding)
        @definition = definition
        @item_binding_class = item_binding_class
      end

      def serialize(value) # DISCUSS: pass from outside?
        value.collect do |obj| # DISCUSS: what if we wanna keep the original array?
          #super(obj)
          item_binding.serialize(obj)
        end
      end

      def deserialize(array)
        array.collect do |hsh|
          #super(hsh)
          item_binding.deserialize(hsh)
        end
      end

    private
      def item_binding
        @item_binding_class.new(@definition)
      end
    end
    include SerialMethods
  end


  class XMLObjectBinding < JSONObjectBinding
    # def write(parent, value)
    #   # to be consistent with Hash: create the wrap <song> node here and add childs from the #serialize call.
    #   parent << serialize(value)

    #   parent
    # end
    def write(parent, value)
      # DISCUSS: this would be like Hash does it. however, does it make sense to have unwrapped stuff in XML?
      # node_for(parent, from).tap do |wrap|
      #   wrap << serialize(value)
      # end

      parent << serialize(value)
    end

    def read(node)
      nodes = find_nodes(node)

      deserialize(nodes)
    end

  private
    def find_nodes(doc)
      selector  = from
      #selector  = "#{options[:wrap]}/#{xpath}" if options[:wrap]
      nodes     = doc.xpath(selector)
    end

    def node_for(parent, name)
      Nokogiri::XML::Node.new(name.to_s, parent.document)
    end

    def format
      :node
    end
  end

  class XMLScalarBinding < XMLObjectBinding
    def initialize(*)
      super
      @definition = @definition.clone
      @definition.options[:extend] = XMLScalarDecorator # FIXME: merge with JSONScalarBinding.
    end

    class Scalar
      def initialize(scalar, from)
        @scalar, @from = scalar, from
      end
      attr_reader :from
      def to_s
        @scalar
      end
    end

    def serialize(value)
      super Scalar.new(value, from)
    end

    def deserialize(node)
      super node.first.content # should that be in #read?
    end
  end

  class XMLCollectionBinding < XMLObjectBinding
    include JSONCollectionBinding::SerialMethods # this double-inheritance is an indicator for my wrong class structure.
    def initialize(definition, item_binding_class=XMLObjectBinding)
      super
    end

    def write(parent, items)
      # items.collect do |obj| # DISCUSS: what if we wanna keep the original array?
      #     #super(obj)
      #       puts "obj: #{obj.inspect}"
      #      puts "writing: #{item_binding.write(parent, obj)}"
      #     item_binding.serialize(obj)
      #   end

      nodes = serialize(items) # each->to_node

      parent << set_for(parent, nodes)
    end

  private
    def set_for(parent, nodes)
      Nokogiri::XML::NodeSet.new(parent.document, nodes)
    end
  end
