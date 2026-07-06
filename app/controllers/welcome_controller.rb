class WelcomeController < ApplicationController
  layout "app"

  def show
    if Current.user.onboarded_at.present?
      redirect_to home_path
    end
  end
end
