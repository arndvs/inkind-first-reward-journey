# Converts integer cents to the two forms the app needs: dollars for warehouse and Braze numbers,
# and display strings that match first_reward_display in 01-data-contract.md section 4.
module MoneyFormat
  module_function

  # 2500 => BigDecimal("25.00"), 6240 => BigDecimal("62.40")
  def dollars(cents)
    (BigDecimal(cents) / 100).round(2)
  end

  # Whole dollars as an Integer (25), otherwise a Float (12.5, 62.4). Braze and the contract use these JSON numbers.
  def number(cents)
    whole, remainder = cents.divmod(100)
    remainder.zero? ? whole : cents / 100.0
  end

  # 2500 => "25", 1250 => "12.50"
  def display(cents)
    whole, remainder = cents.divmod(100)
    remainder.zero? ? whole.to_s : format("%d.%02d", whole, remainder)
  end
end
