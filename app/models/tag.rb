# Tag do usuário (Fatia 6). Vive na bolha isolada de um `user` (Q23) e nasce
# completa com só nome + user_id (Q51) — por isso pode ser criada inline no tracker.
class Tag < ApplicationRecord
  belongs_to :user

  include Archivable
  include Nameable
  name_uniqueness_scope :user_id

  has_many :taggings, dependent: :restrict_with_error
  has_many :time_entries, through: :taggings

  validates :name, presence: true

  def name_conflicts_with_archived?
    errors.include?(:name) &&
      user&.tags&.archived&.exists?(name_normalized: name_normalized)
  end
end
