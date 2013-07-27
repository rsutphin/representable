require 'representable/binding'

module Representable
  module XML
    class PropertyBinding < Binding
      def self.build_for(definition, *args)
        return CollectionBinding.new(definition, *args)      if definition.array?
        return HashBinding.new(definition, *args)            if definition.hash? and not definition.options[:use_attributes] # FIXME: hate this.
        return AttributeHashBinding.new(definition, *args)   if definition.hash? and definition.options[:use_attributes]
        return AttributeBinding.new(definition, *args)       if definition.attribute
        new(definition, *args)
      end

      def write(parent, value)
        return XMLObjectBinding.new(self).write(parent, value) if typed?
        XMLScalarBinding.new(self).write(parent, value)
      end

      def read(node)
        nodes = find_nodes(node) # FIXME: this is redundant!
        return FragmentNotFound if nodes.size == 0 # TODO: write dedicated test!

        return XMLObjectBinding.new(self).read(node) if typed?
        return XMLScalarBinding.new(self).read(node)
      end



      def find_nodes(doc)
        selector  = from
        selector  = "#{options[:wrap]}/#{from}" if options[:wrap]
        nodes     = doc.xpath(selector)
      end
    end

    class CollectionBinding < PropertyBinding
      def write(hash, value)
        return XMLCollectionBinding.new(self).write(hash, value) if typed?
        return XMLCollectionBinding.new(self, XMLScalarBinding).write(hash, value)
      end

      def read(hash)
        # DISCUSS: where is the check for existance?
        return XMLCollectionBinding.new(self).read(hash) if typed?
        return XMLCollectionBinding.new(self, XMLScalarBinding).read(hash)
      end

    private


      def set_for(parent, nodes)
        Nokogiri::XML::NodeSet.new(parent.document, nodes)
      end
    end


    class HashBinding < CollectionBinding
      def serialize_for(value, parent)
        set_for(parent, value.collect do |k, v|
          node = node_for(parent, k)
          serialize_node(node, v)
        end)
      end

      def deserialize_from(nodes)
        {}.tap do |hash|
          nodes.children.each do |node|
            hash[node.name] = deserialize_node(node)
          end
        end
      end
    end

    class AttributeHashBinding < CollectionBinding
      # DISCUSS: use AttributeBinding here?
      def write(parent, value)  # DISCUSS: is it correct overriding #write here?
        value.collect do |k, v|
          parent[k] = serialize(v.to_s)
        end
        parent
      end

      def deserialize_from(node)
        {}.tap do |hash|
          node.each do |k,v|
            hash[k] = deserialize(v)
          end
        end
      end
    end


    # Represents a tag attribute. Currently this only works on the top-level tag.
    class AttributeBinding < PropertyBinding
      def read(node)
        deserialize(node[from])
      end

      def serialize_for(value, parent)
        parent[from] = serialize(value.to_s)
      end

      def write(parent, value)
        serialize_for(value, parent)
      end
    end
  end
end
