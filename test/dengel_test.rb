require 'test_helper'

class DengelTest < MiniTest::Spec
  class ObjectDecorator < Representable::Decorator # "PropertyDecorator.new(represented, definition)"
    def to_hash(*)
      # this usually happens in Binding::Object.
      # ask which type.
      SongRepresenter.prepare(represented).to_hash
    end

    def from_hash(hash, *)
      SongRepresenter.prepare(represented).from_hash(hash)
    end
  end

  class ObjectCollectionDecorator < Representable::Decorator
    def from_hash(hash, *)
      # usually we would create objects here:
      # "sync strategy":
      hash.each_with_index { |frg, i| ObjectDecorator.prepare(represented[i]).from_hash(frg) }
    end
  end

  class ScalarDecorator < Representable::Decorator
    def to_hash(*)
      represented.to_s
    end

    def from_hash(scalar, *)
      represented.replace(scalar) # DISCUSS: do we need replace?
    end
  end

  representer! do
    property :title,  decorator: ScalarDecorator
    property :song,   decorator: ObjectDecorator, instance: lambda { |*| nil } # here would be extend: SongRepresenter or something.
    property :songs,  decorator: ObjectCollectionDecorator, instance: lambda { |*| nil } # should be collection, of course.

    def representable_mapper(format, options)
      #bindings = representable_bindings_for(format, options)
      bindings = [ScalarDecorator.new()]

      Mapper.new(bindings, represented, options) # TODO: remove self, or do we need it? and also represented!
    end
  end

  module SongRepresenter
    include Representable::Hash
    property :title
  end

  let (:song) { OpenStruct.new(:title => "Knucklehead") }

  describe "ScalarDecorator" do
    it { OpenStruct.new(:title => "Knucklehead").extend(representer).to_hash.must_equal("title"=>"Knucklehead") }
    it do
      album = OpenStruct.new().extend(representer)
      album.from_hash("title"=>"Alvarez")
      album.title.must_equal "Alvarez"
    end
  end


  describe "ObjectDecorator" do
    it { OpenStruct.new(:song => song).extend(representer).to_hash.must_equal({"song"=>{"title"=>"Knucklehead"}}) }

    it "what" do
      album = OpenStruct.new(:song => song).extend(representer)
      album.from_hash("song"=>{"title"=>"Pipeline"})
      album.song.title.must_equal "Pipeline"
    end
  end

  describe "ObjectCollectionDecorator" do
    it "what else" do
      album = OpenStruct.new(:songs => [song]).extend(representer)
      album.from_hash("songs"=>[{"title"=>"Pipeline"}])
      album.songs.first.title.must_equal "Pipeline"
    end
  end

  # describe "CollectionDecorator" do
  #   it "what else" do
  #     album = OpenStruct.new(:songs => ["Knucklehead"]).extend(representer)
  #     album.from_hash("songs"=>["Pipeline"])
  #     album.songs.first.must_equal "Pipeline"
  #   end
  # end
end