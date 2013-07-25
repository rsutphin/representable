class Song
    attr_accessor :title
    def initialize(attrs={})
      @title = attrs[:title]
    end
  end

  module SongRepresenter
    include Representable::Hash
    property :title
  end

  module XMLSongRepresenter
    include Representable::XML
    property :title
    self.representation_wrap = :song
  end

# used in Binding before real rendering
# these Representer classes are generic and do not know anything about the format.
# they just return the serialized property
#
# i wanna use em like
# def write(hash, value)
#   hash[from] = serialize_for(value) # where serialize == represents
#
# erweitere, rendere was auch immer, weitergeben and FragmentBinding!

class ObjectRepresenter
  def initialize(represented, definition, format)
    @represented = represented
    @definition = definition

    @format = format

    #@decorator = prepare ----> pass in represented here? what about create_object, then?
  end

  def serialize
    serialize_for(@represented)
  end

  def deserialize(data)
    # DISCUSS: does it make sense to skip deserialization of nil-values here?
    @definition.create_object(data).tap do |obj|
      #super(obj).send(deserialize_method, data, @user_options)
      deserialize_for(obj, data)
    end
  end

private
  def serialize_for(object)
    decorator = prepare(object)

    decorator.send(serialize_method, {:wrap => false})
  end

  def deserialize_for(object, data)
    decorator = prepare(object)

    decorator.send(deserialize_method, data)
  end

  def prepare(object)
    mod = @definition.send(:representer_module_for, object)

    decorator = mod.prepare(object)
  end

  def serialize_method
    "to_#{@format}"
  end

  def deserialize_method
    "from_#{@format}"
  end
end

class CollectionRepresenter < ObjectRepresenter
  def serialize
    @represented.collect do |obj|
      serialize_for(obj)
    end
  end

  def deserialize(data)
    data.collect do |fragment| # DISCUSS: what if we don't want to override the incoming Array?
      super(fragment)
    end
  end
end

class HashScalarDecorator < Representable::Decorator # we don't really have to inherit here.
  def to_hash(*)
    represented
  end

  def from_hash(hash, *args)
    # this currently works cause create_object returns the scalar from the doc, which is then @represented in the decorator. what about speed here?
    hash
  end
end

class XMLScalarDecorator < HashScalarDecorator # we don't really have to inherit here.
  alias_method :to_node, :to_hash
  alias_method :from_node, :from_hash
end

class SimplerDefinition < Representable::Binding
  include Representable::Binding::Object
end
