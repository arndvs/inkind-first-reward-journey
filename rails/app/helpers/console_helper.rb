module ConsoleHelper
  # The referral reward's state, as the console shows it.
  def reward_status(user)
    reward = user.rewards.find { |candidate| candidate.reward_type == Reward::REFERRAL_WELCOME }
    return "none" if reward.nil?
    return "used" if reward.redeemed_at

    "$#{MoneyFormat.display(reward.amount_cents)} unused"
  end

  def restaurant_choices(restaurants)
    restaurants.map { |restaurant| [ restaurant.name, restaurant.id ] }
  end
end
