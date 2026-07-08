class Ahoy::Event < ApplicationRecord
  self.table_name = "ahoy_events"

  include AhoyCaptain::Ahoy::EventMethods
  include Ahoy::QueryMethods

  belongs_to :visit, class_name: "Ahoy::Visit", foreign_key: :visit_id, optional: true
  belongs_to :user, optional: true

  # Nome do evento de acesso de máquina (CLI/extensão via Bearer). Espelha o
  # ApplicationController#track_api_request — que grava properties com as chaves
  # controller/action/method/format. Fonte da verdade do rótulo mora aqui.
  API_REQUEST = "api_request".freeze

  scope :api_requests, -> { where(name: API_REQUEST) }

  # Resumo por endpoint (controller#action): quantas chamadas e o último acesso.
  # Usa json_extract do SQLite direto no properties (text) — sem carregar linha
  # a linha em Ruby. Ordena do mais usado pro menos. Retorna structs simples pra
  # a view iterar (endpoint, method, count, last_time).
  def self.api_usage_by_endpoint
    api_requests
      .group(Arel.sql("json_extract(properties, '$.controller'), json_extract(properties, '$.action'), json_extract(properties, '$.method')"))
      .order(Arel.sql("COUNT(*) DESC"))
      .pluck(
        Arel.sql("json_extract(properties, '$.controller')"),
        Arel.sql("json_extract(properties, '$.action')"),
        Arel.sql("json_extract(properties, '$.method')"),
        Arel.sql("COUNT(*)"),
        Arel.sql("MAX(time)")
      )
      .map do |controller, action, method, count, last_time|
        ApiEndpointUsage.new(
          endpoint: "#{controller}##{action}",
          method: method,
          count: count,
          # MAX(time) volta como string do SQLite; o banco é UTC (CLAUDE.md),
          # então interpretamos como UTC — Time.zone.parse aplicaria o fuso local.
          last_time: last_time && Time.find_zone("UTC").parse(last_time.to_s)
        )
      end
  end

  # Linha simples do resumo por endpoint — PORO model-adjacent (37signals): dá
  # nome ao que a view consome, sem virar hash anônimo.
  ApiEndpointUsage = Data.define(:endpoint, :method, :count, :last_time)

  def properties=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
end
