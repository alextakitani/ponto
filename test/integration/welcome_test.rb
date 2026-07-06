require "test_helper"

class WelcomeTest < ActionDispatch::IntegrationTest
  test "user HTML por sessão sem onboarding é redirecionado para welcome" do
    sign_in_as("novo@example.com", user: create_user(email: "novo@example.com", onboarded_at: nil))

    get home_path

    assert_redirected_to welcome_path
  end

  test "admin não sofre redirect automático" do
    admin = create_user(email: "admin@example.com", admin: true, onboarded_at: nil)
    sign_in_as("admin@example.com", user: admin)

    get home_path

    assert_response :success
  end

  test "request JSON com Bearer AccessToken não redireciona para welcome" do
    user = create_user(email: "ext@example.com", onboarded_at: nil)
    token = user.access_tokens.create!(permission: "read")

    get timer_path, headers: bearer(token), as: :json

    assert_response :success
  end

  test "skip grava onboarded_at, cai em home e libera navegação seguinte" do
    user = create_user(email: "skip@example.com", onboarded_at: nil)
    sign_in_as("skip@example.com", user: user)

    post onboarding_skip_path

    assert_redirected_to home_path
    assert user.reload.onboarded_at.present?

    get home_path
    assert_response :success
  end

  test "welcome redireciona para home quando onboarding já foi concluído" do
    user = create_user(email: "feito@example.com", onboarded_at: Time.current)
    sign_in_as("feito@example.com", user: user)

    get welcome_path

    assert_redirected_to home_path
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
