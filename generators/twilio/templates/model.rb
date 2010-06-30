class <%= class_name %> < ActiveRecord::Base
  include Workflow
  
  workflow do 
    state :hello do 
      say "Twilio Gorillas. Wasssaaap!"
      prompt 1, "If you are a jungle-dweller, press 1", :primal, :go => :jungle_dweller
      prompt 2, "Captured primates, please press 2", :captured, :go => :zoo_habitant
      press 9, "To end this call, press 9", :go => :goodbye
    end
    
    state :jungle_dweller do 
      say :growl
    end
    
    state :zoo_habitant do 
      say :greetings
    end
    
    state :goodbye do 
      say "Goodbye"
    end
  end
  
  def greetings
    "Greetings. We come in peace."
  end
  
  def growl
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