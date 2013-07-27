require 'representable/binding'

module Representable
  module Hash

    class PropertyBinding < Representable::Binding
      def self.build_for(definition, *args)  # TODO: remove default arg.
        return CollectionBinding.new(definition, *args)  if definition.array?
        return HashBinding.new(definition, *args)        if definition.hash?
        new(definition, *args)
      end

      def read(hash)
        return FragmentNotFound unless hash.has_key?(from) # DISCUSS: put it all in #read for performance. not really sure if i like returning that special thing.

        return JSONObjectBinding.new(self).read(hash) if typed?
        return JSONScalarBinding.new(self).read(hash)
      end

      require 'representable/private/bindings'
      def write(hash, value)
        return JSONObjectBinding.new(self).write(hash, value) if typed?
        return JSONScalarBinding.new(self).write(hash, value)
      end
    end


    class CollectionBinding < PropertyBinding
      def write(hash, value)
        return JSONCollectionBinding.new(self).write(hash, value) if typed?
        return JSONCollectionBinding.new(self, JSONScalarBinding).write(hash, value)
      end

      def read(hash)
        return FragmentNotFound unless hash.has_key?(from) # DISCUSS: put it all in #read for performance. not really sure if i like returning that special thing.

        return JSONCollectionBinding.new(self).read(hash) if typed?
        return JSONCollectionBinding.new(self, JSONScalarBinding).read(hash)
      end
    end


    class HashBinding < PropertyBinding

      def write(hash, value)
        # requires value to respond to #each with two block parameters.
        # return JSONObjectBinding.new(self).write(hash, value) if typed?
        # return JSONScalarBinding.new(self).write(hash, value)
        binding = JSONScalarBinding.new(self) unless typed?
        binding = JSONObjectBinding.new(self) if typed?

        # FIXME: use PropertyBinding for writing or #write here
        hash[from] = {}.tap do |hsh|
          value.each { |key, obj| hsh[key] = binding.serialize(obj) }
        end
      end

      def read(hash)
        # requires value to respond to #each with two block parameters.
        # return JSONObjectBinding.new(self).write(hash, value) if typed?
        # return JSONScalarBinding.new(self).write(hash, value)
        binding = JSONScalarBinding.new(self) unless typed?
        binding = JSONObjectBinding.new(self) if typed?

        # FIXME: use PropertyBinding for writing or #write here
        fragment = hash[from]
        {}.tap do |hsh|
          fragment.each { |key, item_fragment| hsh[key] = binding.deserialize(item_fragment) }

        end
      end

    end
  end
end
