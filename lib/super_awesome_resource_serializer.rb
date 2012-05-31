require 'active_support'
require 'active_support/core_ext'
require 'active_support/json'

# This class provides the base functionality for serializing Activeobject objects to XML, JSON, or YAML. It is intended to be
# used with web services where tighter control is desired than is provided by ActiveResource out of the box. For instance, you may have
# some sensitive fields in your Activeobject that should not be made available through a public web service API unless the user
# is a trusted user.
#
# To create a serializer for you model, you simply need to make a new class named ModelNameSerializer where ModelName is the
# class name of your model. The serializer class itself then needs to define how each field should be serialized using the serialize
# method.
class SuperAwesomeResourceSerializer

  STATIC_CLASSES = [String, Symbol, Fixnum, Float, NilClass, TrueClass, FalseClass, Object].inject({}){|hash, klass| hash[klass] = true; hash}

  class << self
    # Get the serializer class for a given object.
    def for_object (object, options = {}, klass = object.class)
      serializer_class = "#{klass.name}Serializer".constantize
      return serializer_class.new(object, options)
    rescue
      if klass.superclass.nil?
        raise NameError.new("no known serializers for class #{object.class.name}")
      else
        return for_object(object, options, klass.superclass)
      end
    end

    # Define how to serialize and deserialize a field. The following options can be passed in to define how to serialize an object.
    # * :element - The name of the field in the serialized output. This can be used to give a object a prettier name on output.
    # * :getter - The getter to get the field value.
    # * :setter - The setter to set the field value.
    # * :exclude - Indicate that this field should be excluded unless specifically asked for. Values can be :getter, :setter, or true.
    #
    # By default, getters and setters will call the field accessor on the serializer (if it is defined) or on the object.
    # This can be overridden by specifying a different method name to call, or a proc that will be yielded to with the object
    # (and value for a setter). Finally, getters and setters can be disabled by setting them to false.
    def serialize (field, options = {})
      serialized_field_info << SerializedFieldInfo.new(field, options)
    end

    # Merge the values of two field lists as used in :include, :exclude, and :only options.
    def merge_field_lists (list_1, list_2)
      if list_1.blank?
        if list_2.blank?
          return nil
        else
          return list_2
        end
      elsif list_2.blank?
        return list_1
      else
        list_1 = normalize_field_list(list_1)
        list_2 = normalize_field_list(list_2)
        merge_hashes(list_1, list_2)
      end
    end

   # Turn an :include, :exclude, or :only field list into a hash for consistent access.
   def normalize_field_list (field_list)
     case field_list
     when nil
       return {}
     when true
       return {}
     when String
       return {field_list.to_sym => true}
     when Symbol
       return {field_list => true}
     when Array
       hash = {}
       field_list.each do |value|
         if value.is_a?(Hash)
           hash.merge!(normalize_field_list(value))
         else
           hash[value.to_sym] = true
         end
       end
       return hash
     when Hash
       hash = {}
       field_list.each_pair do |key, value|
         value = normalize_field_list(value) unless value == true
         hash[key.to_sym] = value
       end
       return hash
     else
       raise ArgumentError.new("illegal type in field list: #{field_list.class.name}")
     end
   end

    # Get a list of serialized field information for preforming an action (either :getter or :setter) on the class.
    # Option can pass in values for :include, :exclude, and :only to indicate filters on what fields are allowed.
    # Include can be used to add fields that have been defined but excluded by default, exclude can be used to remove
    # fields included by default, while only is used to specify the exact list of fields to use.
    def serializable_fields (action, options = {})
      if self == SuperAwesomeResourceSerializer
        return []
      else
        exclude_fields = options[:exclude] || {}
        include_fields = options[:include] || {}
        only_fields = options[:only] || {}

        all_field_info = superclass.serializable_fields(options) + serialized_field_info

        if only_fields.empty?
          excluded_field_names = exclude_fields.collect{|k,v| k if v == true}.compact
          excluded_field_names = (excluded_field_names + all_field_info.select{|field| field.excluded?(action)}.collect{|field| field.name}) - include_fields.keys
          all_field_info.delete_if{|field| excluded_field_names.include?(field.name)} unless excluded_field_names.empty?
        else
          all_field_info.delete_if{|field| not only_fields.include?(field.name)}
        end

        return all_field_info
      end
    end

    # Get the field name with the unique key used to lookup the object
    def param_key
      if @param_key
        @param_key
      elsif superclass < SuperAwesomeResourceSerializer
        superclass.param_key
      else
        :id
      end
    end

    # Set the field name with the unique key used to lookup the object
    def param_key= (val)
      @param_key = val
    end

    protected

    # Merge two hashes recursively
    def merge_hashes (hash_1, hash_2)
      hash_1.each_pair do |key, value_1|
        value_2 = hash_2.delete(key)
        if value_2.is_a?(Hash)
          hash_1[key] = merge_hashes(value_1, value_2)
        end
      end
      hash_1.merge(hash_2)
    end

    def serialized_field_info
      @serialized_field_info ||= []
    end
  end

  attr_reader :object, :include_fields, :exclude_fields, :only_fields, :root_element

  # Create a new serializer. Options can be passed in for :exclude, :include, or :only to determine
  # which fields will be used.
  #
  # To indicate a field should be included or excluded on a serializer returned by a field, prefix it with the field name.
  # For example, if you have a field :venue and this field returns a VenueSerializer object and you only want the id of the
  # venue, you can specify :only => "venue.id".
  def initialize (object, serialize_options = {})
    @object = object
    @include_fields = self.class.normalize_field_list(serialize_options[:include])
    @exclude_fields = self.class.normalize_field_list(serialize_options[:exclude])
    @only_fields = self.class.normalize_field_list(serialize_options[:only])
    @root_element = serialize_options[:root_element] ? serialize_options[:root_element].to_s : object.class.name.underscore.gsub("/", "-")
  end

  # Set the attributes on the underlying object by calling the available setters. All keys in the hash (and in any hashes in the values)
  # will be converted to symbols.
  def set_attributes (attributes)
    return unless attributes
    attributes = normalize_attribute_keys(attributes)
    serializable_fields(:setter).each do |field|
      if attributes.include?(field.name)
        field.set(self, attributes[field.name])
      end
    end
  end

  # Update the available fields in the object with a serialized representation of the object in XML.
  def update_with_xml (xml)
    set_attributes(Hash.from_xml(xml)[root_element])
  end

  # Update the available fields in the object with a serialized representation of the object in JSON.
  def update_with_json (json)
    set_attributes(ActiveSupport::JSON.decode(json))
  end

  # Update the available fields in the object with a serialized representation of the object in YAML.
  def update_with_yaml (yaml)
    set_attributes(YAML.load(yaml))
  end

  # Serialize the object to a hash.
  def to_hash
    hash = HashWithIndifferentAccess.new
    serializable_fields(:getter).each do |field|
      if field.getter?
        hash[field.element] = wrap_object_for_hash(field.get(self), field.name)
      end
    end
    return hash
  end

  # Serialize the object to XML.
  def to_xml (xml_options = {})
    to_hash.to_xml({:root => root_element, :dasherize => false}.reverse_merge(xml_options))
  end

  # Serialize the object to JSON.
  def to_json (json_options = nil)
    to_hash.to_json(json_options)
  end

  # Serialize the object to YAML.
  def to_yaml (yaml_options = {})
    remove_hash_indifferent_access(to_hash).to_yaml(yaml_options)
  end

  # Get the unique key used for lookups
  def to_param
    object.send(self.class.param_key || :id)
  end

  def == (val)
    return val.is_a?(self.class) && val.object == object && val.include_fields == include_fields && val.exclude_fields == exclude_fields && val.only_fields == only_fields && val.root_element == root_element
  end

  private

  # Convert a hash and all contained hashes to use symbols for keys.
  def normalize_attribute_keys (attributes)
    attributes = HashWithIndifferentAccess.new(attributes) unless attributes.is_a?(HashWithIndifferentAccess)
    attributes.each_pair do |key, value|
      attributes[key] = normalize_attribute_keys(value) if value.is_a?(Hash) and not value.is_a?(HashWithIndifferentAccess)
    end
  end

  # Get the list of serializable fields for an action (either :getter or :setter)
  def serializable_fields (action)
    return self.class.serializable_fields(action, :include => include_fields, :exclude => exclude_fields, :only => only_fields)
  end

  # Convert an object to a hash using serializers if they exist.
  def wrap_object_for_hash (object, field)
    if STATIC_CLASSES.include?(object.class)
      return object
    elsif object.is_a?(Array)
      return object.collect{|element| wrap_object_for_hash(element, field.to_s.singularize)}
    elsif object.is_a?(Hash)
      hash = {}
      object.each_pair{|key, value| hash[key] = wrap_object_for_hash(value, field)}
      return hash
    elsif object.is_a?(SuperAwesomeResourceSerializer)
      return object.to_hash
    else
      serializer_class = "#{object.class.name}Serializer".constantize rescue nil
      if serializer_class
        serialize_options = {:include => include_fields[:field], :exclude => exclude_fields[field], :only => only_fields[field]}
        return serializer_class.new(object, serialize_options).to_hash
      else
        return object
      end
    end
  end

  # Change a HashWithIndifferentAccess into a regular hash including all hashes in the values
  def remove_hash_indifferent_access (value)
    if value.is_a?(Hash)
      hash = {}
      value.each_pair do |key, value|
        hash[key] = remove_hash_indifferent_access(value)
      end
      return hash
    elsif value.is_a?(Array)
      return value.collect{|v| remove_hash_indifferent_access(v)}
    else
      return value
    end
  end

  # Encapulation of information about a serialized field.
  class SerializedFieldInfo
    attr_reader :name, :element

    def initialize (name, options)
      @name = name.to_sym
      @getter = options[:getter]
      @setter = options[:setter]
      @element = (options[:element] || @name).to_sym
      @exclude = options[:exclude] || []
    end

    # Get the field value in the specified serializer.
    def get (serializer)
      if getter?
        if @getter.is_a?(Proc)
          @getter.call(serializer.object) if @getter.is_a?(Proc)
        else
          method_name = @getter || name
          if serializer.respond_to?(method_name)
            serializer.send(method_name)
          else
            serializer.object.send(method_name)
          end
        end
      end
    end

    # Set the field value in the specified serializer.
    def set (serializer, value)
      if setter?
        if @setter.is_a?(Proc)
          @setter.call(serializer.object, value) if @setter.is_a?(Proc)
        else
          method_name = @setter || "#{name}="
          if serializer.respond_to?(method_name)
            serializer.send(method_name, value)
          else
            serializer.object.send(method_name, value)
          end
        end
      end
    end

    # Check if the field has a getter.
    def getter?
      return @getter != false
    end

    # Check if the field has a setter.
    def setter?
      return @setter != false
    end

    # Return true if the field is excluded from the specified action by default.
    def excluded? (action)
      if @exclude == true
        return true
      elsif @exclude.is_a?(Array)
        return @exclude.include?(action)
      else
        return @exclude == action
      end
    end
  end
end
