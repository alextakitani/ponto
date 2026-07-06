class OnboardingSkipsController < ApplicationController
  def create
    # O import bem-sucedido e o pulo manual convergem aqui: onboarding concluído.
    Current.user.update!(onboarded_at: Time.current)

    redirect_to home_path
  end
end
