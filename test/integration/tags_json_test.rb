require "test_helper"

class TagsJsonTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email: "tags@example.com")
    @read = @user.access_tokens.create!(permission: "read")
    @write = @user.access_tokens.create!(permission: "write")
  end

  test "GET index devolve só as tags do user" do
    mine = @user.tags.create!(name: "Urgente")
    create_user(email: "other@example.com").tags.create!(name: "Alheia")

    get tags_path, headers: bearer(@read), as: :json

    assert_response :success
    assert_equal [ mine.id ], response.parsed_body.map { |tag| tag["id"] }
  end

  test "POST create com write cria a tag" do
    assert_difference -> { @user.tags.count }, +1 do
      post tags_path, headers: bearer(@write), params: { tag: { name: "Nova" } }, as: :json
    end

    assert_response :created
    assert_equal "Nova", response.parsed_body["name"]
  end

  test "POST create com read é rejeitado" do
    assert_no_difference -> { @user.tags.count } do
      post tags_path, headers: bearer(@read), params: { tag: { name: "Barrada" } }, as: :json
    end

    assert_response :unauthorized
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
