# frozen_string_literal: true

# Base class for models stored in SolidCache
# Provides ActiveModel-like interface with validations
#
# Example:
#   class UserSession < CacheModel
#     attribute :user_id, :integer
#     attribute :token, :string
#     attribute :expires_at, :datetime
#
#     validates :user_id, presence: true
#     validates :token, presence: true
#
#     def self.cache_key_prefix
#       "user_session"
#     end
#
#     def self.default_ttl
#       1.hour
#     end
#   end
#
#   session = UserSession.new(user_id: 1, token: "abc123")
#   session.save  # => true
#   UserSession.find("user_session:1")  # => UserSession instance
class CacheModel
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations
  include ActiveModel::Serialization
  include Turbo::Broadcastable

  # Primary key for cache storage
  attribute :id, :string

  class RecordNotFound < StandardError; end
  class RecordInvalid < StandardError; end

  # Override in subclass to set custom cache key prefix
  # @return [String] cache key prefix
  def self.cache_key_prefix
    name.underscore
  end

  # Override in subclass to set custom TTL (time to live)
  # @return [ActiveSupport::Duration, nil] TTL duration or nil for no expiration
  def self.default_ttl
    nil
  end

  # Find a record by cache key or ID
  # @param key [String] cache key or ID
  # @return [CacheModel, nil] found instance or nil
  def self.find(key)
    cache_key = key&.start_with?("#{cache_key_prefix}:") ? key : build_cache_key(key)
    data = Rails.cache.read(cache_key)
    return nil unless data

    instance = new(data)
    instance.id = extract_id_from_key(cache_key)
    instance
  end

  # Find a record by cache key or ID, raises RecordNotFound if not found
  # @param key [String] cache key or ID
  # @return [CacheModel] found instance
  # @raise [RecordNotFound] if record not found
  def self.find!(key)
    find(key) || raise(RecordNotFound, "Couldn't find #{name} with id=#{key}")
  end

  # Check if a record exists
  # @param key [String] cache key or ID
  # @return [Boolean]
  def self.exists?(key)
    cache_key = key.start_with?("#{cache_key_prefix}:") ? key : build_cache_key(key)
    Rails.cache.exist?(cache_key)
  end

  # Delete a record from cache
  # @param key [String] cache key or ID
  # @return [Boolean] true if deleted
  def self.destroy(key)
    cache_key = key.start_with?("#{cache_key_prefix}:") ? key : build_cache_key(key)
    Rails.cache.delete(cache_key)
  end

  # Delete all records with the cache key prefix
  # Note: This requires cache store to support delete_matched
  # @return [void]
  def self.destroy_all
    Rails.cache.delete_matched("#{cache_key_prefix}:*")
  end

  # Build cache key from ID
  # @param id [String] ID
  # @return [String] cache key
  def self.build_cache_key(id)
    "#{cache_key_prefix}:#{id}"
  end

  # Extract ID from cache key
  # @param cache_key [String] cache key
  # @return [String] ID
  def self.extract_id_from_key(cache_key)
    cache_key.delete_prefix("#{cache_key_prefix}:")
  end

  # Save the record to cache
  # @param validate [Boolean] whether to run validations
  # @return [Boolean] true if saved successfully
  def save(validate: true)
    return false if validate && invalid?

    generate_id if id.blank?

    Rails.cache.write(
      cache_key,
      serializable_hash,
      expires_in: self.class.default_ttl
    )
  end

  # Save the record to cache, raises RecordInvalid if invalid
  # @return [Boolean] true if saved successfully
  # @raise [RecordInvalid] if record is invalid
  def save!
    raise RecordInvalid, errors.full_messages.join(", ") if invalid?
    save(validate: false)
  end

  # Update attributes and save
  # @param attributes [Hash] attributes to update
  # @return [Boolean] true if saved successfully
  def update(attributes)
    assign_attributes(attributes)
    save
  end

  # Update attributes and save, raises RecordInvalid if invalid
  # @param attributes [Hash] attributes to update
  # @return [Boolean] true if saved successfully
  # @raise [RecordInvalid] if record is invalid
  def update!(attributes)
    assign_attributes(attributes)
    save!
  end

  # Delete the record from cache
  # @return [Boolean] true if deleted
  def destroy
    return false if id.blank?
    self.class.destroy(id)
  end

  # Reload the record from cache
  # @return [CacheModel] self
  # @raise [RecordNotFound] if record not found
  def reload
    raise RecordNotFound, "Cannot reload unsaved record" if id.blank?

    reloaded = self.class.find!(id)
    assign_attributes(reloaded.attributes)
    self
  end

  # Check if record is persisted in cache
  # @return [Boolean]
  def persisted?
    id.present? && self.class.exists?(id)
  end

  # Get cache key for this instance
  # @return [String] cache key
  def cache_key
    raise "Record must have an id" if id.blank?
    self.class.build_cache_key(id)
  end

  private

  # Generate a unique ID for this record
  # Override in subclass to customize ID generation
  # @return [String] generated ID
  def generate_id
    self.id = SecureRandom.uuid
  end
end
