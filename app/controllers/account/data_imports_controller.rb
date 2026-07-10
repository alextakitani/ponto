# Portabilidade JSON — IMPORT (Q26/Q72). Restaura uma exportação do Ponto numa conta
# VAZIA. Síncrono (roda no request, sem job — decisão do dono). Escopo por Current.user
# (Q23); sem Action Policy (segue o padrão do PreferencesController).
class Account::DataImportsController < ApplicationController
  layout "app"

  def new
    @empty_bubble = Current.user.empty_bubble?
  end

  def create
    unless Current.user.empty_bubble?
      redirect_to new_account_data_import_path,
        alert: t("account.data_imports.create.non_empty_bubble")
      return
    end

    if uploaded_file.blank?
      @empty_bubble = true
      @upload_error = t("account.data_imports.new.form.file_blank")
      render :new, status: :unprocessable_entity
      return
    end

    result = Account::Import.new(user: Current.user, io: uploaded_file.read).run!
    redirect_to home_path, notice: t("account.data_imports.create.imported",
      clients: result.clients_created,
      projects: result.projects_created,
      tasks: result.tasks_created,
      tags: result.tags_created,
      time_entries: result.time_entries_created)
  rescue Account::Import::Error => error
    @empty_bubble = true
    @upload_error = error.message
    render :new, status: :unprocessable_entity
  end

  private
    def uploaded_file
      params.dig(:account_data_import, :file)
    end
end
