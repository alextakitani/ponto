require "test_helper"

# O único fio de nav desta fatia (Q68): o link "Admin" na home aparece SÓ pro
# admin. (A nav real vem na fase de telas.) Testamos a condicional de visibilidade
# — não o texto/estética.
class HomeAdminLinkTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  test "admin vê o link para /admin na home" do
    sign_in_as("chefe@example.com", admin: true)
    get home_path
    assert_select "a[href=?]", admin_root_path
  end

  test "user comum NÃO vê o link para /admin na home" do
    sign_in_as("membro@example.com")
    get home_path
    assert_select "a[href=?]", admin_root_path, count: 0
  end

  private
    def sign_in_as(email, admin: false)
      User.create!(email: email, admin: admin)
      keep_one_active_admin
      perform_enqueued_jobs { post sign_in_path, params: { email: email } }
      code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
      post sign_in_session_path, params: { code: code }
    end

    def keep_one_active_admin
      User.create!(email: "outro-admin@example.com", admin: true) unless User.exists?(admin: true)
    end
end
