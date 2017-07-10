class IssueParticipant < ActiveRecord::Base
  ASSIGNEE = 0
  WATCHER  = 1

  belongs_to :issue
  belongs_to :user, class_name: 'Principal'

  scope :assignees, lambda { where(participant_role: ASSIGNEE).order(:date_begin) }

  class << self
    def import!(record_list, batch_size = 500, &block)
      raise ArgumentError 'record_list not an Array of Hashes' unless record_list.is_a?(Array) &&
        record_list.all? { |rec| rec.is_a? Hash }
      return record_list if record_list.empty?

      (0...record_list.count).step(batch_size).each do |start|
        key_list, value_list = convert_record_list(record_list[start...start+batch_size])
        sql                  = "INSERT INTO #{self.table_name} (#{key_list.join(', ')}) VALUES #{value_list.map { |rec| "(#{rec.join(', ')})" }.join(' ,')}"
        self.connection.insert_sql(sql)
        block.call(batch_size) if block_given?
      end
    end

    def convert_record_list(record_list)
      # Build the list of keys
      key_list = record_list.map(&:keys).flatten.map(&:to_s).uniq.sort

      value_list = record_list.map do |rec|
        list = []
        key_list.each { |key| list << ActiveRecord::Base.connection.quote(rec[key] || rec[key.to_sym]) }
        list
      end

      [key_list, value_list]
    end
  end
end
