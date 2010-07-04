# = Twilioflow Example 
#
# This example demonstrates how to specify a Twilio interaction model with 
# voice responses, key pressings and state transitions. 
# This model was initially generated using 
#     ruby script/generate twilio interaction
#
# and enhanced with additional states and key press specifiers. 
# 
class Interaction < ActiveRecord::Base
  include Workflow

  # Specify the interaction workflow
  workflow do 
    # This is the initial (default) state for all new interactions
    #
    state :hello do 
      # These sentences are "spoken" via the Twilio Say verb. 
      #
      say "Twilio Gorillas. Wasssaaap!"
      # Text specified as prompt is added to the "sayings" for this state. 
      # The prompt associates the key-press, names the event, and specifies 
      # next state to transition to. 
      #
      prompt 1, "If you are a jungle-dweller, press 1", :primal, :go => :jungle_dweller
      prompt 2, "Captured primates, please press 2", :captured, :go => :zoo_habitant
      prompt 9, "To end this call, press 9", :end_call, :go => :goodbye
    end
  
    # For this example, we arrive at this state when the user
    # presses 1 in the inital state during the call. 
    #
    state :jungle_dweller do 
      # The text to say, can be dynamically provided by a method 
      #
      say :growl, "Press 1 to hear more"
      #
      # The #press needs only the key, event name and transition information. 
      # If the transition information is provided as either :yes and/or :no, 
      # then we automatically consider this a decision (see #decide) and invoke
      # the decider method (in this case, #tired?)
      # Since there is not a :no transition, we stay in the same state when 
      # #tired? returns false. 
      # 
      press 1, :tired?, :yes => :alpha_rating
    end
  
    state :zoo_habitant do 
      say :greetings
      prompt 1, "Press 1 to be a fan", :get_contact, :go => :fan_registration
      #      
      # This is the simplest #press specification
      # The name specified is an event (since this is not a :yes/:no decision)
      # named #end_call! which will result in a transition to 
      # the :goodbye state if the #current_state corresponds to :zoo_habitant
      #
      press 9, :end_call, :go => :goodbye 
    end
  
    state :fan_registration do 
      say "Great. Give us your mobile number."
      #
      # An event is automatically associated with a callback method of the 
      # same name. This can be used to process the response and update internal
      # data before transitioning to the next state. 
      # A key-press of '#' instructs Twilio to collect a string of digits 
      # ending in the pound-key. 
      # 
      press '#', :collect_callback, :go => :goodbye
    end

    state :alpha_rating do 
      say "That's it.", :provide_rating_info
      #
      # You can dynamically provide a range of acceptable keys (1 to that number)
      # This can be combined with the dynamic sentences to provide customized
      # options 
      #
      press '.:num_ratings', :collect_rating, :go => :goodbye
      press 9, :repeat, :go => :jungle_dweller
    end    
  
    state :goodbye do 
      say "Goodbye"
    end
  end

  # This is used as a decider. It can return true, false or nil. 
  # This particular method ignores the digits(response), but you can use it, 
  # for example to verify a string of digits and decide the next state 
  # e.g. pin verification, credit card validity, etc. 
  # 
  def tired?(digits=nil) 
    # ignore the arg, go with your guts
    (rand * 10 < 3)
  end

  # This is an event callback. We use this to gather the digits for future use
  def collect_callback(digits=nil)
    # do something, either in memory or in DB
  end

  # This is an event callback. 
  def collect_rating(digits = nil)
    # do something, either with object state or DB info. 
  end

  def provide_rating_info 
    "Rate me from 1 to #{self.num_ratings}. " + 
    "1 is weak, #{self.num_ratings} is strong. " + 
    "Press 9 to hear me growl again."
  end

  # Dynamically provide a range of keys options
  def num_ratings 
    5
  end

  # This can provide customized text to say
  def greetings
    "Greetings. We come in peace."
  end

  # Suggested improvement - support a custom mp3 file name
  def growl
    "Please listen carefully to this recorded growl"
  end

  # These are generated method for the interaction object, which are 
  # used by the view builder to create the XML response. 
  #
	def says
		self.current_state.sayings.map do |phrase|
			if phrase.is_a?(String) 
				phrase.match(/^ivr/) ? I18n.t(phrase) : phrase
			elsif phrase.is_a?(Symbol)
				self.send(phrase)
			end
		end.flatten || []
	end

	# Generated method to gather all the accepted key-presses. 
	def accepts
		self.current_state.pressings || {}
	end
end

