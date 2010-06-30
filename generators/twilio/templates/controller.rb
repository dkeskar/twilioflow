require 'twiliolib'

class <%= class_name.pluralize %>Controller < ApplicationController
  layout nil

	class TwilioError < StandardError
	  def state; :sorry; end
	end
	
	def twilio
		@<%= file_name %> = <%= class_name %>.find_by_call_guid(params[:CallGuid]) ||
					<%= class_name %>.new(:call_guid => params[:CallGuid])
		if request.post? and not @<%= file_name %>.new_record?
			@<%= file_name %>.respond!(params[:Digits])
		end
		@<%= file_name %>.save
	rescue TwilioError => e
		@<%= file_name %>.workflow_state = e.state
		@<%= file_name %>.save
	ensure
		respond_to do |format|
			format.html {render :action => 'edit'}
			format.twiml { @<%= file_name %> }
		end
	end

  # HTML rendering for testing states and transitions
	def index
		redirect_to new_<%= file_name %>_url(:format => params[:format])
	end
	
	def new
		@<%= file_name %> = <%= class_name %>.new
		render :action => "edit"
	end
	
	def create
		@<%= file_name %> = <%= class_name %>.new(params['<%= file_name %>'])
		@<%= file_name %>.respond!(params[:Digits])
		@<%= file_name %>.save if @<%= file_name %>.new_record? 		# twilio starts with POST
		redirect_to edit_<%= file_name %>_url(@<%= file_name %>, :format => params[:format])
	rescue ArgumentError, ActiveRecord::RecordInvalid
		render :action => "edit"
	end
	
	def edit
		@<%= file_name %> = <%= class_name %>.find(params[:id])
		respond_to do |format|
			format.html
		end
	end
	
	def update
		@<%= file_name %> = <%= class_name %>.find(params[:id])
		@<%= file_name %>.respond!(params[:Digits])
		redirect_to edit_<%= file_name %>_url(@<%= file_name %>, :format => params[:format])
	rescue ArgumentError, ActiveRecord::RecordInvalid
		render :action => "edit"
	end
  
  protected
	def valid_twilio_request?
		return false if (sid = params["AccountSid"]).blank?
		return false if (num = (params["To"] || params["Called"])).blank?
		
		sid == ENV['TWILIO_ACCOUNT_SID'] && 
		num == ENV['TWILIO_PHONE_NUMBER']
	end
  
	def verify_authenticity_token
		verified_request? || 
		valid_twilio_request? ||
		raise(ActionController::InvalidAuthenticityToken)
	end
  
end