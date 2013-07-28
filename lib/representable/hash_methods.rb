module Representable
  module HashMethods
    # FIXME: refactor Definition so we can simply add options in #items to existing definition.
    def representable_attrs
      attrs = super
      attrs << Definition.new(*definition_opts) if attrs.size == 0
      attrs
    end

    def create_representation_with(doc, options, format)
      bin   = representable_mapper(format, options).bindings.first
      hash  = filter_keys_for(represented, options)

      if bin.typed?
          bbin= JSONHashBinding.new(bin)
        else
         bbin= JSONHashBinding.new(bin, XMLScalarBinding)
       end

      bbin.serialize(hash)
    end

    def update_properties_from(doc, options, format)
      bin   = representable_mapper(format, options).bindings.first
      hash  = filter_keys_for(doc, options)

      #value = bin.deserialize_from(hash)

      if bin.typed?
          bbin= JSONHashBinding.new(bin)
        else
         bbin= JSONHashBinding.new(bin, XMLScalarBinding)
       end

       value = bbin.deserialize(hash)

      represented.replace(value)
    end

  private
    def filter_keys_for(hash, options)
      return hash unless props = options[:exclude] || options[:include]
      hash.reject { |k,v| options[:exclude] ? props.include?(k.to_sym) : !props.include?(k.to_sym) }
    end
  end
end
