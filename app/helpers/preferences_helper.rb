module PreferencesHelper
  def token_last_used(access_token)
    return "nunca" if access_token.last_used_at.blank?

    access_token.last_used_at
      .in_time_zone(Current.user.time_zone)
      .strftime("%d/%m/%Y %H:%M")
  end
end
