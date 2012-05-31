require 'rubygems'
begin
  require 'simplecov'
  SimpleCov.start do
    add_filter "/spec/"
  end
rescue LoadError
  # simplecov not installed
end

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'super_awesome_resource_serializer'))

describe SuperAwesomeResourceSerializer do
  
  class SuperAwesomeResourceSerializer
    class Tester
      attr_accessor :field_1, :field_2, :field_3, :field_4, :field_5
      def initialize (values = {})
        values.each_pair{|key, value| self.send("#{key}=", value)}
      end
    end
    
    class TesterSubclass < Tester
    end
    
    class TesterSerializer < SuperAwesomeResourceSerializer
      serialize :field_1
      serialize :field_2, :exclude => :setter
      serialize :field_3, :exclude => :getter
      serialize :field_4, :exclude => true
      serialize :field_5, :element => :field_five, :exclude => true
      serialize :field_one, :getter => :field_1, :setter => :field_1=, :exclude => true
      serialize :virtual_1, :getter => lambda{|object| object.field_1.upcase}, :setter => false, :exclude => true
      serialize :virtual_2, :getter => false, :setter => lambda{|object, value| object.field_1 = value.upcase}, :exclude => true
      
      def field_4
        object.field_4.upcase if object.field_4
      end
      
      def field_4= (value)
        value = value.upcase if value
        object.field_4 = value
      end
    end
    
    class TesterWithParamKeySerializer < SuperAwesomeResourceSerializer
      self.param_key = :slug
    end
    
    class Tester2
      attr_accessor :value
      def initialize (value)
        @value = value
      end
    end
  end
  
  it "should serialize just the default fields and a HashWithIndifferentAccess" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj)
    hash = serializer.to_hash
    hash.should == {"field_1" => "one", "field_2" => "two"}
    hash[:field_1].should == "one"
  end
  
  it "should be able to add fields to the serialization" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_3 => "three")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :include => :field_3)
    serializer.to_hash.should == {"field_1" => "one", "field_2" => nil, "field_3" => "three"}
  end
  
  it "should be able to exclude default fields from the serialization" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :exclude => [:field_2])
    serializer.to_hash.should == {"field_1" => "one"}
  end
  
  it "should be able to define the exact fields to serialize" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two", :field_3 => "three")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => [:field_1, :field_3])
    serializer.to_hash.should == {"field_1" => "one", "field_3" => "three"}
  end
  
  it "should be able to specify a hash key for serialization with the :element option" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_5 => "five")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :field_5)
    serializer.to_hash.should == {"field_five" => "five"}
  end
  
  it "should be able to define a getter with a symbol" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :field_one)
    serializer.to_hash.should == {"field_one" => "one"}
  end
  
  it "should call getters on the serializer if they are defined" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_4 => "four")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :field_4)
    serializer.to_hash.should == {"field_4" => "FOUR"}
  end
  
  it "should be able to define a getter with a proc" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :virtual_1)
    serializer.to_hash.should == {"virtual_1" => "ONE"}
  end
  
  it "should not be able to get values without getters" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :virtual_2)
    serializer.to_hash.should == {}
  end
  
  it "should use an object's serializer on field values if it exists" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two"))
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :field_1)
    serializer.to_hash.should == {"field_1" => {"field_1" => "one", "field_2" => "two"}}
  end
  
  it "should not use an object's serializer if it doesn't exist" do
    value = SuperAwesomeResourceSerializer::Tester2.new("value")
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => value)
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :field_1)
    serializer.to_hash.should == {"field_1" => value}
  end
  
  it "should wrap an array's elements with serializers if the exist" do
    element_1 = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "a", :field_2 => "b")
    element_2 = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "c", :field_2 => "d")
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => [element_1, element_2])
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :field_1)
    serializer.to_hash.should == {"field_1" => [{"field_1" => "a", "field_2" => "b"}, {"field_1" => "c", "field_2" => "d"}]}
  end
  
  it "should wrap a hash's values with serializers if the exist" do
    element_1 = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "a", :field_2 => "b")
    element_2 = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "c", :field_2 => "d")
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => {:a => element_1, :b => element_2})
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => :field_1)
    serializer.to_hash.should == {"field_1" => {"a" => {"field_1" => "a", "field_2" => "b"}, "b" => {"field_1" => "c", "field_2" => "d"}}}
  end
  
  it "should normalize field lists" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :include => [:field_1, :field_2], :exclude => {:field_1 => [:field_1, :field_2], :field_2 => true}, :only => [{:field_1 => "field_1"}, "field_2"])
    serializer.include_fields.should == {:field_1 => true, :field_2 => true}
    serializer.exclude_fields.should == {:field_1=>{:field_1=>true, :field_2=>true}, :field_2=>true}
    serializer.only_fields.should == {:field_1 => {:field_1 => true}, :field_2 => true}
    SuperAwesomeResourceSerializer.normalize_field_list(:field_1).should == {:field_1 => true}
  end
  
  it "should merge field lists" do
    SuperAwesomeResourceSerializer.merge_field_lists(nil, "").should == nil
    SuperAwesomeResourceSerializer.merge_field_lists(:slug, "").should == :slug
    SuperAwesomeResourceSerializer.merge_field_lists(nil, :slug).should == :slug
    SuperAwesomeResourceSerializer.merge_field_lists(:slug, "title").should == {:slug => true, :title => true}
    SuperAwesomeResourceSerializer.merge_field_lists([:slug, {:assoc => :f3}], ["title", {:assoc => [:f1, :f2]}]).should == {:slug => true, :title => true, :assoc => {:f1 => true, :f2 => true, :f3 => true}}
  end
  
  it "should be able to specify filters on object returned by a field that have serializers" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two"), :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :only => [{:field_1 => "field_1"}, "field_2"])
    serializer.to_hash.should == {"field_1" => {"field_1" => "one"}, "field_2" => "two"}
  end
  
  it "should be able to specify exclude filters on object returned by a field that have serializers and only exclude the subobject fields" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two"), :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :exclude => {:field_1 => "field_1", :field_2 => true})
    serializer.to_hash.should == {"field_1" => {"field_2" => "two"}}
  end
  
  it "should be able to serialize to xml" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj)
    Hash.from_xml(serializer.to_xml).should == {"super_awesome_resource_serializer_tester" => {"field_1" => "one", "field_2" => "two"}}
  end
  
  it "should be able to serialize to json" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj)
    ActiveSupport::JSON.decode(serializer.to_json).should == {"field_1" => "one", "field_2" => "two"}
  end
  
  it "should be able to serialize to yaml" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj)
    YAML.load(serializer.to_yaml).should == {"field_1" => "one", "field_2" => "two"}
  end
  
  it "should be able to set attribute values" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj)
    serializer.set_attributes(:field_1 => 1)
    obj.field_1.should == 1
    obj.field_2.should == "two"
  end
  
  it "should not be able to set attribute values on fields not included" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :exclude => :field_1, :include => :field_2)
    serializer.set_attributes(:field_1 => 1, :field_2 => 2)
    obj.field_1.should == "one"
    obj.field_2.should == 2
  end
  
  it "should call setters on the serializer if they are defined" do
    obj = SuperAwesomeResourceSerializer::Tester.new
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :include => :field_4)
    serializer.set_attributes(:field_4 => "forty")
    obj.field_4.should == "FORTY"
  end
  
  it "should be able to define setters as procs" do
    obj = SuperAwesomeResourceSerializer::Tester.new
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :include => :virtual_2)
    serializer.set_attributes(:virtual_2 => "one")
    obj.field_1.should == "ONE"
  end
  
  it "should not be able to set values without setters" do
    obj = SuperAwesomeResourceSerializer::Tester.new
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :include => :virtual_1)
    serializer.set_attributes(:virtual_1 => "one")
    obj.field_1.should == nil
  end
  
  it "should be able to use a default root element of the XML document" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj)
    serializer.root_element.should == "super_awesome_resource_serializer-tester"
  end
  
  it "should be able to use a custom root element of the XML document" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer::TesterSerializer.new(obj, :root_element => "test")
    serializer.root_element.should == "test"
  end
  
  it "should be able to create a serializer for an object" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer.for_object(obj, :include => :test)
    serializer.class.should == SuperAwesomeResourceSerializer::TesterSerializer
    serializer.object.should == obj
    serializer.include_fields.should == {:test => true}
  end
  
  it "should be able to create a serializer for an object whose superclass has a serializer" do
    obj = SuperAwesomeResourceSerializer::TesterSubclass.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer.for_object(obj, :include => :test)
    serializer.class.should == SuperAwesomeResourceSerializer::TesterSerializer
    serializer.object.should == obj
    serializer.include_fields.should == {:test => true}
  end
  
  it "should raise an error if an object doesn't have a serializer" do
    lambda{SuperAwesomeResourceSerializer.for_object(1)}.should raise_error(NameError)
  end
  
  it "should be able to turn a serializer into a param" do
    obj = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one", :field_2 => "two")
    serializer = SuperAwesomeResourceSerializer.for_object(obj, :include => :test)
    obj.should_receive(:id).and_return(5)
    serializer.to_param.should == 5
  end
  
  it "should be able to customize the param key used" do
    SuperAwesomeResourceSerializer::TesterSerializer.param_key.should == :id
    SuperAwesomeResourceSerializer::TesterWithParamKeySerializer.param_key.should == :slug
  end
  
  it "should test equality" do
    obj_1 = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "one")
    obj_2 = SuperAwesomeResourceSerializer::Tester.new(:field_1 => "ONE")
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1).should == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1).should_not == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_2)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :include => :field_1).should_not == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :include => :field_1).should == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :include => :field_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :exclude => :field_1).should_not == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :exclude => :field_1).should == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :exclude => :field_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :only => :field_1).should_not == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :only => :field_1).should == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :only => :field_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :root_element => "test").should_not == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1)
    SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :root_element => "test").should == SuperAwesomeResourceSerializer::TesterSerializer.new(obj_1, :root_element => "test")
  end
end
