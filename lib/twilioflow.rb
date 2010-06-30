module Twilioflow
  
  @twilio_config = {}
  
  class << self
    def load_config(twilio_yaml)
      return false unless File.exist?(twilio_yaml)
      @twilio_config = YAML.load(ERB.new(File.read(twilio_yaml)).result)
      if defined? RAILS_ENV
        @twilio_config = @twilio_config[RAILS_ENV]
      end
      # move some information into the environment 
      
      ['account_sid', 'phone_number'].each do |item|
        ENV["TWILIO_#{item.upcase}"] = @twilio_config[item]
      end
      twilio_config
    end
    
    def twilio_config
      @twilio_config
    end
  end
  
end

require 'workflow/workflow'
require 'workflow/ivr_workflow'
