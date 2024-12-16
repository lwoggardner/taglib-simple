# frozen_string_literal: true

module TagLib
  # @!visibility private
  # Type checking methods
  module Types
    class << self
      def check_value_types(values)
        return if values.empty?
        return check_complex_property_value(values) if values.first.is_a?(Hash)

        values.each do |v|
          raise TypeError, "expected property value to be String, received #{v.class.name}" unless v.is_a?(String)
        end
      end

      def check_complex_property_value(values)
        values.each do |v|
          raise TypeError, "expected complex property value to be Hash, received #{v.class.name}" unless v.is_a?(Hash)

          check_variant_value(v)
        end
      end

      def check_variant_value(obj)
        case obj
        when String, Integer
          # nothing to do
        when Array
          obj.each { |v| check_variant_value(v) }
        when Hash
          obj.each do |k, v|
            raise TypeError "VariantMap keys must be String, received #{k.class.name}" unless k.is_a?(String)

            check_variant_value(v)
          end
        else
          raise TypeError, "Variant Type expected String, Integer, Array or Hash, received #{obj.class.name}"
        end
      end

      def complex_property?(_key, values)
        values.first.is_a?(Hash)
      end
    end
  end
end
