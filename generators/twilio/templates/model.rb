class <%= class_name %> < ActiveRecord::Base
  include Workflow
  
  workflow do 
    state :hello do 
      say "Twilio Gorillas. Wasssaaap!"
      prompt 1, "If you are an existing primate", :go => :existing
      prompt 2, "For evolved primates", :go => :evolved
      prompt 9, "To end this call", :go => :goodbye
    end
    
    state :existing do 
      say :vocalize
    end
    
    state :evolved do 
      say :greetings
    end
    
    state :goodbye do 
      say "Goodbye"
    end
  end
  
  def greetings
    "Customized greeting"
  end
  
  def vocalize
    "Please listen carefully to this recorded growl"
  end
  
	def says
		self.current_state.sayings.map do |phrase|
			if phrase.is_a?(String) 
				phrase.match(/^ivr/) ? I18n.t(phrase) : phrase
			elsif phrase.is_a?(Symbol)
				self.send(phrase)
			end
		end.flatten || []
	end
	
	def accepts
		self.current_state.pressings || {}
	end
  
end