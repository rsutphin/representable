require 'representable/hash/collection'

module Representable::XML
  module Collection
    include Representable::XML

    def self.included(base)
      base.class_eval do
        include Representable::Hash::Collection
        include Methods
      end
    end

    module Methods
      def update_properties_from(doc, options, format)
        node = doc.search("./*") # pass the list of collection items to Hash::Collection#update_properties_from.
        bin   = representable_mapper(format, options).bindings.first
        #value = bin.deserialize(node)

        if bin.typed?
          bbin= XMLCollectionBinding.new(bin)
        else
         bbin= XMLCollectionBinding.new(bin, XMLScalarBinding)
       end

       value = bbin.deserialize(node)

        represented.replace(value)
      end
    end
  end
end
