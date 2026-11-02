module ConsoleHelper
  # The referral reward's state, as the console shows it.
  def reward_status(user)
    reward = user.rewards.find { |candidate| candidate.reward_type == Reward::REFERRAL_WELCOME }
    return "none" if reward.nil?
    return "used" if reward.redeemed_at

    "$#{MoneyFormat.display(reward.amount_cents)} unused"
  end

  # JSON null shows as "null", so an empty reward field is visible in the preview.
  def json_value(value)
    value.nil? ? "null" : value.to_s
  end

  def restaurant_choices(restaurants)
    restaurants.map { |restaurant| [ restaurant.name, restaurant.id ] }
  end
end
