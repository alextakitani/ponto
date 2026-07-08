class Ahoy::Event < ApplicationRecord
  self.table_name = "ahoy_events"

  include AhoyCaptain::Ahoy::EventMethods
  include Ahoy::QueryMethods

  belongs_to :visit, class_name: "Ahoy::Visit", foreign_key: :visit_id, optional: true
  belongs_to :user, optional: true

  def properties=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
end
