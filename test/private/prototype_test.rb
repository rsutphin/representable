require 'test_helper'


class FragmentRepresenterTest < MiniTest::Spec

  let (:song) { OpenStruct.new(:title => "Kinetic") }

  # Representer -------

  # Object + Hash
  it do
    ObjectRepresenter.new(song,
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter), song), :hash).
      serialize.
      must_equal({"title"=>"Kinetic"})
  end

  it do
    obj = ObjectRepresenter.new(nil,
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter, :class => Song), nil), :hash).
      deserialize({"title"=>"Kinetic"})

      obj.title.must_equal("Kinetic")
  end


  # Scalar + Hash
  it do
    ObjectRepresenter.new("Kinetic",
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => HashScalarDecorator), nil), :hash).
      serialize.
      must_equal("Kinetic")
  end
  it do
    obj = ObjectRepresenter.new(nil,
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => HashScalarDecorator), nil), :hash).
      deserialize("Kinetic")

    obj.must_equal("Kinetic")
  end


  # Collection + Hash
  it do
    CollectionRepresenter.new([song, song],
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => SongRepresenter), song), :hash).
      serialize.
      must_equal([{"title"=>"Kinetic"}, {"title"=>"Kinetic"}])
  end

  it do
    array = CollectionRepresenter.new(nil,
      SimplerDefinition.new(Representable::Definition.new(:songs, :extend => SongRepresenter, :class => Song), nil), :hash).
      deserialize([{"title"=>"Kinetic"}, {"title"=>"Contention"}])

      array[0].title.must_equal("Kinetic")
      array[1].title.must_equal("Contention")
  end


  # Collection + XML
  it do
    nodes = CollectionRepresenter.new([song, song],
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter), song), :node).
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
      SimplerDefinition.new(Representable::Definition.new(:song, :extend => XMLSongRepresenter, :class => Song), song), :node).
      deserialize(xml_array.children)

    array[0].title.must_equal("Kinetic")
    array[1].title.must_equal("Contention")
  end


  # Scalar + XML
  it do
    ObjectRepresenter.new("Kinetic",
      SimplerDefinition.new(Representable::Definition.new(:title, :decorator => XMLScalarDecorator), nil), :node).
      serialize.
      must_equal("Kinetic")
  end

  # Scalar + XML
  it do
    ObjectRepresenter.new("Kinetic",
      SimplerDefinition.new(Representable::Definition.new(:title, :decorator => XMLScalarDecorator), nil), :node).
      serialize.
      to_s.
      must_equal("Kinetic")
  end

  # it do
  #   xml_node = Nokogiri::XML.parse("<title>Kinetic</title>").root

  #   obj = ScalarRepresenter.new(nil,
  #     SimplerDefinition.new(Representable::Definition.new(:title), nil), :to_hash, :from_node).
  #     deserialize(xml_node)

  #   obj.must_equal("Kinetic")
  # end
end