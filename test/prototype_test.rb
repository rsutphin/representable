require 'test_helper'

# used in Binding before real rendering
# these Representer classes are generic and do not know anything about the format.
# they just return the serialized property
#
# i wanna use em like
# def write(hash, value)
#   hash[from] = serialize_for(value) # where serialize == represents
#
# erweitere, rendere was auch immer, weitergeben and FragmentBinding!

# Object and ScalarRepresenter should be the same where we have a special ScalarDecorator with #to_node etc

class ObjectRepresenter
  def initialize(represented, definition, serialize_method, deserialize_method=nil)
    @represented = represented
    @definition = definition
    @serialize_method = serialize_method
    @deserialize_method = deserialize_method
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

    decorator.send(@serialize_method, {:wrap => false})
  end

  def deserialize_for(object, data)
    decorator = prepare(object)

    decorator.send(@deserialize_method, data)
  end

  def prepare(object)
    mod = @definition.send(:representer_module_for, object)

    decorator = mod.prepare(object)
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

class ScalarRepresenter < ObjectRepresenter
  def serialize
    @represented
  end

  def deserialize(data)
    data
  end
end

class SimplerDefinition < Representable::Binding
  include Representable::Binding::Object
end

class BllaTest < MiniTest::Spec
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

  let (:song) { OpenStruct.new(:title => "Kinetic") }

  # Representer -------

  # Object + Hash
  it do
    ObjectRepresenter.new(song,
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter), song), :to_hash).
      serialize.
      must_equal({"title"=>"Kinetic"})
  end

  it do
    obj = ObjectRepresenter.new(nil,
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter, :class => Song), nil), :to_hash, :from_hash).
      deserialize({"title"=>"Kinetic"})

      obj.title.must_equal("Kinetic")
  end


  # Collection + Hash
  it do
    CollectionRepresenter.new([song, song],
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter), song), :to_hash).
      serialize.
      must_equal([{"title"=>"Kinetic"}, {"title"=>"Kinetic"}])
  end

  it do
    array = CollectionRepresenter.new(nil,
      SimplerDefinition.new(Representable::Definition.new(:songs, :extend => SongRepresenter, :class => Song), nil), :to_hash, :from_hash).
      deserialize([{"title"=>"Kinetic"}, {"title"=>"Contention"}])

      array[0].title.must_equal("Kinetic")
      array[1].title.must_equal("Contention")
  end


  # Collection + XML
  it do
    nodes = CollectionRepresenter.new([song, song],
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter), song), :to_node).
      serialize

      nodes.first.must_be_kind_of(Nokogiri::XML::Element)

      nodes.first.to_s.
      must_equal_xml("<song><title>Kinetic</title></song>")
      nodes.last.to_s.
      must_equal_xml("<song><title>Kinetic</title></song>")
  end

  it do
    xml_array = Nokogiri::XML.parse("<root><song><title>Kinetic</title></song><song><title>Contention</title></song></root>").root

    array = CollectionRepresenter.new(nil,
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter, :class => Song), song), :to_node, :from_node).
      deserialize(xml_array.children)

    array[0].title.must_equal("Kinetic")
    array[1].title.must_equal("Contention")
  end


 # Scalar + Hash
  it do
    ScalarRepresenter.new("Kinetic",
      SimplerDefinition.new(Representable::Definition.new(:title), nil), :to_hashhhhh).
      serialize.
      must_equal("Kinetic")
  end

  it do
    obj = ScalarRepresenter.new(nil,
      SimplerDefinition.new(Representable::Definition.new(:title), nil), :to_hash, :from_hashhhh).
      deserialize("Kinetic")

    obj.must_equal("Kinetic")
  end


  # Scalar + XML
  it do
    ScalarRepresenter.new("Kinetic",
      SimplerDefinition.new(Representable::Definition.new(:title), nil), :to_node).
      serialize.
      must_equal("Kinetic")
  end

  # it do
  #   xml_node = Nokogiri::XML.parse("<title>Kinetic</title>").root

  #   obj = ScalarRepresenter.new(nil,
  #     SimplerDefinition.new(Representable::Definition.new(:title), nil), :to_hash, :from_node).
  #     deserialize(xml_node)

  #   obj.must_equal("Kinetic")
  # end


  # Binding -----------
  class JSONScalarBinding
    def initialize(definition)
      @definition =definition
    end

    def write(hash, value)
      hash[from] = serialize(value)
      hash
    end

    def read(hash)
      fragment = hash[from]

      deserialize(fragment)
    end

  private
    def serialize(value) # DISCUSS: pass Representer.serialize from outside?
      ScalarRepresenter.new(value, SimplerDefinition.new(@definition, value), :to_json).serialize # prepare, to_json
    end

    def deserialize(fragment)
      ScalarRepresenter.new(nil, SimplerDefinition.new(@definition, nil), :to_json, :blabla).deserialize(fragment) # prepare, from_json
    end

    def from
      @definition.from
    end
  end

  class JSONObjectBinding < JSONScalarBinding
    def serialize(value) # DISCUSS: pass from outside?
      ObjectRepresenter.new(value, SimplerDefinition.new(@definition, nil), :to_hash).serialize # prepare, to_json
    end

    def deserialize(fragment)
      ObjectRepresenter.new(nil, SimplerDefinition.new(@definition, nil), :to_json, :from_hash).deserialize(fragment) # prepare, from_json
    end
  end

  class JSONCollectionBinding < JSONObjectBinding
    def serialize(value) # DISCUSS: pass from outside?
      value.collect do |obj| # DISCUSS: what if we wanna keep the original array?
        super(obj)
      end
    end
  end

  class XMLScalarBinding < JSONObjectBinding
    def write(parent, value)
      wrap_node = parent

      #if wrap = options[:wrap]
      #  parent << wrap_node = node_for(parent, wrap)
      #end

      wrapped = node_for(parent, from)
      wrapped.content = serialize(value)

      wrap_node << wrapped

      parent
    end

  private
    def node_for(parent, name)
      Nokogiri::XML::Node.new(name.to_s, parent.document)
    end

    def serialize(value) # DISCUSS: pass from outside?
      ScalarRepresenter.new(value, SimplerDefinition.new(@definition, nil), :to_node).serialize # prepare, to_json
    end

    #def options
    #  @definition.options
    #end
  end

  class XMLObjectBinding < XMLScalarBinding
    def write(parent, value)
      parent << serialize(value)

      parent
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

    def serialize(value) # DISCUSS: pass from outside?
      ObjectRepresenter.new(value, SimplerDefinition.new(@definition, nil), :to_node).serialize # prepare, to_json
    end

    def deserialize(node)
      ObjectRepresenter.new(nil, SimplerDefinition.new(@definition, nil), :to_node, :from_node).deserialize(node)
    end
  end

  class XMLCollectionBinding < XMLObjectBinding
    def write(parent, value)
      nodes = value.collect { |item| serialize(item) }

      parent << set_for(parent, nodes)
    end

    def deserialize(nodes)
      nodes.collect do |nod|
        super(nod)
      end
    end

  private
    def set_for(parent, nodes)
      Nokogiri::XML::NodeSet.new(parent.document, nodes)
    end
  end

  describe "read and write" do

    # Scalar + Hash
    it { JSONScalarBinding.new(Representable::Definition.new(:title)).write({}, "Kinetic").
      must_equal({"title"=>"Kinetic"}) }


    # Object + Hash
    it { JSONObjectBinding.new(Representable::Definition.new(:song, :extend => SongRepresenter)).write({}, song).
      must_equal("song" => {"title"=>"Kinetic"}) }

    it do
      obj = JSONObjectBinding.new(Representable::Definition.new(:song, :extend => SongRepresenter, :class => Song)).read("song"=>{"title"=>"Kinetic"})

      obj.title.must_equal("Kinetic")
    end

    # Collection + Hash
    it { JSONCollectionBinding.new(Representable::Definition.new(:songs, :extend => SongRepresenter)).write({}, [song, song]).
      must_equal("songs" => [{"title"=>"Kinetic"},{"title"=>"Kinetic"}]) }



    # Scalar + XML
    it { XMLScalarBinding.new(Representable::Definition.new(:title)).write(Nokogiri::XML::Document.new, "Kinetic").
      to_s.
      must_equal_xml "<title>Kinetic</title>" }


    # Object + XML
    it { XMLObjectBinding.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter)).write(Nokogiri::XML::Document.new, song).
      to_s.
      must_equal_xml "<song><title>Kinetic</title></song>" }

    it do
      xml_object = Nokogiri::XML.parse("<root><song><title>Kinetic</title></song></root>").root

      obj = XMLObjectBinding.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter, :class => Song)).read(xml_object)

      obj.title.must_equal("Kinetic")
    end

    # Collection + XML
    it {
      root = Nokogiri::XML::Node.new("root", Nokogiri::XML::Document.new)

      XMLCollectionBinding.new(Representable::Definition.new(:songs, :extend => XMLSongRepresenter)).write(root, [song, song]).
      to_s.
      must_equal_xml "<root><song><title>Kinetic</title></song><song><title>Kinetic</title></song></root>" }

    it do
      xml_object = Nokogiri::XML.parse("<root><song><title>Kinetic</title></song><song><title>Contention</title></song></root>").root

      array = XMLCollectionBinding.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter, :class => Song)).read(xml_object)

      array[0].title.must_equal("Kinetic")
      array[1].title.must_equal("Contention")
    end
  end
end