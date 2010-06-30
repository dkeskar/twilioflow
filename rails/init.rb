require File.join(File.dirname(__FILE__),"..", "lib", "twilioflow")

if defined? RAILS_ROOT
  config_file = "#{RAILS_ROOT}/config/twilio.yml"
  TWILIOFLOW = Twilioflow.load_config(config_file)
end