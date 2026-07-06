class ClockifyImport < ApplicationRecord
  belongs_to :user
  has_many_attached :files

  enum :status, %w[pending processing completed failed].index_by(&:itself), default: "pending"

  broadcasts_refreshes
end
