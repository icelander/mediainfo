require "time"
require "mediainfo/string"

class  Mediainfo
module AttrReaders
  def mediainfo_attr_reader(method_name, mediainfo_key = nil)
    # NOTE explicit self necessary here until we rename local var 'name'
    stream_class_type = name[/::([^:]+)Stream$/, 1]
    
    before_type_cast_method_name = "#{method_name}_before_type_cast"
    mediainfo_key = mediainfo_key.gsub(/\W+/, "_").downcase if mediainfo_key
    
    if m = stream_class_type.match(/^#{Regexp.union *Mediainfo::NON_GENERAL_SECTIONS.map { |x| x.to_s.capitalize }}$/)
      k1 = stream_class_type.downcase.to_sym
    else
      k1 = :general
    end
    
    define_method before_type_cast_method_name do
      if v = instance_variable_get("@#{before_type_cast_method_name}")
        v
      else
        k2 = mediainfo_key ? mediainfo_key : method_name.to_s
        v = @parsed_response[k1][k2]
        
        instance_variable_set "@#{before_type_cast_method_name}", v
        instance_variable_get "@#{before_type_cast_method_name}"
      end
    end
    
    define_method method_name do
      if v = instance_variable_get("@#{method_name}")
        v
      else
        v = send(before_type_cast_method_name)
        v = yield v if v and block_given?
        
        instance_variable_set "@#{method_name}", v
        instance_variable_get "@#{method_name}"
      end
    end
    
    supported_attribute = method_name
    supported_attribute = "#{stream_class_type.downcase}_#{method_name}".to_sym unless k1 == :general
    Mediainfo.supported_attributes << supported_attribute
  end
  
  # Returns the duration in milliseconds
  def mediainfo_duration_reader(*a)
    mediainfo_attr_reader *a do |v|
      t = 0
      amount = 0
      count = 0

      # mediainfo always returns a string like 'x U y u,' 
      # where x and y are integers and U and u are the 
      # larger and smaller units, respectively
      # So array values 0 and 2 contain the amounts and 
      # values 1 and 3 contain the units

      v.split(/\s/).each_with_index do |tf,i|
        case i
          when *[0,2] 
            amount = tf.to_i
          when *[1,3]
            case tf
              when 'h'
                t += amount * 60 * 60 * 1000
              when 'min'
                t += amount * 60 * 1000
              when 'ms'
                t += amount
              when 's'
                t += amount * 1000
            else
              raise "unexpected time fragment: #{tf}! please report bug!"
            end
        end
      end
      # So this outputs the duration in milliseconds, which isn't very useful
      # It would be better if we could output it as a time object
      t/1000.0
    end
  end
  
  def mediainfo_date_reader(*a)
    mediainfo_attr_reader(*a) { |v| Time.parse v }
  end
  
  def mediainfo_int_reader(*a)
    mediainfo_attr_reader(*a) { |v| v.gsub(/\D+/, "").to_i }
  end
end
end