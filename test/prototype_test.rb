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

class ObjectRepresenter
  def initialize(represented, definition, serialize_method)
    @represented = represented
    @definition = definition
    @serialize_method = serialize_method
  end

  def serialize
    serialize_for(@represented)
  end

private
  def serialize_for(object)
    decorator = prepare(object)

    decorator.send(@serialize_method, {:wrap => false})
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
end

class ScalarRepresenter < ObjectRepresenter
  def serialize
    @represented
  end

  # def to_hash
  #   @represented.to_s
  # end

  # def to_node
  #   # should that happen in a FragmentBinding?
  #   node = Nokogiri::XML::Node.new(@definition.name.to_s, Nokogiri::XML::Document.new) # was #node_for. that used to happen in PBinding#serialize_for.
  #   node.content = to_hash
  #   node
  # end
end

class SimplerDefinition < Representable::Binding
  include Representable::Binding::Prepare
end

class BllaTest < MiniTest::Spec
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

  it do
    ObjectRepresenter.new(song,
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter), song), :to_hash).
      serialize.
      must_equal({"title"=>"Kinetic"})
  end

  it do
    CollectionRepresenter.new([song, song],
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter), song), :to_hash).
      serialize.
      must_equal([{"title"=>"Kinetic"}, {"title"=>"Kinetic"}])
  end

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
    ScalarRepresenter.new("Kinetic",
      SimplerDefinition.new(Representable::Definition.new(:title), nil), :to_hash).
      serialize.
      must_equal("Kinetic")
  end

  it do
    ScalarRepresenter.new("Kinetic",
      SimplerDefinition.new(Representable::Definition.new(:title), nil), :to_node).
      serialize.
      must_equal("Kinetic")
  end


  class JSONScalarBinding
    def initialize(definition)
      @definition =definition
    end

    def write(hash, value)
      hash[from] = serialize(value)
      hash
    end

  private
    def serialize(value) # DISCUSS: pass Representer.serialize from outside?
      ScalarRepresenter.new(value, SimplerDefinition.new(@definition, value), :to_json).serialize # prepare, to_json
    end

    def from
      @definition.from
    end
  end

  class JSONObjectBinding < JSONScalarBinding
    def serialize(value) # DISCUSS: pass from outside?
      ObjectRepresenter.new(value, SimplerDefinition.new(@definition, nil), :to_hash).serialize # prepare, to_json
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

    def serialize(value) # DISCUSS: pass from outside?
      ObjectRepresenter.new(value, SimplerDefinition.new(@definition, nil), :to_node).serialize # prepare, to_json
    end
  end

  class XMLCollectionBinding < XMLObjectBinding
    def write(parent, value)
      nodes = value.collect { |item| serialize(item) }

      parent << set_for(parent, nodes)
    end

  private
    def set_for(parent, nodes)
      Nokogiri::XML::NodeSet.new(parent.document, nodes)
    end
  end

  describe "read and write" do
    it { JSONScalarBinding.new(Representable::Definition.new(:title)).write({}, "Kinetic").
      must_equal({"title"=>"Kinetic"}) }

    it { JSONObjectBinding.new(Representable::Definition.new(:song, :extend => SongRepresenter)).write({}, song).
      must_equal("song" => {"title"=>"Kinetic"}) }

    it { JSONCollectionBinding.new(Representable::Definition.new(:songs, :extend => SongRepresenter)).write({}, [song, song]).
      must_equal("songs" => [{"title"=>"Kinetic"},{"title"=>"Kinetic"}]) }



    it { XMLScalarBinding.new(Representable::Definition.new(:title)).write(Nokogiri::XML::Document.new, "Kinetic").
      to_s.
      must_equal_xml "<title>Kinetic</title>" }

    it { XMLObjectBinding.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter)).write(Nokogiri::XML::Document.new, song).
      to_s.
      must_equal_xml "<song><title>Kinetic</title></song>" }

    it {
      root = Nokogiri::XML::Node.new("root", Nokogiri::XML::Document.new)

      XMLCollectionBinding.new(Representable::Definition.new(:songs, :extend => XMLSongRepresenter)).write(root, [song, song]).
      to_s.
      must_equal_xml "<root><song><title>Kinetic</title></song><song><title>Kinetic</title></song></root>" }
  end
end