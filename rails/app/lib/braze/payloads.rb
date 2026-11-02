module Braze
  # Pure builders for the /users/track bodies in 01-data-contract.md section 3.
  # Each returns a hash with string keys. Payloads never contain email, name or other personal fields.
  module Payloads
    PRODUCT_ID = "dine_in".freeze
    CURRENCY = "USD".freeze

    module_function

    def restaurant_saved(saved_restaurant)
      user = saved_restaurant.user
      keys = user.saved_restaurants.includes(:restaurant).order(:created_at, :id).map { |saved| saved.restaurant.key }

      {
        "attributes" => [ { "external_id" => user.external_id, "saved_restaurants" => keys } ],
        "events" => [
          {
            "external_id" => user.external_id,
            "name" => "restaurant_saved",
            "time" => iso8601(saved_restaurant.created_at),
            "properties" => {
              "restaurant_id" => saved_restaurant.restaurant.key,
              "cuisine" => saved_restaurant.restaurant.cuisine
            }
          }
        ]
      }
    end

    def restaurant_viewed(app_event)
      {
        "events" => [
          {
            "external_id" => app_event.user.external_id,
            "name" => "restaurant_viewed",
            "time" => iso8601(app_event.occurred_at),
            "properties" => { "restaurant_id" => app_event.restaurant.key }
          }
        ]
      }
    end

    def purchase(txn)
      user = txn.user
      properties = {}
      properties["restaurant_id"] = txn.restaurant.key if txn.restaurant
      properties["subtotal"] = MoneyFormat.number(txn.subtotal_cents)
      properties["tip"] = MoneyFormat.number(txn.tip_cents)
      properties["reward_applied"] = txn.reward_applied
      properties["reward_amount"] = MoneyFormat.number(txn.reward_amount_cents) if txn.reward_applied

      {
        "purchases" => [
          {
            "external_id" => user.external_id,
            "product_id" => PRODUCT_ID,
            "currency" => CURRENCY,
            "price" => MoneyFormat.number(txn.subtotal_cents),
            "time" => iso8601(txn.created_at),
            "properties" => properties
          }
        ]
      }
    end

    def iso8601(time)
      time.utc.iso8601
    end
  end
end
