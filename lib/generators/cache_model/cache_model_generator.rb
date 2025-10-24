# frozen_string_literal: true

require "rails/generators"
# Generator for CacheModel classes
#
# Usage:
#   rails generate cache_model NAME [field:type field:type] [options]
#
# Example:
#   rails generate cache_model user_session user_id:integer token:string expires_at:datetime
#   rails generate cache_model player_status player_id:integer status:string --ttl=5.minutes
#   rails generate cache_model game_state room_id:string data:string --prefix=game
#   rails generate cache_model cache/room room_id:string data:string  # => Cache::Room with prefix "cache_room"
class CacheModelGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  argument :attributes, type: :array, default: [], banner: "field:type field:type"

  class_option :ttl, type: :string, default: "1.hour", desc: "Cache TTL (e.g., 1.hour, 30.minutes, nil)"
  class_option :prefix, type: :string, desc: "Custom cache key prefix (defaults to model name)"

  def create_cache_model_file
    template "cache_model.rb.tt", File.join("app/models", class_path, "#{file_name}.rb")
  end

  private

  def attributes_with_types
    attributes.map do |attr|
      { name: attr.name, type: attr.type }
    end
  end

  def cache_key_prefix
    return options[:prefix] if options[:prefix]

    # Combine class_path and file_name for namespaced models
    # e.g., cache/room => "cache_room", long_cache/room => "long_cache_room"
    if class_path.empty?
      file_name
    else
      [ class_path, file_name ].join("_")
    end
  end

  def ttl_value
    options[:ttl]
  end

  def default_values
    attributes_with_types.map do |attr|
      case attr[:type]
      when "integer"
        nil
      when "boolean"
        "false"
      when "datetime"
        nil
      else
        nil
      end
    end
  end
end
