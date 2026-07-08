require "test_helper"

# Paginação da API JSON (Q73): TODO endpoint de coleção é limitado no SQL (LIMIT/
# OFFSET via Pagy 43) — sem isso um histórico grande puxava o array inteiro numa
# request só (o bug que motivou isto: 3319 entries + N+1 gigante de taggings ao
# abrir a extensão). Testamos NOSSA lógica: default, override por ?limit=, teto
# (clamp), navegação por ?page= e os headers de paginação. O body segue array puro
# (contrato dos clientes preservado — a extensão espera array, não envelope).
class JsonPaginationTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email: "pagination@example.com")
    @read = @user.access_tokens.create!(permission: "read")
  end

  test "index limita ao default (50) mesmo com mais registros" do
    create_time_entries(60)

    get time_entries_path, headers: bearer(@read), as: :json

    assert_response :success
    assert_equal 50, response.parsed_body.size, "default deve limitar em 50"
    assert_equal "60", response.headers["X-Total-Count"]
    assert_equal "50", response.headers["X-Per-Page"]
    assert_equal "1", response.headers["X-Page"]
    assert_equal "2", response.headers["X-Total-Pages"]
    assert_equal "2", response.headers["X-Next-Page"]
    assert_nil response.headers["X-Prev-Page"], "página 1 não tem anterior"
  end

  test "?page= navega e a segunda página traz o resto" do
    create_time_entries(60)

    get time_entries_path(page: 2), headers: bearer(@read), as: :json

    assert_response :success
    assert_equal 10, response.parsed_body.size, "página 2 traz os 10 restantes"
    assert_equal "2", response.headers["X-Page"]
    assert_equal "1", response.headers["X-Prev-Page"]
    assert_nil response.headers["X-Next-Page"], "última página não tem próxima"
  end

  test "?limit= sobrescreve o default" do
    create_time_entries(30)

    get time_entries_path(limit: 10), headers: bearer(@read), as: :json

    assert_response :success
    assert_equal 10, response.parsed_body.size
    assert_equal "10", response.headers["X-Per-Page"]
    assert_equal "3", response.headers["X-Total-Pages"]
  end

  test "?limit= acima do teto é clampeado (não reabre o buraco)" do
    create_time_entries(120)

    get time_entries_path(limit: 999_999), headers: bearer(@read), as: :json

    assert_response :success
    assert_equal 100, response.parsed_body.size, "limit é clampeado no teto de 100"
    assert_equal "100", response.headers["X-Per-Page"]
  end

  test "o body segue array puro (sem envelope) — contrato dos clientes preservado" do
    create_time_entries(3)

    get time_entries_path, headers: bearer(@read), as: :json

    assert_response :success
    assert_kind_of Array, response.parsed_body
  end

  test "catálogo (clients) também é paginado" do
    55.times { |i| @user.clients.create!(name: "Cliente #{format('%03d', i)}") }

    get clients_path(limit: 20), headers: bearer(@read), as: :json

    assert_response :success
    assert_equal 20, response.parsed_body.size
    assert_equal "55", response.headers["X-Total-Count"]
  end

  private
    def create_time_entries(count)
      base = Time.utc(2026, 1, 1, 8)
      count.times do |i|
        start = base + (i * 2).hours
        @user.time_entries.create!(started_at: start, ended_at: start + 1.hour)
      end
    end

    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
