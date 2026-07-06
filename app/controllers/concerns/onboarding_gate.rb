module OnboardingGate
  extend ActiveSupport::Concern

  included do
    before_action :require_onboarding
  end

  private
    def require_onboarding
      return unless onboarding_required?

      redirect_to welcome_path
    end

    def onboarding_required?
      Current.session.present? &&
        request.format.html? &&
        request.get? &&
        !request.xhr? &&
        !turbo_frame_request? &&
        Current.user.onboarded_at.nil? &&
        !Current.user.admin? &&
        !onboarding_exempt_controller?
    end

    def onboarding_exempt_controller?
      controller_path.in?(%w[welcome onboarding_skips clockify_imports sessions]) ||
        controller_path.start_with?("admin/")
    end
end
