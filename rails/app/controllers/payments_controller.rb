class PaymentsController < ApplicationController
  def create
    user = User.find(params[:user_id])
    attributes = params.expect(payment: [ :restaurant_id, :subtotal, :tip, :use_reward ])

    subtotal_cents = dollars_to_cents(attributes[:subtotal])
    tip_cents = dollars_to_cents(attributes[:tip].presence || "0")
    if subtotal_cents.nil? || tip_cents.nil?
      return render_user_page_with_errors(user, [ "Enter amounts like 62.40 for the subtotal and tip." ])
    end

    Payments::Record.call(
      user: user,
      restaurant: Restaurant.find_by(id: attributes[:restaurant_id]),
      subtotal_cents: subtotal_cents,
      tip_cents: tip_cents,
      use_reward: attributes[:use_reward] == "1"
    )
    redirect_to user_path(user), notice: "Payment recorded."
  rescue ActiveRecord::RecordInvalid => error
    render_user_page_with_errors(user, error.record.errors.full_messages)
  end

  private

  # "62.40" => 6240. Returns nil for anything that isn't a non-negative amount.
  def dollars_to_cents(text)
    amount = BigDecimal(text.to_s)
    return nil unless amount.finite?
    return nil if amount.negative?

    (amount * 100).round
  rescue ArgumentError
    nil
  end
end
