# Portabilidade JSON — EXPORT (Q26/Q72). Baixa a bolha inteira do usuário num único
# arquivo JSON. Escopo por Current.user (Q23) garante o isolamento — segue o padrão do
# PreferencesController (sem Action Policy: só o concern Authentication + Current.user).
class Account::DataExportsController < ApplicationController
  # Isento do gate de suspensão (Q34b/Q66): a conta suspensa ainda pode LEVAR seus
  # dados embora (o export é a rota de saída). O import NÃO precisa disso (bolha vazia
  # ⇒ conta nova, não suspensa).
  allow_suspended_access only: :show

  # GET /account/data_export(.json) — baixa o arquivo. `send_data` com disposition
  # attachment; o CLI/extensão baixam com Bearer (format .json cai no mesmo gate).
  def show
    export = Account::Export.new(user: Current.user)
    send_data export.to_json,
      filename: export.filename,
      type: "application/json",
      disposition: "attachment"
  end
end
