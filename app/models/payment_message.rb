class PaymentMessage < ApplicationRecord
  validates :stripe_payment_intent_id, presence: true, uniqueness: true
  validates :customer_name, presence: true
  validates :amount, presence: true

  scope :recent, -> { where(created_at: 24.hours.ago..).order(created_at: :desc) }

  def formatted
    message
  end
end
