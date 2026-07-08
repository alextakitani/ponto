class Ahoy::Visit < ApplicationRecord
  self.table_name = "ahoy_visits"

  include AhoyCaptain::Ahoy::VisitMethods

  has_many :ahoy_events, class_name: "Ahoy::Event", foreign_key: :visit_id
  has_many :events, class_name: "Ahoy::Event", foreign_key: :visit_id
  belongs_to :user, optional: true
end
