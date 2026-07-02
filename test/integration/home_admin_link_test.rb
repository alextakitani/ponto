require "test_helper"

# O único fio de nav desta fatia (Q68): o link "Admin" na home aparece SÓ pro
# admin. (A nav real vem na fase de telas.) Testamos a condicional de visibilidade
# — não o texto/estética.
class HomeAdminLinkTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  test "admin vê o link para /admin na home" do
    sign_in_as("chefe@example.com", admin: true, keep_active_admin: true)
    get home_path
    assert_select "a[href=?]", admin_root_path
  end

  test "user comum NÃO vê o link para /admin na home" do
    sign_in_as("membro@example.com", keep_active_admin: true)
    get home_path
    assert_select "a[href=?]", admin_root_path, count: 0
  end
end
