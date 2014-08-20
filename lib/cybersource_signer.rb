require 'hmac-sha2'
require 'base64'

class CybersourceSigner
  attr_accessor :profile, :signer
  attr_writer   :time
  attr_writer   :form_fields
  attr_reader   :unsigned_field_names, :signable_fields

  IGNORE_FIELDS = %i[
    commit
    utf8
    authenticity_token
    action
    controller
  ]

  def initialize(profile, unsigned_field_names = [], signer = Signer)
    @profile              = profile
    @signer               = signer
    @unsigned_field_names = unsigned_field_names
    @signable_fields      = {
      access_key:           @profile.access_key,
      profile_id:           @profile.profile_id,
      payment_method:       "card",
      locale:               "en",
      transaction_type:     @profile.transaction_type,
      currency:             "USD"
    }
  end

  def add_and_sign_fields(params)
    add_signable_fields(params)
    sign_fields
  end

  def add_signable_fields(params)
    @signable_fields.merge! params.symbolize_keys.delete_if { |k,v|
      @unsigned_field_names.include?(k) || IGNORE_FIELDS.include?(k)
    }
  end

  def sign_fields
    form_fields.tap do |data|
      signature_keys = data[:signed_field_names].split(',').map { |e| e.to_sym}
      signature_message = self.class.signature_message(data, signature_keys)
      data[:signature]  = signer.signature(signature_message, profile.secret_key)
    end
  end

  def form_fields
    @form_fields ||= signable_fields.dup.merge(
      unsigned_field_names: @unsigned_field_names.map { |e| e.to_s }.join(','),
      transaction_uuid:     SecureRandom.hex(16),
      reference_number:     SecureRandom.hex(16)
    ).tap do |data|
      data[:signed_field_names] =
        (data.keys + %w(signed_field_names signed_date_time)).join(',')
      data[:signed_date_time] = time
    end
  end

  def time
    @time ||= Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def self.signature_message(hash, keys)
    keys.map {|key| "#{key}=#{hash.fetch(key)}" }.join(',')
  end

  # For the cart, we put the signed field names in merchant_defined_data99, and the signature in
  # merchant_defined_data100. This allows us to show the payment form again, with the original
  # cart data, if there is a failed transaction.
  def sign_cart_fields(fields)
    fields[:signed_field_names] = fields.keys.join(',')
    self.form_fields = fields
    signed_cart_fields = sign_fields
    signed_cart_fields[:merchant_defined_data99] = signed_cart_fields.delete :signed_field_names
    signed_cart_fields[:merchant_defined_data100] = signed_cart_fields.delete :signature
    signed_cart_fields
  end

  class Signer
    def self.signature(message, secret_key)
      mac = HMAC::SHA256.new(secret_key)
      mac.update message
      Base64.strict_encode64(mac.digest)
    end
  end
end
