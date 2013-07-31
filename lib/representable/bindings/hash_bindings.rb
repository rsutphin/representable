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
        return JSONObjectBinding.new(self, AlmightyScalarRepresenter).read(hash)
      end

      require 'representable/private/bindings'
      def write(hash, value)
        return JSONObjectBinding.new(self).write(hash, value) if typed?
        return JSONObjectBinding.new(self, AlmightyScalarRepresenter).write(hash, value)
      end
    end


    class CollectionBinding < PropertyBinding
      def write(hash, value)
        return JSONCollectionBinding.new(self).write(hash, value) if typed?
        return JSONCollectionBinding.new(self, AlmightyScalarRepresenter).write(hash, value)
      end

      def read(hash)
        return FragmentNotFound unless hash.has_key?(from) # DISCUSS: put it all in #read for performance. not really sure if i like returning that special thing.

        return JSONCollectionBinding.new(self).read(hash) if typed?
        return JSONCollectionBinding.new(self, AlmightyScalarRepresenter).read(hash)
      end
    end


    class HashBinding < PropertyBinding
      def write(hash, value)
        return JSONHashBinding.new(self).write(hash, value) if typed?
        return JSONHashBinding.new(self, AlmightyScalarRepresenter).write(hash, value)
      end

      def read(hash)
        return FragmentNotFound unless hash.has_key?(from) # DISCUSS: put it all in #read for performance. not really sure if i like returning that special thing.

        return JSONHashBinding.new(self).read(hash) if typed?
        return JSONHashBinding.new(self, AlmightyScalarRepresenter).read(hash)
      end
    end
  end
end
