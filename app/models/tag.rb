# Tag do usuário (Fatia 6). Vive na bolha isolada de um `user` (Q23) e nasce
# completa com só nome + user_id (Q51) — por isso pode ser criada inline no tracker.
class Tag < ApplicationRecord
  belongs_to :user

  include Archivable

  has_many :taggings, dependent: :restrict_with_error
  has_many :time_entries, through: :taggings

  encrypts :name, deterministic: true

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: "já está em uso" }

  def name_conflicts_with_archived?
    errors.include?(:name) &&
      user&.tags&.archived&.exists?(name: name)
  end
end
