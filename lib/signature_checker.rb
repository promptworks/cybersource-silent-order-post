class SignatureChecker
  attr_reader :profile, :params, :check_merchant_fields

  def initialize(profile, params, check_merchant_fields = false)
    @profile = profile
    @params = params
    @check_merchant_fields = check_merchant_fields
  end

  def run
    signature_valid = signature == CybersourceSigner::Signer.signature(signature_message, @profile.secret_key)

    if block_given?
      yield({
        signature_valid: signature_valid,
        profile_id: @profile.profile_id,
        params: @params
      })
    end

    signature_valid
  end

  def run!(&block)
    raise Exceptions::CybersourceryError, 'Detected possible data tampering. Signatures do not match.' unless run(&block)
  end

  private

  def signature_message
    signed_fields_keys = signed_field_names.split(',')
    signed_fields = @params.select { |k, v| signed_fields_keys.include? k }
    CybersourceSigner.signature_message(signed_fields, signed_fields_keys)
  end

  def signed_field_names
    @check_merchant_fields ? @params['merchant_defined_data99'] : @params['signed_field_names']
  end

  def signature
    @check_merchant_fields ? @params['merchant_defined_data100'] : @params['signature']
  end
end
