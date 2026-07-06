module Nameable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_name

    scope :alphabetical, -> { order(:name_normalized) }
    scope :name_matching, ->(query) {
      if query.blank?
        all
      else
        pattern = "%#{sanitize_sql_like(normalize_name(query))}%"
        where("name_normalized LIKE ? ESCAPE '\\'", pattern)
      end
    }

    validate :name_normalized_must_be_unique
  end

  class_methods do
    def name_uniqueness_scope(scope)
      @name_uniqueness_scope = scope
    end

    def name_uniqueness_scope_column
      @name_uniqueness_scope
    end

    def normalize_name(value)
      string = value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      ActiveSupport::Inflector.transliterate(string).downcase
    end
  end

  private
    def normalize_name
      self.name_normalized = self.class.normalize_name(name)
    end

    def name_normalized_must_be_unique
      return if name_normalized.blank?

      scope_column = self.class.name_uniqueness_scope_column
      relation = self.class.where(name_normalized: name_normalized)
      relation = relation.where(scope_column => public_send(scope_column)) if scope_column
      relation = relation.where.not(id: id) if persisted?

      errors.add(:name, :taken) if relation.exists?
    end
end
