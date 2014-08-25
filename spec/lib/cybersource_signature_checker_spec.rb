require 'rails_helper'

describe CybersourceSignatureChecker do
  let(:profile) { double :profile, profile_id: 'pwksgem', secret_key: 'SECRET_KEY' }
  let(:signature) { 'vWV/HxXelIWsO0tkLZe+H1S6tXflgPz79udP0uXrvPI=' }

  let(:params) do
    {
      'signed_field_names' => 'access_key,profile_id,payment_method',
      'access_key' => 'ACCESS_KEY',
      'profile_id' => 'pwksgem',
      'payment_method' => 'sale',
      'signature' => signature,
      'foo' => 'bar'
    }
  end

  describe '#run!' do
    it 'does not raise an exception when the signatures match' do
      checker = CybersourceSignatureChecker.new({ profile: profile, params: params })
      expect(checker.run!).to be_nil
    end

    it 'raises an exception when the signatures do not match' do
      params['access_key'] = 'TAMPERED_KEY'
      checker = CybersourceSignatureChecker.new({ profile: profile, params: params })
      expect { checker.run! }.to raise_exception(
        Exceptions::CybersourceryError,
        'Detected possible data tampering. Signatures do not match.'
      )
    end
  end
end
