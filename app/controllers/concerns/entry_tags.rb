# Pipeline de tags compartilhado entre controllers que persistem TimeEntry
# (`TimeEntriesController` e `TimersController`). Valida isolamento por user
# (Q23) — tag alheia no `tag_ids` é rejeitada e aborta o save inteiro (nada
# aplica parcialmente). Tags novas em `new_tag_names` são criadas/reesperadas
# por nome normalizado. Tudo numa transação com o save da entry.
module EntryTags
  private
    # Salva a entry e sincroniza as tags numa transação só. Extrai `tag_ids` e
    # `new_tag_names` de `attrs` (não vão pra `assign_attributes` — são tratadas
    # à parte). Retorna true se salvou+sin crouizou, false caso contrário (deixa
    # `time_entry.errors` populado pra o responder renderizar).
    def save_entry_with_tags(time_entry, attrs)
      tag_ids = Array(attrs.delete(:tag_ids))
      new_tag_names = Array(attrs.delete(:new_tag_names))

      time_entry.assign_attributes(attrs)
      return false unless time_entry.valid?

      saved = false
      TimeEntry.transaction do
        time_entry.save!
        unless sync_tags(time_entry, tag_ids:, new_tag_names:)
          raise ActiveRecord::Rollback
        end
        saved = true
      end
      saved
    end

    def sync_tags(time_entry, tag_ids:, new_tag_names:)
      tags = tags_from_ids(time_entry, tag_ids)
      return false if time_entry.errors.any?

      tags += tags_from_names(new_tag_names)
      time_entry.tags = tags.uniq
      true
    end

    # Apenas tags do próprio user (isolamento Q23). Se algum id não resolveu,
    # a entry fica inválida (erro em :tags) e o save é abortado.
    def tags_from_ids(time_entry, tag_ids)
      ids = tag_ids.map(&:to_s).reject(&:blank?)
      return [] if ids.empty?

      tags = Current.user.tags.where(id: ids).to_a
      return tags if tags.size == ids.uniq.size

      time_entry.errors.add(:tags, :not_owned)
      []
    end

    def tags_from_names(new_tag_names)
      new_tag_names
        .map { |name| name.to_s.strip }
        .reject(&:blank?)
        .uniq { |name| Tag.normalize_name(name) }
        .map do |name|
          Current.user.tags.find_by(name_normalized: Tag.normalize_name(name)) ||
            Current.user.tags.create!(name: name)
        end
    end
end
