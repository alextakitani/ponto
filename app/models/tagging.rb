# Join M:N entre Tag e TimeEntry. A FK sozinha não conhece bolhas multi-tenant, então
# a validação abaixo garante que tag e entry pertençam ao MESMO user.
class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :time_entry

  validates :tag_id, uniqueness: { scope: :time_entry_id, message: "já está em uso" }
  validate :tag_and_time_entry_belong_to_same_user

  private
    def tag_and_time_entry_belong_to_same_user
      return if tag.blank? || time_entry.blank?
      return if tag.user_id == time_entry.user_id

      errors.add(:tag, "não pertence a você")
    end
end
