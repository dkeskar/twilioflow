#
# Twilioflow enhances the Workflow module to incorporate voice response 
# and key press events into the state machine. This is achieved through 
# enhanced event specifiers (press and prompt) and instance methods for 
# triggering transitions (#respond! and #decide!) 
#
module Workflow 
  # Workflow::Decision handles the specification and transitions associated
  # with a yes/no decision as reported by a deciding method. The decision 
  # therefore has two associated events (on_yes and on_no). 
  #
  # The decider can return true/false or yes/no, which triggers the associated
  # event, and results in a state transition. 
  #
  # The decider can also return nil. In this third outcome, there is no 
  # decision made and therefore no transition. 
  #
  class Decision 
    attr_accessor :decider, :action, :meta, :on_yes, :on_no

    # Create a new Decision instance that maps the state machine spec
    def initialize(decider, yes, no, meta = {}, &action)
      @decider, @action, @on_yes, @on_no, @meta = decider, action, yes, no, meta
    end

    # String description of decision for logging or display purposes
    def describe
      "#{decider} yes: #{@on_yes} no: #{@on_no}"
    end

    # If an event is to be invoked directly on the yes/no path. 
    # FIXME - make this a protected method
    def event_name_for(path)
      "#{decider}_#{path}".to_sym
    end
    
    # Pick the event (if it exists) to execute for the given outcome. 
    def to_execute(outcome)
      case outcome
      when FalseClass, 'no', :no
        self.on_no ? event_name_for(:no) : nil
      when TrueClass, 'yes', :yes
        self.on_yes ? event_name_for(:yes) : nil
      when NilClass
        nil
      else
        raise WorkflowError.new("Can't decide #{name} in state #{current_state}")
      end			
    end
  end
end

Workflow::Event.class_eval do 
  # String description of event for display or logging purposes. 
  def describe
    "#{@name} to #{@transitions_to}"
  end
end

# Workflow::State manages the state specific information for the model 
# workflow. Twilioflow enhances this with the set of #sayings (voice prompts),
# #pressings (acceptable keys) and #decisions associated with the state.
#
Workflow::State.class_eval do 
  attr_accessor :sayings, :decisions

  def add_press(digit, ev)
    @pressings = Hash.new if @pressings.nil? 
    @pressings[digit] = ev
  end

  def add_decision(d)
    @decisions = Array.new if @decisions.nil?
    @decisions << d
  end

  def pressings
    @pressings
  end	
end

# Workflow::Specification provides the Ruby DSL for specifying a workflow 
# in terms of states and events that trigger state transitions. 
# Twilioflow enhances the specification to add four more directives, namely
# #press, #prompt, #say and #decide. 
# 
# Thus, each state now has a set of 
#
Workflow::Specification.class_eval do 
  # Specifies the text to speak when entering the enclosing state. 
  # There can be only one say statement for the state. If there are multiple
  # say statements, only the sentences from the last one are kept. 
  # Use #prompt to add text to speak associated with key presses.  
  # 
  def say(*sentences)
    @scoped_state.sayings = sentences
  end

  # Specifies the actions to take upon a specified key press. 
  # The key press can be a single key, a set of keys followed by the # sign
  # or any of a number of key choices (e.g. three choices, either 1, 2 or 3) 
  # 
  #     press 1, :confirm, :go => :next_state
  #     press '#', :pin_entered, :go => :verify_pin  
  #     presss '.3', :three_choices, :go => :choice_made
  # 
  # This creates an event associated with this transition and adds the keys to 
  # the accepted pressings for this state. This information is used by the 
  # the #respond! method during processing to deduce and trigger state 
  # transitions. 
  #
  def press(digits, name, args = {}, &action)
    if decision_indicator?(args) 
      decide(name, args.merge(:press => digits), &action)
    else
      e = event(name, args, &action)
      @scoped_state.add_press(digits, e) 
    end
  end

  # Specifies the voice prompt and actions to take upon a key press. 
  # This is a convenience wrapper for #say and #press. 
  #
  # Note - this specifier can be improved to nest the saying and the gathering 
  # to fine-tune the Twilio voice interaction for a given state. 
  # 
  def prompt(digits, what, name, args = {}, &action)
    @scoped_state.sayings = [] if @scoped_state.sayings.nil?
    @scoped_state.sayings << what
    press(digits, name, args, &action)
  end

  # Make a yes/no/ignore decision for transiting to another state based on 
  # conditions to be checked by a decider. 
  # 
  #     decide :need_id, :yes => :pin_verification, :no => :authenticated
  # 
  # Decisions are processed after responding to key presses, and if there is 
  # no state transition triggered by the key press. The decider method is 
  # called and its outcome (true/false/nil) decides the yes/no transition or
  # staying in the same state. 
  #  
  def decide(decider, args = {}, &action)		
    if !args[:yes] and !args[:no]
      raise WorkflowDefinitionError.new("missing: need at least one yes/no transition")
    end
    d = Workflow::Decision.new(decider, args[:yes], args[:no], (args[:meta] or {}), &action)

    # create events for yes/no paths
    evargs = args[:meta] || {}
    [:yes, :no].each do |path|
      next if !args[path]
      e = event(d.event_name_for(path), evargs.merge(:transition_to => args[path]), &action)
    end
    if digits = args[:press]
      @scoped_state.add_press(digits, d)
    else
      # only non-keypress decisions considered for sequential transition check
      @scoped_state.add_decision(d)
    end
  end	
	
  private 
  def event_indicator?(args)
    [:go, :triggers, :trigger, :transition_to, :transitions_to].each do |indicator|
      return true if args[indicator]
    end
    false
  end

  def decision_indicator?(args)
    [:yes, :no].each {|x| return true if args[x] }
    false
  end
end

Workflow::WorkflowInstanceMethods.module_eval do 
  # TODO: private or protected
  # Processes the decision by running the associated block or the decider 
  # callback, and triggering the associated event if any. 
  # 
  # Returns the new state only if there is a transition.
  #
  def process_decision!(decision, *args)
    raise WorkflowError.new("Bad decision") if decision.nil?
    start_state = self.current_state.name
    outcome = run_action(decision.action, *args) || 
    					run_action_callback(decision.decider, *args)
    event_name = decision.to_execute(outcome)
    process_event!(event_name, *args) if not event_name.nil? 
    new_state = self.current_state.name
    new_state != start_state ? new_state : nil
  end
	
	# Respond to key presses by triggering events and effecting state transition.
	# 
	# See #decide!
	# If there is no event driven transition, we process all the decisions 
	# for this state. Similarly, if we reach a new state where there are no 
	# voice prompts or key presses, we immediately evaluate the decisions for the 
	# new state. 
	# 
  def respond!(digits)
    start_state_name = self.current_state.name
    raise "No Key Presses" if not (pressings = current_state.pressings)
    key, args = if digits.is_a?(Fixnum)
      [digits, nil]
    elsif digits.is_a?(String) and digits.size <= 1
      [digits.to_i, nil]
    else
      ['#', digits]
    end
    response = pressings[key]
    if not response and (any = pressings.keys.grep(/^\./))
      response = pressings[any.first]
      args = digits
    end
    case response
    when Workflow::Event; process_event!(response.name, args)
    when Workflow::Decision; process_decision!(response, args)
    end
    new_state = self.current_state
    make_decisions = (start_state_name == new_state.name || new_state.sayings.blank?)
    make_decisions ? self.decide! : new_state
  rescue
    return self.current_state.name
  end	
	
	# Consider each decision associated with this state, until there is a 
	# transition. If there is no transition after all decisions are evaluated
	# we remain in the current state.  
	# 
  def decide!
    return if not (consider = self.current_state.decisions)
    consider.each {|decision| break if process_decision!(decision) }
    self.current_state.name
  end
end
