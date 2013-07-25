require 'test_helper'
require 'private/representers'

class FragmentBindingTest < MiniTest::Spec
    let (:song) { OpenStruct.new(:title => "Kinetic") }


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
      decorate(value).serialize # prepare, to_json
    end

    def deserialize(fragment)
      decorate(nil).deserialize(fragment) # prepare, from_json # FIXME: nothing to decorate here!
    end

  # DISCUSS: have wrapping _and_ representing in one class?
  private

    def from
      @definition.from
    end

    def decorate(value)
      ObjectRepresenter.new(value, SimplerDefinition.new(@definition, nil), format) # FIXME: remove need for SimplerDefinition.
    end

    def format
      :hash
    end
  end

  class JSONScalarBinding < JSONObjectBinding # DISCUSS: do we really need this binding?
    def initialize(*)
      super
      @definition.options[:extend] = HashScalarDecorator
    end
  end

  class JSONCollectionBinding < JSONObjectBinding # inherit #read and #write
    def initialize(definition, item_binding_class=JSONObjectBinding)
      @definition = definition
      @item_binding_class = item_binding_class
    end

    def serialize(value) # DISCUSS: pass from outside?
      value.collect do |obj| # DISCUSS: what if we wanna keep the original array?
        #super(obj)
        item_binding.serialize(obj)
      end
    end

    def deserialize(array)
      array.collect do |hsh|
        #super(hsh)
        item_binding.deserialize(hsh)
      end
    end

  private
    def item_binding
      @item_binding_class.new(@definition)
    end
  end


  class XMLObjectBinding < JSONObjectBinding
    def write(parent, value)
      # to be consistent with Hash: create the wrap <song> node here and add childs from the #serialize call.
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

    def node_for(parent, name)
      Nokogiri::XML::Node.new(name.to_s, parent.document)
    end

    def format
      :node
    end
  end

  class XMLScalarBinding < XMLObjectBinding
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

    def serialize(value) # DISCUSS: pass from outside?
      #ScalarRepresenter.new(value, SimplerDefinition.new(@definition, nil), :node).serialize # prepare, to_json
      @definition.options[:extend] = XMLScalarDecorator
      ObjectRepresenter.new(value, SimplerDefinition.new(@definition, nil), :node).serialize # prepare, to_json
    end

    def deserialize(node)
      @definition.options[:extend] = XMLScalarDecorator
      ObjectRepresenter.new(nil, SimplerDefinition.new(@definition, nil), :node).deserialize(node.first.content) # FIXME: not sure about this.
    end

    #def options
    #  @definition.options
    #end
  end

  class XMLCollectionBinding < XMLObjectBinding
    def write(parent, value)
      nodes = value.collect { |item| serialize(item) }

      parent << set_for(parent, nodes)
    end

    def deserialize(nodes) # FIXME: same as JSONCollectionBinding
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

    it do
      obj = JSONScalarBinding.new(Representable::Definition.new(:title)).read({"title"=>"Kinetic"})

      obj.must_equal("Kinetic")
    end


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

    it do
      array = JSONCollectionBinding.new(Representable::Definition.new(:songs, :extend => SongRepresenter, :class => Song)).read("songs"=>[{"title"=>"Kinetic"},{"title"=>"Contention"}])

      array[0].title.must_equal("Kinetic")
      array[1].title.must_equal("Contention")
    end

    it do # with scalar
      JSONCollectionBinding.new(Representable::Definition.new(:songs), JSONScalarBinding).write({}, ["Kinetic", "Contention"]).
        must_equal("songs" => ["Kinetic", "Contention"])
    end

    it do # with scalar
      array = JSONCollectionBinding.new(Representable::Definition.new(:songs), JSONScalarBinding).read("songs" => ["Kinetic", "Contention"])

      array[0].must_equal("Kinetic")
      array[1].must_equal("Contention")
    end


    let (:root) { Nokogiri::XML::Node.new("root", Nokogiri::XML::Document.new) }

    # Scalar + XML
    it do
      XMLScalarBinding.new(Representable::Definition.new(:title)).write(Nokogiri::XML::Document.new, "Kinetic").
      to_s.
      must_equal_xml "<title>Kinetic</title>"
    end

    it do
      xml_object = Nokogiri::XML.parse("<root><title>Kinetic</title></root>").root

      obj = XMLScalarBinding.new(Representable::Definition.new(:title)).read(xml_object)

      obj.must_equal "Kinetic"
    end


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
    it do
      XMLCollectionBinding.new(Representable::Definition.new(:songs, :extend => XMLSongRepresenter)).write(root, [song, song]).
      to_s.
      must_equal_xml "<root><song><title>Kinetic</title></song><song><title>Kinetic</title></song></root>"
    end

    it do
      xml_object = Nokogiri::XML.parse("<root><song><title>Kinetic</title></song><song><title>Contention</title></song></root>").root

      array = XMLCollectionBinding.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter, :class => Song)).read(xml_object)

      array[0].title.must_equal("Kinetic")
      array[1].title.must_equal("Contention")
    end

    it do # with scalar
      XMLCollectionBinding.new(Representable::Definition.new(:song), JSONScalarBinding).write(root, ["Kinetic", "Contention"]).
      to_s.
      must_equal_xml "<root><song>Kinetic</song><song>Kinetic</song></root>"
    end
  end
end