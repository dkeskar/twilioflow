module Workflow 
	class Decision 
		attr_accessor :decider, :action, :meta, :on_yes, :on_no
		
		def initialize(decider, yes, no, meta = {}, &action)
			@decider, @action, @on_yes, @on_no, @meta = decider, action, yes, no, meta
		end
		
		def describe
			"#{decider} yes: #{@on_yes} no: #{@on_no}"
		end
		
		def event_name_for(path)
			"#{decider}_#{path}".to_sym
		end
		
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
	def describe
		"#{@name} to #{@transitions_to}"
	end
end

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

Workflow::Specification.class_eval do 
		
	def say(*sentences)
		@scoped_state.sayings = sentences
	end
	
	def press(digits, name, args = {}, &action)
	  if decision_indicator?(args) 
	    decide(name, args.merge(:press => digits), &action)
    else
		  e = event(name, args, &action)
		  @scoped_state.add_press(digits, e) 
	  end
	end
	
	def prompt(digits, what, name, args = {}, &action)
		@scoped_state.sayings = [] if @scoped_state.sayings.nil?
		@scoped_state.sayings << what
		press(digits, name, args, &action)
	end
	
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
	
	def decide!
		return if not (consider = self.current_state.decisions)
		consider.each {|decision| break if process_decision!(decision) }
		self.current_state.name
	end
end
