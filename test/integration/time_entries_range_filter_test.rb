require "test_helper"

# Filtro por intervalo em GET /time_entries JSON (extensão: "ledger da semana"
# filtrado no SERVIDOR, não no client — senão o total quebra quando a semana passa
# de uma página). `since`/`until` são ISO 8601 opcionais e combináveis; filtram por
# `started_at` no SQL, antes da paginação, com `until` como fim EXCLUSIVO. Testamos
# NOSSA lógica: as fronteiras, a combinação, o timezone/offset, o 400 pra inválido e
# que os headers de paginação refletem a janela.
class TimeEntriesRangeFilterTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email: "range@example.com")
    @read = @user.access_tokens.create!(permission: "read")

    # Três entries em dias distintos (UTC), pra cortar em qualquer ponto.
    @mon = entry_at(Time.utc(2026, 7, 6, 10)) # segunda
    @wed = entry_at(Time.utc(2026, 7, 8, 10)) # quarta
    @fri = entry_at(Time.utc(2026, 7, 10, 10)) # sexta
  end

  test "sem params o comportamento não muda (todas as entries)" do
    get time_entries_path, headers: bearer(@read), as: :json
    assert_response :success
    assert_equal ids(@fri, @wed, @mon), response_ids
  end

  test "since sozinho corta as mais antigas (inclusivo)" do
    get time_entries_path(since: "2026-07-08T00:00:00Z"), headers: bearer(@read), as: :json
    assert_response :success
    assert_equal ids(@fri, @wed), response_ids, "quarta e sexta, não a segunda"
  end

  test "since é inclusivo na fronteira exata" do
    get time_entries_path(since: "2026-07-08T10:00:00Z"), headers: bearer(@read), as: :json
    assert_response :success
    assert_includes response_ids, @wed.id, "started_at == since entra"
  end

  test "until sozinho corta as mais novas com FIM EXCLUSIVO" do
    get time_entries_path(until: "2026-07-08T10:00:00Z"), headers: bearer(@read), as: :json
    assert_response :success
    assert_equal ids(@mon), response_ids, "entry com started_at == until NÃO aparece"
  end

  test "since + until formam uma janela [inicio, fim)" do
    get time_entries_path(since: "2026-07-06T00:00:00Z", until: "2026-07-10T00:00:00Z"),
      headers: bearer(@read), as: :json
    assert_response :success
    assert_equal ids(@wed, @mon), response_ids, "segunda e quarta; sexta fica de fora (>= until)"
  end

  test "offset explícito é respeitado (comparação em UTC)" do
    # 2026-07-08T00:00:00-03:00 == 2026-07-08T03:00:00Z, então a quarta (10:00Z) entra
    # e a segunda fica de fora.
    get time_entries_path(since: "2026-07-08T00:00:00-03:00"), headers: bearer(@read), as: :json
    assert_response :success
    assert_equal ids(@fri, @wed), response_ids
  end

  test "since inválido devolve 400 com {error:} (sem 500)" do
    get time_entries_path(since: "não-é-data"), headers: bearer(@read), as: :json
    assert_response :bad_request
    assert response.parsed_body["error"].present?
  end

  test "until inválido devolve 400 com {error:}" do
    get time_entries_path(until: "13/07/2026"), headers: bearer(@read), as: :json
    assert_response :bad_request
    assert response.parsed_body["error"].present?
  end

  test "X-Total-Count reflete a janela filtrada, não o total geral" do
    get time_entries_path(since: "2026-07-08T00:00:00Z"), headers: bearer(@read), as: :json
    assert_response :success
    assert_equal "2", response.headers["X-Total-Count"], "só as 2 dentro da janela"
  end

  private
    def entry_at(started_at)
      @user.time_entries.create!(started_at: started_at, ended_at: started_at + 1.hour)
    end

    def ids(*entries)
      entries.map(&:id)
    end

    def response_ids
      response.parsed_body.map { |e| e["id"] }
    end

    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
