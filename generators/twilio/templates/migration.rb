class Create<%= class_name.pluralize %> < ActiveRecord::Migration
  def self.up
    create_table "<%= table_name %>", :force => true do |t|
			t.string				:workflow_state
      t.string        :call_guid			
      t.timestamps      
    end
    add_index :<%= table_name %>, :call_guid, :unique => true
  end

  def self.down
    drop_table "<%= table_name %>"
  end
end
