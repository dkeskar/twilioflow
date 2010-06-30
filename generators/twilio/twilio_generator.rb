class TwilioGenerator < Rails::Generator::NamedBase
  
  def manifest
    record do |m|
      m.class_collisions class_name

      m.directory File.join('app/models', class_path)
      m.directory File.join('app/controllers', class_path)
      m.directory File.join('app/helpers', class_path)
      m.directory File.join('app/views', class_path, file_name)
      
      m.template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
      
      m.migration_template 'migration.rb', 'db/migrate', 
        :migration_file_name => "create_#{file_name.pluralize}"
      
      m.template 'controller.rb', 
        File.join('app/controllers', class_path, "#{file_name}_controller.rb")
      
      m.template 'twilio.twiml.builder', 
          File.join('app/views', class_path, file_name, "twilio.twiml.builder")
      m.template 'edit.html.erb', 
          File.join('app/views', class_path, file_name, "edit.html.erb")
      
      m.file 'config/twilio.yml', 'config/twilio.yml'
      m.file 'lib/twiliolib.rb', 'lib/twiliolib.rb'
      
      m.route_resources file_name
    end
  end
  
end
