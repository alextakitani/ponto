require "test_helper"
class PwaManifestRegressionTest < ActionDispatch::IntegrationTest
  # Regressão: o Ahoy.user_method global chamava current_ahoy_user em TODO
  # controller; o Rails::PwaController (manifest/service-worker) não tem o método
  # -> NoMethodError / 500. Guarda com respond_to? no store e no user_method.
  test "GET /manifest.json não estoura (Rails::PwaController sem current_ahoy_user)" do
    get "/manifest.json"
    assert_response :success
  end

  test "GET /service-worker.js não estoura" do
    get "/service-worker.js"
    assert_response :success
  end
end
