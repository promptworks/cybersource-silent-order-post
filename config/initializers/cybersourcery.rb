Cybersourcery.configure do |config|
  config.profiles = "#{Rails.root}/config/cybersourcery_profiles.yml"
  config.sop_proxy_url = 'http://localhost:5555'
end
