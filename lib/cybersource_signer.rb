require 'hmac-sha2'
require 'base64'

class CybersourceSigner
  attr_accessor :profile, :signer
  attr_writer   :time
  attr_writer   :form_fields
  attr_reader   :cybersource_fields

  UNSIGNED_FIELD_NAMES = %w[
    bill_to_email
    bill_to_forename
    bill_to_surname
    bill_to_address_line1
    bill_to_address_line2
    bill_to_address_country
    bill_to_address_state
    bill_to_address_postal_code
    bill_to_address_city
    card_cvn
    card_expiry_date
    card_number
    card_type
  ]

  def initialize(profile, signer = Signer)
    @profile              = profile
    @signer               = signer
    @cybersource_fields   = {
      access_key:           @profile.access_key,
      profile_id:           @profile.profile_id,
      payment_method:       "card",
      locale:               "en",
      transaction_type:     "sale", # TODO: transaction_type will be variable
      currency:             "USD"
    }
  end

  def sign_cybersource_fields(params)
    add_cybersource_fields(params)
    sign_fields
  end

  def add_cybersource_fields(params)
    filtered_params = params.select do |key, value|
      result = false

      if key == 'amount'
        result = true
      else
        match_data = /^merchant_defined_data(\d{1,3})$/.match(key)

        if match_data.present?
          result = match_data[1].to_i > 0 && match_data[1].to_i < 101
        end
      end

      result
    end

    filtered_params_with_sym_keys = Hash[filtered_params.map{|(k,v)| [k.to_sym,v]}]
    cybersource_fields.merge!(filtered_params_with_sym_keys)
  end

  def sign_fields
    form_fields.tap do |data|
      signature_keys = data[:signed_field_names].split(",").map { |e| e.to_sym}
      signature_message = self.class.signature_message(data, signature_keys)
      data[:signature]  = signer.signature(signature_message, profile.secret_key)
    end
  end

  def form_fields
    @form_fields ||= cybersource_fields.dup.merge(
      unsigned_field_names: CybersourceSigner::UNSIGNED_FIELD_NAMES.join(','),
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
