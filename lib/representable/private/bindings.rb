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
      decorate.serialize(value) # prepare, to_json
    end

    def deserialize(fragment)
      decorate.deserialize(fragment) # prepare, from_json # FIXME: nothing to decorate here!
    end

  # DISCUSS: have wrapping _and_ representing in one class?
  private

    def from
      @definition.from
    end

    def decorate
      ObjectRepresenter.new(@definition, format)
      # how to get scalar wrapped by property binding? we could reuse the same ScalarRepresenter here for all formats, then
    end

    def format
      :hash
    end
  end
  class ObjectBinding < JSONObjectBinding

  end

  class JSONScalarBinding < JSONObjectBinding # DISCUSS: do we really need this binding?
    def initialize(*)
      super
      @definition.options[:extend] = HashScalarDecorator # the universal scalar decorator for now.
    end
  end



  class JSONCollectionBinding < JSONObjectBinding # inherit #read and #write
    def initialize(definition, item_binding_class=ObjectBinding) # TODO: don't use Binding but Representer here! we only want serialize/deserialize!
      @definition = definition
      @item_binding_class = item_binding_class
    end

    def serialize(value)
      # the point here is to use an abstract Collection representer in JSON, XML, Hash, YAML, etc.
      CollectionRepresenter.new(@definition, format, @item_binding_class).serialize(value)
    end
    def deserialize(array)
      CollectionRepresenter.new(@definition, format, @item_binding_class).deserialize(array)
    end

  end

  # this is kindof the transformer from an abstract hash into the concrete representation, egg hash.
  class JSONHashBinding < JSONObjectBinding
    def initialize(definition, item_binding_class=ObjectBinding)
      @definition = definition
      @item_binding_class = item_binding_class
    end # FIXME: yeah

    def item_binding
        @item_binding_class.new(@definition)
      end



    def serialize(value)
      {}.tap do |hsh|
        value.each do |k,v|
          hsh[k] = item_binding.serialize(v)
        end
      end
    end

    def deserialize(hash)
      {}.tap do |hsh|
        hash.each do |k,v|
          hsh[k] = item_binding.deserialize(v)
        end
      end
    end
  end


  class XMLObjectBinding < JSONObjectBinding
    # def write(parent, value)
    #   # to be consistent with Hash: create the wrap <song> node here and add childs from the #serialize call.
    #   parent << serialize(value)

    #   parent
    # end
    def write(parent, value)
       #DISCUSS: this would be like Hash does it. however, does it make sense to have unwrapped stuff in XML?
       node_for(parent, from).tap do |wrap|

         parent << (wrap << serialize(value))
       end

      #parent << serialize(value)
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

    def serialize(value)
      super
    end

    def deserialize(node)
      puts node.inspect
      return node.children.first.content
      node# should that be in #read?
    end
  end

  class XMLCollectionBinding < XMLObjectBinding
    #include JSONCollectionBinding::SerialMethods # this double-inheritance is an indicator for my wrong class structure.
    def initialize(definition, item_binding_class=XMLObjectBinding)
      @definition = definition
      @item_binding_class = item_binding_class
    end

    def write(parent, items)
      nodes = serialize(items) # each->to_node



      nodes = nodes.collect do |nod| # an XML Collection binding is absolutely ok to wrap items. e.g. we could add indexes here etc <song position="1">
        parent << (Nokogiri::XML::Node.new(from, parent.document) << nod)
      end
    end

    def serialize(value)
      # the point here is to use an abstract Collection representer in JSON, XML, Hash, YAML, etc.
      CollectionRepresenter.new(@definition, format, @item_binding_class).serialize(value)
    end
    def deserialize(array)
      CollectionRepresenter.new(@definition, format, @item_binding_class).deserialize(array)
    end

  private
  # FIXME: remove.
    def set_for(parent, nodes)
      Nokogiri::XML::NodeSet.new(parent.document, nodes)
    end
  end

  class XMLHashBinding < JSONHashBinding
    def initialize(definition, item_binding_class=XMLObjectBinding)
      @definition = definition
        @item_binding_class = item_binding_class
    end

    def write(parent, value)
      nodes = serialize(value) # each->to_node

      parent << (Nokogiri::XML::Node.new(from, parent.document) << nodes)# FIXME: make this beautiful!
    end

    def serialize(value) # we could use the original HashBinding#serialize here, and override the Nokogiri API so that hash[k] = .. is transformed to this?
      hash = super # {:first => <node>, ..}
      parent = Nokogiri::XML::Document.new

      list = hash.collect do |k, nod|
        Nokogiri::XML::Node.new(k, parent) << nod # DISCUSS: use Scalar?
      end


      Nokogiri::XML::NodeSet.new(parent, list)
    end

    def deserialize(nodes)
      nodes = nodes.children


      {}.tap do |hsh|
        nodes.each do |nod|
          hsh[nod.name] = item_binding.deserialize(nod.children.first)
        end
      end
    end



    def read(node) # FIXME: from XMLObject.
      nodes = find_nodes(node)

      deserialize(nodes)
    end

  private
    def find_nodes(doc) # FIXME: from XMLObject.
      selector  = from
      #selector  = "#{options[:wrap]}/#{xpath}" if options[:wrap]
      nodes     = doc.xpath(selector)
    end



  private
    def item_binding
      @item_binding_class.new(@definition)
    end
  end
