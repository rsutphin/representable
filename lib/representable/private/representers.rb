
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
  def initialize(definition, format)
    @definition = definition

    @format = format

    #@decorator = prepare ----> pass in represented here? what about create_object, then?
  end

  def serialize(object)
    serialize_for(object)
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
    mod = representer_module_for(object) #@representer

    # FIXME: this happens when class.is_a?(Representable::JSON), that should be handled elsewhere.
    return object unless mod
    # FIXME: handle that in prepare?
    mod = mod.first if mod.is_a?(Array)

    decorator = mod.prepare(object)
  end

  def serialize_method
    "to_#{@format}"
  end

  def deserialize_method
    "from_#{@format}"
  end

  def representer_module_for(object)
    unless @definition.typed?
      return  HashScalarDecorator
    end


    @definition.representer_module_for(object) # =>  || HashScalarDecorator # FIXME: this should be a generic Decorator
    # FIXME: also, what if there's not represnter module configured since object.is_a?(Representable) class?
  end
end

class CollectionRepresenter # means: #serialize/#deserialize
  def initialize(definition, format=:hash, item_binding_class=ObjectBinding)
    @definition = definition
    @format = format
    @item_binding = item_binding_class.new(definition)
  end

  def serialize(value) # DISCUSS: pass from outside?
    value.collect do |obj| # DISCUSS: what if we wanna keep the original array?
      #item_binding.serialize(obj)
      ObjectRepresenter.new(@definition, @format).serialize(obj)
    end
  end

  def deserialize(array)
    array.collect do |hsh|
      item_binding.deserialize(hsh)
      #ObjectRepresenter.new(nil, @definition, @format).deserialize(hsh) # this uses create_object and fucks up.
    end
  end

  attr_reader :item_binding
end

class HashScalarDecorator < Representable::Decorator # we don't really have to inherit here.
  def to_hash(*)
    represented
  end

  def from_hash(hash, *args)
    # this currently works cause create_object returns the scalar from the doc, which is then @represented in the decorator. what about speed here?
    hash
  end

  alias_method :to_node, :to_hash
  #alias_method :from_node, :from_hash
  def from_node(node, *args)
    node.children.first.content
  end
end

class XMLScalarDecorator < HashScalarDecorator # we don't really have to inherit here.
  alias_method :to_node, :to_hash
  #alias_method :from_node, :from_hash
  def from_node(node, *args)
    node.children.first.content
  end
end
