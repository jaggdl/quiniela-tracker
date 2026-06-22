class StripePaymentFetcher
  def self.call
    new.call
  end

  def call
    payment_intents = Stripe::PaymentIntent.list(
      limit: 100,
      created: { gte: 24.hours.ago.to_i },
      expand: ["data.customer"]
    )

    payment_intents.auto_paging_each do |pi|
      next unless pi.status == "succeeded"

      customer_name = pi.customer&.respond_to?(:name) ? pi.customer.name : "Anónimo"
      description = pi.description.presence || metadata_message(pi)

      PaymentMessage.find_or_create_by!(stripe_payment_intent_id: pi.id) do |pm|
        pm.customer_name = customer_name
        pm.amount = pi.amount
        pm.message = description || "Sin mensaje"
      end
    end
  end

  private

  def metadata_message(pi)
    meta = pi.metadata
    return unless meta
    meta["message"] || meta["mensaje"]
  end
end
