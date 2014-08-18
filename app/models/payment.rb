class Payment
  # These are dependencies for ActiveModel::Errors in the initialize method
  extend ActiveModel::Naming
  extend ActiveModel::Translation
  include ActiveModel::Validations

  # So we can use form_for in a view
  include ActiveModel::Conversion

  attr_reader :signer, :profile, :params, :errors
  attr_accessor :bill_to_forename, :bill_to_surname, :card_number, :card_expiry_date,
                :card_expiry_dummy, :card_expiry_month, :card_expiry_year, :card_cvn, :card_type,
                :bill_to_email, :bill_to_address_line1, :bill_to_address_line2,
                :bill_to_address_city, :bill_to_address_state, :bill_to_address_postal_code
  validates_presence_of :bill_to_forename, :bill_to_surname, :card_number, :card_expiry_date,
                        :card_expiry_dummy, :card_expiry_month, :card_expiry_year, :card_cvn,
                        :card_type, :bill_to_email, :bill_to_address_line1, :bill_to_address_city,
                        :bill_to_address_state, :bill_to_address_postal_code

  # To keep ActiveModel::Conversion happy
  def persisted?
    false
  end

  def initialize(signer, profile, params)
    @signer = signer
    @profile = profile
    @params = params
    # I'm not doing dependency injection for ActiveModel dependencies.
    # Given we're extending ActiveModel::Naming above, we're already tightly bound...
    @errors = ActiveModel::Errors.new(self)
  end

  def form_action_url
    @profile.transaction_url
  end

  def sign_cybersource_fields
    # We're reserving merchant defined data fields 99 and 100 for fields we will need in the case of
    # a failed transaction, so we can re-create the state of the submission from the cart to the
    # credit card payment form.

    if @params['merchant_defined_data99'].blank?
      @params['merchant_defined_data99'] = @params['signed_field_names']
    end

    if @params['merchant_defined_data100'].blank?
      @params['merchant_defined_data100'] = @params['signature']
    end

    @signer.sign_cybersource_fields(@params)
  end
end
