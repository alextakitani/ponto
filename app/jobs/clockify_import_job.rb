class ClockifyImportJob < ApplicationJob
  def perform(import)
    import.update!(status: "processing")

    sources = import.files.map do |file|
      Clockify::Import::Source.new(name: file.filename.to_s, content: file.download)
    end

    result = Clockify::Import.new(user: import.user, sources: sources).run!

    import.update!(
      status: "completed",
      clients_created: result.clients_created,
      projects_created: result.projects_created,
      tasks_created: result.tasks_created,
      tags_created: result.tags_created,
      time_entries_created: result.time_entries_created
    )
    # Onboarding grava NO SUCESSO do import (Q4), não só no clique "Ir pro tracker":
    # quem completa o import mas sai do resumo antes de clicar ficava preso no
    # /welcome (bolha cheia, onboarded_at nil). O guard onboarded_at? preserva um
    # timestamp anterior. O botão da tela vira só navegação pro /home.
    import.user.update!(onboarded_at: Time.current) unless import.user.onboarded_at?
    purge_files(import)
  rescue Clockify::Import::Error => error
    import.update!(status: "failed", error_message: error.message)
  rescue StandardError
    import.update!(
      status: "failed",
      error_message: I18n.t("clockify_import.errors.unexpected")
    )
  end

  private
    # Purga só DEPOIS do completed persistido, e marca files_purged conforme a
    # realidade: falha de purge não pode rebaixar um import bem-sucedido pra
    # failed nem deixar a flag mentindo — loga e segue (os dados já entraram).
    def purge_files(import)
      import.files.purge
      import.update!(files_purged: true)
    rescue StandardError => error
      Rails.logger.error("ClockifyImport #{import.id}: purge falhou — #{error.message}")
    end
end
