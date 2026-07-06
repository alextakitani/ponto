require "test_helper"

class TagsTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("dono@example.com")
  end

  test "index lista só as tags ativas e busca por nome normalizado" do
    ativa = @user.tags.create!(name: "Urgente")
    arquivada = @user.tags.create!(name: "Legado")
    arquivada.archive!
    @user.tags.create!(name: "Backend")

    get tags_path(q: "urg")

    assert_response :success
    assert_select "body", text: /Urgente/
    assert_select "body", { text: /Backend/, count: 0 }
    assert_select "body", { text: /Legado/, count: 0 }
  end

  test "create, update, archive e unarchive funcionam" do
    assert_difference -> { @user.tags.count }, +1 do
      post tags_path, params: { tag: { name: "Cliente VIP" } }
    end

    tag = @user.tags.find_by!(name: "Cliente VIP")
    patch tag_path(tag), params: { tag: { name: "Prioridade" } }
    post tag_archival_path(tag)
    delete tag_archival_path(tag)

    assert_redirected_to tags_path(archived: "1")
    assert_equal "Prioridade", tag.reload.name
    assert_not tag.archived?
  end

  test "colisão com arquivada mostra mensagem de desarquivar" do
    archived = @user.tags.create!(name: "Urgente")
    archived.archive!

    assert_no_difference -> { @user.tags.count } do
      post tags_path, params: { tag: { name: "Urgente" } }
    end

    assert_response :unprocessable_entity
    assert_match(/arquivad/i, response.body)
    assert_match(/desarquiv/i, response.body)
  end

  test "destroy hard-deleta tag sem uso e bloqueia tag com tagging" do
    removable = @user.tags.create!(name: "Solta")
    used = @user.tags.create!(name: "Com uso")
    entry = @user.time_entries.create!(started_at: Time.current - 1.hour, ended_at: Time.current)
    entry.tags << used

    assert_difference -> { @user.tags.count }, -1 do
      delete tag_path(removable)
    end

    assert_no_difference -> { @user.tags.count } do
      delete tag_path(used)
    end
    assert_redirected_to tags_path
    assert_match(/arquive/i, flash[:alert])
  end

  test "isolamento: não vê nem edita tag de outra conta" do
    other = create_user(email: "outro@example.com")
    foreign = other.tags.create!(name: "Alheia")

    get tag_path(foreign)
    assert_response :not_found

    patch tag_path(foreign), params: { tag: { name: "Invadida" } }
    assert_response :not_found
  end
end
