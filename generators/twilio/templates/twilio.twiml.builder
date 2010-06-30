
action = "/<%= file_path %>/twilio/do.twiml"
keys = @<%= file_name %>.accepts
says = @<%= file_name %>.says
numDigits = (keys and not keys['#']) ? "1" : ""
locale = current_locale.to_s

xml.instruct!
xml.Response do 
	says.each do |sentence|
		xml.Say(sentence, :voice => 'woman', :language => locale) 
	end		
	if not keys.blank? 
		xml.Gather :action => action, :method => "POST", :numDigits => numDigits do 
		end
	end
end
