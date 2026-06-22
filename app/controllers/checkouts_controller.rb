require "stripe"

class CheckoutsController < ApplicationController
  def new
  end

  def create
    message = params[:message].to_s.strip.presence || "Sin mensaje"

    session = Stripe::Checkout::Session.create(
      line_items: [{
        price_data: {
          currency: "mxn",
          product_data: {
            name: "Mensaje Quiniela",
            description: message
          },
          unit_amount: 2000
        },
        quantity: 1
      }],
      mode: "payment",
      success_url: root_url(success: "1"),
      cancel_url: root_url,
      custom_text: {
        submit: { message: message }
      },
      payment_intent_data: {
        description: message
      },
      metadata: { message: message }
    )

    redirect_to session.url, allow_other_host: true
  end
end
