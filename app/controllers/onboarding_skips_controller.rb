class OnboardingSkipsController < ApplicationController
  def create
    Current.user.update!(onboarded_at: Time.current)

    redirect_to home_path
  end
end
