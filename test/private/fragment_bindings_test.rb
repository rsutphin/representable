require 'test_helper'
require 'representable/private/bindings'

class FragmentBindingTest < MiniTest::Spec
    let (:song) { OpenStruct.new(:title => "Kinetic") }

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

    # Hash + Hash
    it { JSONHashBinding.new(Representable::Definition.new(:songs, :extend => SongRepresenter)).write({}, {"first" => song, "same" => song}).
      must_equal({"songs"=>{"first"=>{"title"=>"Kinetic"}, "same"=>{"title"=>"Kinetic"}}}) }

    it do
      hash = JSONHashBinding.new(Representable::Definition.new(:songs, :extend => SongRepresenter, :class => Song)).read("songs" => {"first"=>{"title"=>"Kinetic"}, "same"=>{"title"=>"Contention"}})

      hash["first"].title.must_equal("Kinetic")
      hash["same"].title.must_equal("Contention")
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
      XMLCollectionBinding.new(Representable::Definition.new(:song), XMLScalarBinding).write(root, ["Kinetic", "Contention"]).
      to_s.
      must_equal_xml "<root><song>Kinetic</song><song>Contention</song></root>"
    end

    it do # with scalar
      xml_object = Nokogiri::XML.parse("<root><song>Kinetic</song><song>Contention</song></root>").root

      array = XMLCollectionBinding.new(Representable::Definition.new(:song), JSONScalarBinding).read(xml_object)

      array[0].must_equal("Kinetic")
      array[1].must_equal("Contention")
    end

    # Hash + XML
    it do XMLHashBinding.new(Representable::Definition.new(:songs, :extend => XMLSongRepresenter)).write(root, {"first" => song, "same" => song}).
      to_s.
      must_equal_xml("<root><songs><first><song><title>Kinetic</title></song></first><same><song><title>Kinetic</title></song></same></songs></root>")
    end

    it "ficken" do
      hash = XMLHashBinding.new(Representable::Definition.new(:songs, :extend => XMLSongRepresenter, :class => Song)).read(Nokogiri::XML.parse("<root><songs><first><song><title>Kinetic</title></song></first><same><song><title>Contention</title></song></same></songs></root>").root)

      hash["first"].title.must_equal("Kinetic")
      hash["same"].title.must_equal("Contention")
    end
  end

end